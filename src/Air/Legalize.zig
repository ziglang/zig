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
    inline fn hasAny(_: @This(), comptime features: []const Feature) bool {
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
    scalarize_reduce,
    scalarize_reduce_optimized,
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
    /// Replace `struct_field_val` of a packed field with a `bitcast` to integer, `shr`, `trunc`, and `bitcast` to field type.
    expand_packed_struct_field_val,
    /// Replace `aggregate_init` of a packed struct with a sequence of `shl_exact`, `bitcast`, `intcast`, and `bit_or`.
    expand_packed_aggregate_init,

    /// Replace all arithmetic operations on 16-bit floating-point types with calls to soft-float
    /// routines in compiler_rt, including `fptrunc`/`fpext`/`float_from_int`/`int_from_float`
    /// where the operand or target type is a 16-bit floating-point type. This feature implies:
    ///
    /// * scalarization of 16-bit float vector operations
    /// * expansion of safety-checked 16-bit float operations
    ///
    /// If this feature is enabled, the following AIR instruction tags may be emitted:
    /// * `.legalize_vec_elem_val`
    /// * `.legalize_vec_store_elem`
    /// * `.legalize_compiler_rt_call`
    soft_f16,
    /// Like `soft_f16`, but for 32-bit floating-point types.
    soft_f32,
    /// Like `soft_f16`, but for 64-bit floating-point types.
    soft_f64,
    /// Like `soft_f16`, but for 80-bit floating-point types.
    soft_f80,
    /// Like `soft_f16`, but for 128-bit floating-point types.
    soft_f128,

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
            .reduce => .scalarize_reduce,
            .reduce_optimized => .scalarize_reduce_optimized,
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
    // In zig1, this function needs a lot of eval branch quota, because all of the inlined feature
    // checks are comptime-evaluated (to ensure unused features are not included in the binary).
    @setEvalBranchQuota(4000);

    const zcu = l.pt.zcu;
    const ip = &zcu.intern_pool;
    for (0..body_len) |body_index| {
        const inst: Air.Inst.Index = @enumFromInt(l.air_extra.items[body_start + body_index]);
        inst: switch (l.air_instructions.items(.tag)[@intFromEnum(inst)]) {
            .arg => {},
            inline .add,
            .add_optimized,
            .sub,
            .sub_optimized,
            .mul,
            .mul_optimized,
            .div_float,
            .div_float_optimized,
            .div_exact,
            .div_exact_optimized,
            .rem,
            .rem_optimized,
            .min,
            .max,
            => |air_tag| {
                const bin_op = l.air_instructions.items(.data)[@intFromEnum(inst)].bin_op;
                const ty = l.typeOf(bin_op.lhs);
                switch (l.wantScalarizeOrSoftFloat(air_tag, ty)) {
                    .none => {},
                    .scalarize => continue :inst l.replaceInst(inst, .block, try l.scalarizeBlockPayload(inst, .bin_op)),
                    .soft_float => continue :inst try l.compilerRtCall(
                        inst,
                        softFloatFunc(air_tag, ty, zcu),
                        &.{ bin_op.lhs, bin_op.rhs },
                        l.typeOf(bin_op.lhs),
                    ),
                }
            },
            inline .div_trunc,
            .div_trunc_optimized,
            .div_floor,
            .div_floor_optimized,
            => |air_tag| {
                const bin_op = l.air_instructions.items(.data)[@intFromEnum(inst)].bin_op;
                switch (l.wantScalarizeOrSoftFloat(air_tag, l.typeOf(bin_op.lhs))) {
                    .none => {},
                    .scalarize => continue :inst l.replaceInst(inst, .block, try l.scalarizeBlockPayload(inst, .bin_op)),
                    .soft_float => continue :inst l.replaceInst(inst, .block, try l.softFloatDivTruncFloorBlockPayload(
                        inst,
                        bin_op.lhs,
                        bin_op.rhs,
                        air_tag,
                    )),
                }
            },
            inline .mod, .mod_optimized => |air_tag| {
                const bin_op = l.air_instructions.items(.data)[@intFromEnum(inst)].bin_op;
                switch (l.wantScalarizeOrSoftFloat(air_tag, l.typeOf(bin_op.lhs))) {
                    .none => {},
                    .scalarize => continue :inst l.replaceInst(inst, .block, try l.scalarizeBlockPayload(inst, .bin_op)),
                    .soft_float => continue :inst l.replaceInst(inst, .block, try l.softFloatModBlockPayload(
                        inst,
                        bin_op.lhs,
                        bin_op.rhs,
                    )),
                }
            },
            inline .add_wrap,
            .add_sat,
            .sub_wrap,
            .sub_sat,
            .mul_wrap,
            .mul_sat,
            .bit_and,
            .bit_or,
            .xor,
            => |air_tag| if (l.features.has(comptime .scalarize(air_tag))) {
                const bin_op = l.air_instructions.items(.data)[@intFromEnum(inst)].bin_op;
                if (l.typeOf(bin_op.lhs).isVector(zcu)) {
                    continue :inst l.replaceInst(inst, .block, try l.scalarizeBlockPayload(inst, .bin_op));
                }
            },
            .add_safe => if (l.features.has(.expand_add_safe)) {
                assert(!l.features.has(.scalarize_add_safe)); // it doesn't make sense to do both
                continue :inst l.replaceInst(inst, .block, try l.safeArithmeticBlockPayload(inst, .add_with_overflow));
            } else if (l.features.has(.scalarize_add_safe)) {
                const bin_op = l.air_instructions.items(.data)[@intFromEnum(inst)].bin_op;
                if (l.typeOf(bin_op.lhs).isVector(zcu)) {
                    continue :inst l.replaceInst(inst, .block, try l.scalarizeBlockPayload(inst, .bin_op));
                }
            },
            .sub_safe => if (l.features.has(.expand_sub_safe)) {
                assert(!l.features.has(.scalarize_sub_safe)); // it doesn't make sense to do both
                continue :inst l.replaceInst(inst, .block, try l.safeArithmeticBlockPayload(inst, .sub_with_overflow));
            } else if (l.features.has(.scalarize_sub_safe)) {
                const bin_op = l.air_instructions.items(.data)[@intFromEnum(inst)].bin_op;
                if (l.typeOf(bin_op.lhs).isVector(zcu)) {
                    continue :inst l.replaceInst(inst, .block, try l.scalarizeBlockPayload(inst, .bin_op));
                }
            },
            .mul_safe => if (l.features.has(.expand_mul_safe)) {
                assert(!l.features.has(.scalarize_mul_safe)); // it doesn't make sense to do both
                continue :inst l.replaceInst(inst, .block, try l.safeArithmeticBlockPayload(inst, .mul_with_overflow));
            } else if (l.features.has(.scalarize_mul_safe)) {
                const bin_op = l.air_instructions.items(.data)[@intFromEnum(inst)].bin_op;
                if (l.typeOf(bin_op.lhs).isVector(zcu)) {
                    continue :inst l.replaceInst(inst, .block, try l.scalarizeBlockPayload(inst, .bin_op));
                }
            },
            .ptr_add, .ptr_sub => {},
            inline .add_with_overflow,
            .sub_with_overflow,
            .mul_with_overflow,
            .shl_with_overflow,
            => |air_tag| if (l.features.has(comptime .scalarize(air_tag))) {
                const ty_pl = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_pl;
                if (ty_pl.ty.toType().fieldType(0, zcu).isVector(zcu)) {
                    continue :inst l.replaceInst(inst, .block, try l.scalarizeOverflowBlockPayload(inst));
                }
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
                    if (l.features.has(comptime .scalarize(air_tag))) {
                        continue :inst l.replaceInst(inst, .block, try l.scalarizeBlockPayload(inst, .bin_op));
                    }
                }
            },
            inline .not,
            .clz,
            .ctz,
            .popcount,
            .byte_swap,
            .bit_reverse,
            .intcast,
            .trunc,
            => |air_tag| if (l.features.has(comptime .scalarize(air_tag))) {
                const ty_op = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_op;
                if (ty_op.ty.toType().isVector(zcu)) {
                    continue :inst l.replaceInst(inst, .block, try l.scalarizeBlockPayload(inst, .ty_op));
                }
            },
            .abs => {
                const ty_op = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_op;
                switch (l.wantScalarizeOrSoftFloat(.abs, ty_op.ty.toType())) {
                    .none => {},
                    .scalarize => continue :inst l.replaceInst(inst, .block, try l.scalarizeBlockPayload(inst, .ty_op)),
                    .soft_float => continue :inst try l.compilerRtCall(
                        inst,
                        softFloatFunc(.abs, ty_op.ty.toType(), zcu),
                        &.{ty_op.operand},
                        ty_op.ty.toType(),
                    ),
                }
            },
            .fptrunc => {
                const ty_op = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_op;
                const src_ty = l.typeOf(ty_op.operand);
                const dest_ty = ty_op.ty.toType();
                if (src_ty.zigTypeTag(zcu) == .vector) {
                    if (l.features.has(.scalarize_fptrunc) or
                        l.wantSoftFloatScalar(src_ty.childType(zcu)) or
                        l.wantSoftFloatScalar(dest_ty.childType(zcu)))
                    {
                        continue :inst l.replaceInst(inst, .block, try l.scalarizeBlockPayload(inst, .ty_op));
                    }
                } else if (l.wantSoftFloatScalar(src_ty) or l.wantSoftFloatScalar(dest_ty)) {
                    continue :inst try l.compilerRtCall(inst, l.softFptruncFunc(src_ty, dest_ty), &.{ty_op.operand}, dest_ty);
                }
            },
            .fpext => {
                const ty_op = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_op;
                const src_ty = l.typeOf(ty_op.operand);
                const dest_ty = ty_op.ty.toType();
                if (src_ty.zigTypeTag(zcu) == .vector) {
                    if (l.features.has(.scalarize_fpext) or
                        l.wantSoftFloatScalar(src_ty.childType(zcu)) or
                        l.wantSoftFloatScalar(dest_ty.childType(zcu)))
                    {
                        continue :inst l.replaceInst(inst, .block, try l.scalarizeBlockPayload(inst, .ty_op));
                    }
                } else if (l.wantSoftFloatScalar(src_ty) or l.wantSoftFloatScalar(dest_ty)) {
                    continue :inst try l.compilerRtCall(inst, l.softFpextFunc(src_ty, dest_ty), &.{ty_op.operand}, dest_ty);
                }
            },
            inline .int_from_float, .int_from_float_optimized => |air_tag| {
                const ty_op = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_op;
                switch (l.wantScalarizeOrSoftFloat(air_tag, l.typeOf(ty_op.operand))) {
                    .none => {},
                    .scalarize => continue :inst l.replaceInst(inst, .block, try l.scalarizeBlockPayload(inst, .ty_op)),
                    .soft_float => switch (try l.softIntFromFloat(inst)) {
                        .call => |func| continue :inst try l.compilerRtCall(inst, func, &.{ty_op.operand}, ty_op.ty.toType()),
                        .block_payload => |data| continue :inst l.replaceInst(inst, .block, data),
                    },
                }
            },
            .float_from_int => {
                const ty_op = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_op;
                const dest_ty = ty_op.ty.toType();
                switch (l.wantScalarizeOrSoftFloat(.float_from_int, dest_ty)) {
                    .none => {},
                    .scalarize => continue :inst l.replaceInst(inst, .block, try l.scalarizeBlockPayload(inst, .ty_op)),
                    .soft_float => switch (try l.softFloatFromInt(inst)) {
                        .call => |func| continue :inst try l.compilerRtCall(inst, func, &.{ty_op.operand}, dest_ty),
                        .block_payload => |data| continue :inst l.replaceInst(inst, .block, data),
                    },
                }
            },
            .bitcast => if (l.features.has(.scalarize_bitcast)) {
                if (try l.scalarizeBitcastBlockPayload(inst)) |payload| {
                    continue :inst l.replaceInst(inst, .block, payload);
                }
            },
            .intcast_safe => if (l.features.has(.expand_intcast_safe)) {
                assert(!l.features.has(.scalarize_intcast_safe)); // it doesn't make sense to do both
                continue :inst l.replaceInst(inst, .block, try l.safeIntcastBlockPayload(inst));
            } else if (l.features.has(.scalarize_intcast_safe)) {
                const ty_op = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_op;
                if (ty_op.ty.toType().isVector(zcu)) {
                    continue :inst l.replaceInst(inst, .block, try l.scalarizeBlockPayload(inst, .ty_op));
                }
            },
            inline .int_from_float_safe,
            .int_from_float_optimized_safe,
            => |air_tag| {
                const optimized = air_tag == .int_from_float_optimized_safe;
                const expand_feature = switch (air_tag) {
                    .int_from_float_safe => .expand_int_from_float_safe,
                    .int_from_float_optimized_safe => .expand_int_from_float_optimized_safe,
                    else => unreachable,
                };
                if (l.features.has(expand_feature)) {
                    assert(!l.features.has(.scalarize(air_tag)));
                    continue :inst l.replaceInst(inst, .block, try l.safeIntFromFloatBlockPayload(inst, optimized));
                }
                const ty_op = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_op;
                switch (l.wantScalarizeOrSoftFloat(air_tag, l.typeOf(ty_op.operand))) {
                    .none => {},
                    .scalarize => continue :inst l.replaceInst(inst, .block, try l.scalarizeBlockPayload(inst, .ty_op)),
                    // Expand the safety check so that soft-float can rewrite the unchecked operation.
                    .soft_float => continue :inst l.replaceInst(inst, .block, try l.safeIntFromFloatBlockPayload(inst, optimized)),
                }
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
            => |air_tag| {
                const operand = l.air_instructions.items(.data)[@intFromEnum(inst)].un_op;
                const ty = l.typeOf(operand);
                switch (l.wantScalarizeOrSoftFloat(air_tag, ty)) {
                    .none => {},
                    .scalarize => continue :inst l.replaceInst(inst, .block, try l.scalarizeBlockPayload(inst, .un_op)),
                    .soft_float => continue :inst try l.compilerRtCall(
                        inst,
                        softFloatFunc(air_tag, ty, zcu),
                        &.{operand},
                        l.typeOf(operand),
                    ),
                }
            },
            inline .neg, .neg_optimized => |air_tag| {
                const operand = l.air_instructions.items(.data)[@intFromEnum(inst)].un_op;
                switch (l.wantScalarizeOrSoftFloat(air_tag, l.typeOf(operand))) {
                    .none => {},
                    .scalarize => continue :inst l.replaceInst(inst, .block, try l.scalarizeBlockPayload(inst, .un_op)),
                    .soft_float => continue :inst l.replaceInst(inst, .block, try l.softFloatNegBlockPayload(inst, operand)),
                }
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
            => |air_tag| {
                const bin_op = l.air_instructions.items(.data)[@intFromEnum(inst)].bin_op;
                const ty = l.typeOf(bin_op.lhs);
                if (l.wantSoftFloatScalar(ty)) {
                    continue :inst l.replaceInst(
                        inst,
                        .block,
                        try l.softFloatCmpBlockPayload(inst, ty, air_tag.toCmpOp().?, bin_op.lhs, bin_op.rhs),
                    );
                }
            },
            inline .cmp_vector, .cmp_vector_optimized => |air_tag| {
                const ty_pl = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_pl;
                const payload = l.extraData(Air.VectorCmp, ty_pl.payload).data;
                switch (l.wantScalarizeOrSoftFloat(air_tag, l.typeOf(payload.lhs))) {
                    .none => {},
                    .scalarize => continue :inst l.replaceInst(inst, .block, try l.scalarizeBlockPayload(inst, .cmp_vector)),
                    .soft_float => unreachable, // the operand is not a scalar
                }
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
                if (ptr_info.packed_offset.host_size > 0 and ptr_info.flags.vector_index == .none) {
                    continue :inst l.replaceInst(inst, .block, try l.packedLoadBlockPayload(inst));
                }
            },
            .ret, .ret_safe, .ret_load => {},
            .store, .store_safe => if (l.features.has(.expand_packed_store)) {
                const bin_op = l.air_instructions.items(.data)[@intFromEnum(inst)].bin_op;
                const ptr_info = l.typeOf(bin_op.lhs).ptrInfo(zcu);
                if (ptr_info.packed_offset.host_size > 0 and ptr_info.flags.vector_index == .none) {
                    continue :inst l.replaceInst(inst, .block, try l.packedStoreBlockPayload(inst));
                }
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
            inline .reduce, .reduce_optimized => |air_tag| {
                const reduce = l.air_instructions.items(.data)[@intFromEnum(inst)].reduce;
                const vector_ty = l.typeOf(reduce.operand);
                if (l.features.has(.reduce_one_elem_to_bitcast)) {
                    switch (vector_ty.vectorLen(zcu)) {
                        0 => unreachable,
                        1 => continue :inst l.replaceInst(inst, .bitcast, .{ .ty_op = .{
                            .ty = .fromType(vector_ty.childType(zcu)),
                            .operand = reduce.operand,
                        } }),
                        else => {},
                    }
                }
                switch (l.wantScalarizeOrSoftFloat(air_tag, vector_ty)) {
                    .none => {},
                    .scalarize => continue :inst l.replaceInst(
                        inst,
                        .block,
                        try l.scalarizeReduceBlockPayload(inst, air_tag == .reduce_optimized),
                    ),
                    .soft_float => unreachable, // the operand is not a scalar
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
            .shuffle_one => {
                const ty_pl = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_pl;
                switch (l.wantScalarizeOrSoftFloat(.shuffle_one, ty_pl.ty.toType())) {
                    .none => {},
                    .scalarize => continue :inst l.replaceInst(inst, .block, try l.scalarizeShuffleOneBlockPayload(inst)),
                    .soft_float => unreachable, // the operand is not a scalar
                }
            },
            .shuffle_two => {
                const ty_pl = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_pl;
                switch (l.wantScalarizeOrSoftFloat(.shuffle_two, ty_pl.ty.toType())) {
                    .none => {},
                    .scalarize => continue :inst l.replaceInst(inst, .block, try l.scalarizeShuffleTwoBlockPayload(inst)),
                    .soft_float => unreachable, // the operand is not a scalar
                }
            },
            .select => {
                const pl_op = l.air_instructions.items(.data)[@intFromEnum(inst)].pl_op;
                const bin = l.extraData(Air.Bin, pl_op.payload).data;
                switch (l.wantScalarizeOrSoftFloat(.select, l.typeOf(bin.lhs))) {
                    .none => {},
                    .scalarize => continue :inst l.replaceInst(inst, .block, try l.scalarizeBlockPayload(inst, .select)),
                    .soft_float => unreachable, // the operand is not a scalar
                }
            },
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
                    .@"union" => unreachable,
                    .@"struct" => switch (agg_ty.containerLayout(zcu)) {
                        .auto, .@"extern" => {},
                        .@"packed" => switch (agg_ty.structFieldCount(zcu)) {
                            0 => unreachable,
                            // An `aggregate_init` of a packed struct with 1 field is just a fancy bitcast.
                            1 => continue :inst l.replaceInst(inst, .bitcast, .{ .ty_op = .{
                                .ty = .fromType(agg_ty),
                                .operand = @enumFromInt(l.air_extra.items[ty_pl.payload]),
                            } }),
                            else => continue :inst l.replaceInst(inst, .block, try l.packedAggregateInitBlockPayload(inst)),
                        },
                    },
                }
            },
            .union_init, .prefetch => {},
            .mul_add => {
                const pl_op = l.air_instructions.items(.data)[@intFromEnum(inst)].pl_op;
                const ty = l.typeOf(pl_op.operand);
                switch (l.wantScalarizeOrSoftFloat(.mul_add, ty)) {
                    .none => {},
                    .scalarize => continue :inst l.replaceInst(inst, .block, try l.scalarizeBlockPayload(inst, .pl_op_bin)),
                    .soft_float => {
                        const bin = l.extraData(Air.Bin, pl_op.payload).data;
                        const func = softFloatFunc(.mul_add, ty, zcu);
                        continue :inst try l.compilerRtCall(inst, func, &.{ bin.lhs, bin.rhs, pl_op.operand }, ty);
                    },
                }
            },
            .field_parent_ptr,
            .wasm_memory_size,
            .wasm_memory_grow,
            .cmp_lt_errors_len,
            .err_return_trace,
            .set_err_return_trace,
            .addrspace_cast,
            .save_err_return_trace_index,
            .runtime_nav_ptr,
            .c_va_arg,
            .c_va_copy,
            .c_va_end,
            .c_va_start,
            .work_item_id,
            .work_group_size,
            .work_group_id,
            .legalize_vec_elem_val,
            .legalize_vec_store_elem,
            .legalize_compiler_rt_call,
            => {},
        }
    }
}

const ScalarizeForm = enum { un_op, ty_op, bin_op, pl_op_bin, cmp_vector, select };
fn scalarizeBlockPayload(l: *Legalize, orig_inst: Air.Inst.Index, form: ScalarizeForm) Error!Air.Inst.Data {
    const pt = l.pt;
    const zcu = pt.zcu;

    const orig = l.air_instructions.get(@intFromEnum(orig_inst));
    const res_ty = l.typeOfIndex(orig_inst);
    const result_is_array = switch (res_ty.zigTypeTag(zcu)) {
        .vector => false,
        .array => true,
        else => unreachable,
    };
    const res_len = res_ty.arrayLen(zcu);
    const res_elem_ty = res_ty.childType(zcu);

    if (result_is_array) {
        // This is only allowed when legalizing an elementwise bitcast.
        assert(orig.tag == .bitcast);
        assert(form == .ty_op);
    }

    // Our output will be a loop doing elementwise stores:
    //
    // %1 = block(@Vector(N, Scalar), {
    //   %2 = alloc(*usize)
    //   %3 = alloc(*@Vector(N, Scalar))
    //   %4 = store(%2, @zero_usize)
    //   %5 = loop({
    //     %6 = load(%2)
    //     %7 = <scalar result of operation at index %5>
    //     %8 = legalize_vec_store_elem(%3, %5, %6)
    //     %9 = cmp_eq(%6, <usize, N-1>)
    //     %10 = cond_br(%9, {
    //       %11 = load(%3)
    //       %12 = br(%1, %11)
    //     }, {
    //       %13 = add(%6, @one_usize)
    //       %14 = store(%2, %13)
    //       %15 = repeat(%5)
    //     })
    //   })
    // })
    //
    // If scalarizing an elementwise bitcast, the result might be an array, in which case
    // `legalize_vec_store_elem` becomes two instructions (`ptr_elem_ptr` and `store`).
    // Therefore, there are 13 or 14 instructions in the block, plus however many are
    // needed to compute each result element for `form`.
    const inst_per_form: usize = switch (form) {
        .un_op, .ty_op => 2,
        .bin_op, .cmp_vector => 3,
        .pl_op_bin => 4,
        .select => 7,
    };
    const max_inst_per_form = 7; // maximum value in the above switch
    var inst_buf: [14 + max_inst_per_form]Air.Inst.Index = undefined;

    var main_block: Block = .init(&inst_buf);
    try l.air_instructions.ensureUnusedCapacity(zcu.gpa, inst_buf.len);

    const index_ptr = main_block.addTy(l, .alloc, .ptr_usize).toRef();
    const result_ptr = main_block.addTy(l, .alloc, try pt.singleMutPtrType(res_ty)).toRef();

    _ = main_block.addBinOp(l, .store, index_ptr, .zero_usize);

    var loop: Loop = .init(l, &main_block);
    loop.block = .init(main_block.stealRemainingCapacity());

    const index_val = loop.block.addTyOp(l, .load, .usize, index_ptr).toRef();
    const elem_val: Air.Inst.Ref = switch (form) {
        .un_op => elem: {
            const orig_operand = orig.data.un_op;
            const operand = loop.block.addBinOp(l, .legalize_vec_elem_val, orig_operand, index_val).toRef();
            break :elem loop.block.addUnOp(l, orig.tag, operand).toRef();
        },
        .ty_op => elem: {
            const orig_operand = orig.data.ty_op.operand;
            const operand_is_array = switch (l.typeOf(orig_operand).zigTypeTag(zcu)) {
                .vector => false,
                .array => true,
                else => unreachable,
            };
            const operand = loop.block.addBinOp(
                l,
                if (operand_is_array) .array_elem_val else .legalize_vec_elem_val,
                orig_operand,
                index_val,
            ).toRef();
            break :elem loop.block.addTyOp(l, orig.tag, res_elem_ty, operand).toRef();
        },
        .bin_op => elem: {
            const orig_bin = orig.data.bin_op;
            const lhs = loop.block.addBinOp(l, .legalize_vec_elem_val, orig_bin.lhs, index_val).toRef();
            const rhs = loop.block.addBinOp(l, .legalize_vec_elem_val, orig_bin.rhs, index_val).toRef();
            break :elem loop.block.addBinOp(l, orig.tag, lhs, rhs).toRef();
        },
        .pl_op_bin => elem: {
            const orig_operand = orig.data.pl_op.operand;
            const orig_bin = l.extraData(Air.Bin, orig.data.pl_op.payload).data;
            const operand = loop.block.addBinOp(l, .legalize_vec_elem_val, orig_operand, index_val).toRef();
            const lhs = loop.block.addBinOp(l, .legalize_vec_elem_val, orig_bin.lhs, index_val).toRef();
            const rhs = loop.block.addBinOp(l, .legalize_vec_elem_val, orig_bin.rhs, index_val).toRef();
            break :elem loop.block.add(l, .{
                .tag = orig.tag,
                .data = .{ .pl_op = .{
                    .operand = operand,
                    .payload = try l.addExtra(Air.Bin, .{ .lhs = lhs, .rhs = rhs }),
                } },
            }).toRef();
        },
        .cmp_vector => elem: {
            const orig_payload = l.extraData(Air.VectorCmp, orig.data.ty_pl.payload).data;
            const cmp_op = orig_payload.compareOperator();
            const optimized = switch (orig.tag) {
                .cmp_vector => false,
                .cmp_vector_optimized => true,
                else => unreachable,
            };
            const lhs = loop.block.addBinOp(l, .legalize_vec_elem_val, orig_payload.lhs, index_val).toRef();
            const rhs = loop.block.addBinOp(l, .legalize_vec_elem_val, orig_payload.rhs, index_val).toRef();
            break :elem loop.block.addCmpScalar(l, cmp_op, lhs, rhs, optimized).toRef();
        },
        .select => elem: {
            const orig_cond = orig.data.pl_op.operand;
            const orig_bin = l.extraData(Air.Bin, orig.data.pl_op.payload).data;

            const elem_block_inst = loop.block.add(l, .{
                .tag = .block,
                .data = .{ .ty_pl = .{
                    .ty = .fromType(res_elem_ty),
                    .payload = undefined,
                } },
            });
            var elem_block: Block = .init(loop.block.stealCapacity(2));
            const cond = elem_block.addBinOp(l, .legalize_vec_elem_val, orig_cond, index_val).toRef();

            var condbr: CondBr = .init(l, cond, &elem_block, .{});

            condbr.then_block = .init(loop.block.stealCapacity(2));
            const lhs = condbr.then_block.addBinOp(l, .legalize_vec_elem_val, orig_bin.lhs, index_val).toRef();
            condbr.then_block.addBr(l, elem_block_inst, lhs);

            condbr.else_block = .init(loop.block.stealCapacity(2));
            const rhs = condbr.else_block.addBinOp(l, .legalize_vec_elem_val, orig_bin.rhs, index_val).toRef();
            condbr.else_block.addBr(l, elem_block_inst, rhs);

            try condbr.finish(l);

            const inst_data = l.air_instructions.items(.data);
            inst_data[@intFromEnum(elem_block_inst)].ty_pl.payload = try l.addBlockBody(elem_block.body());

            break :elem elem_block_inst.toRef();
        },
    };
    _ = loop.block.stealCapacity(max_inst_per_form - inst_per_form);
    if (result_is_array) {
        const elem_ptr = loop.block.add(l, .{
            .tag = .ptr_elem_ptr,
            .data = .{ .ty_pl = .{
                .ty = .fromType(try pt.singleMutPtrType(res_elem_ty)),
                .payload = try l.addExtra(Air.Bin, .{
                    .lhs = result_ptr,
                    .rhs = index_val,
                }),
            } },
        }).toRef();
        _ = loop.block.addBinOp(l, .store, elem_ptr, elem_val);
    } else {
        _ = loop.block.add(l, .{
            .tag = .legalize_vec_store_elem,
            .data = .{ .pl_op = .{
                .operand = result_ptr,
                .payload = try l.addExtra(Air.Bin, .{
                    .lhs = index_val,
                    .rhs = elem_val,
                }),
            } },
        });
        _ = loop.block.stealCapacity(1);
    }
    const is_end_val = loop.block.addBinOp(l, .cmp_eq, index_val, .fromValue(try pt.intValue(.usize, res_len - 1))).toRef();

    var condbr: CondBr = .init(l, is_end_val, &loop.block, .{});
    condbr.then_block = .init(loop.block.stealRemainingCapacity());
    const result_val = condbr.then_block.addTyOp(l, .load, res_ty, result_ptr).toRef();
    condbr.then_block.addBr(l, orig_inst, result_val);

    condbr.else_block = .init(condbr.then_block.stealRemainingCapacity());
    const new_index_val = condbr.else_block.addBinOp(l, .add, index_val, .one_usize).toRef();
    _ = condbr.else_block.addBinOp(l, .store, index_ptr, new_index_val);
    _ = condbr.else_block.add(l, .{
        .tag = .repeat,
        .data = .{ .repeat = .{ .loop_inst = loop.inst } },
    });

    try condbr.finish(l);

    try loop.finish(l);

    return .{ .ty_pl = .{
        .ty = .fromType(res_ty),
        .payload = try l.addBlockBody(main_block.body()),
    } };
}
fn scalarizeShuffleOneBlockPayload(l: *Legalize, orig_inst: Air.Inst.Index) Error!Air.Inst.Data {
    const pt = l.pt;
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    const shuffle = l.getTmpAir().unwrapShuffleOne(zcu, orig_inst);

    // We're going to emit something like this:
    //
    //   var x: @Vector(N, T) = all_comptime_known_elems;
    //   for (out_idxs, in_idxs) |i, j| x[i] = operand[j];
    //
    // So we must first compute `out_idxs` and `in_idxs`.

    var sfba_state = std.heap.stackFallback(512, gpa);
    const sfba = sfba_state.get();

    const out_idxs_buf = try sfba.alloc(InternPool.Index, shuffle.mask.len);
    defer sfba.free(out_idxs_buf);

    const in_idxs_buf = try sfba.alloc(InternPool.Index, shuffle.mask.len);
    defer sfba.free(in_idxs_buf);

    var n: usize = 0;
    for (shuffle.mask, 0..) |mask, out_idx| switch (mask.unwrap()) {
        .value => {},
        .elem => |in_idx| {
            out_idxs_buf[n] = (try pt.intValue(.usize, out_idx)).toIntern();
            in_idxs_buf[n] = (try pt.intValue(.usize, in_idx)).toIntern();
            n += 1;
        },
    };

    const init_val: Value = init: {
        const undef_val = try pt.undefValue(shuffle.result_ty.childType(zcu));
        const elems = try sfba.alloc(InternPool.Index, shuffle.mask.len);
        defer sfba.free(elems);
        for (shuffle.mask, elems) |mask, *elem| elem.* = switch (mask.unwrap()) {
            .value => |ip_index| ip_index,
            .elem => undef_val.toIntern(),
        };
        break :init try pt.aggregateValue(shuffle.result_ty, elems);
    };

    // %1 = block(@Vector(N, T), {
    //   %2 = alloc(*@Vector(N, T))
    //   %3 = alloc(*usize)
    //   %4 = store(%2, <init_val>)
    //   %5 = [addScalarizedShuffle]
    //   %6 = load(%2)
    //   %7 = br(%1, %6)
    // })

    var inst_buf: [6]Air.Inst.Index = undefined;
    var main_block: Block = .init(&inst_buf);
    try l.air_instructions.ensureUnusedCapacity(gpa, 19);

    const result_ptr = main_block.addTy(l, .alloc, try pt.singleMutPtrType(shuffle.result_ty)).toRef();
    const index_ptr = main_block.addTy(l, .alloc, .ptr_usize).toRef();

    _ = main_block.addBinOp(l, .store, result_ptr, .fromValue(init_val));

    try l.addScalarizedShuffle(
        &main_block,
        shuffle.operand,
        result_ptr,
        index_ptr,
        out_idxs_buf[0..n],
        in_idxs_buf[0..n],
    );

    const result_val = main_block.addTyOp(l, .load, shuffle.result_ty, result_ptr).toRef();
    main_block.addBr(l, orig_inst, result_val);

    return .{ .ty_pl = .{
        .ty = .fromType(shuffle.result_ty),
        .payload = try l.addBlockBody(main_block.body()),
    } };
}
fn scalarizeShuffleTwoBlockPayload(l: *Legalize, orig_inst: Air.Inst.Index) Error!Air.Inst.Data {
    const pt = l.pt;
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    const shuffle = l.getTmpAir().unwrapShuffleTwo(zcu, orig_inst);

    // We're going to emit something like this:
    //
    //   var x: @Vector(N, T) = undefined;
    //   for (out_idxs_a, in_idxs_a) |i, j| x[i] = operand_a[j];
    //   for (out_idxs_b, in_idxs_b) |i, j| x[i] = operand_b[j];
    //
    // The AIR will look like this:
    //
    //   %1 = block(@Vector(N, T), {
    //     %2 = alloc(*@Vector(N, T))
    //     %3 = alloc(*usize)
    //     %4 = store(%2, <@Vector(N, T), undefined>)
    //     %5 = [addScalarizedShuffle]
    //     %6 = [addScalarizedShuffle]
    //     %7 = load(%2)
    //     %8 = br(%1, %7)
    //   })

    var sfba_state = std.heap.stackFallback(512, gpa);
    const sfba = sfba_state.get();

    const out_idxs_buf = try sfba.alloc(InternPool.Index, shuffle.mask.len);
    defer sfba.free(out_idxs_buf);

    const in_idxs_buf = try sfba.alloc(InternPool.Index, shuffle.mask.len);
    defer sfba.free(in_idxs_buf);

    // Iterate `shuffle.mask` before doing anything, because modifying AIR invalidates it.
    const out_idxs_a, const in_idxs_a, const out_idxs_b, const in_idxs_b = idxs: {
        var n: usize = 0;
        for (shuffle.mask, 0..) |mask, out_idx| switch (mask.unwrap()) {
            .undef, .b_elem => {},
            .a_elem => |in_idx| {
                out_idxs_buf[n] = (try pt.intValue(.usize, out_idx)).toIntern();
                in_idxs_buf[n] = (try pt.intValue(.usize, in_idx)).toIntern();
                n += 1;
            },
        };
        const a_len = n;
        for (shuffle.mask, 0..) |mask, out_idx| switch (mask.unwrap()) {
            .undef, .a_elem => {},
            .b_elem => |in_idx| {
                out_idxs_buf[n] = (try pt.intValue(.usize, out_idx)).toIntern();
                in_idxs_buf[n] = (try pt.intValue(.usize, in_idx)).toIntern();
                n += 1;
            },
        };
        break :idxs .{
            out_idxs_buf[0..a_len],
            in_idxs_buf[0..a_len],
            out_idxs_buf[a_len..n],
            in_idxs_buf[a_len..n],
        };
    };

    var inst_buf: [7]Air.Inst.Index = undefined;
    var main_block: Block = .init(&inst_buf);
    try l.air_instructions.ensureUnusedCapacity(gpa, 33);

    const result_ptr = main_block.addTy(l, .alloc, try pt.singleMutPtrType(shuffle.result_ty)).toRef();
    const index_ptr = main_block.addTy(l, .alloc, .ptr_usize).toRef();

    _ = main_block.addBinOp(l, .store, result_ptr, .fromValue(try pt.undefValue(shuffle.result_ty)));

    if (out_idxs_a.len == 0) {
        _ = main_block.stealCapacity(1);
    } else {
        try l.addScalarizedShuffle(
            &main_block,
            shuffle.operand_a,
            result_ptr,
            index_ptr,
            out_idxs_a,
            in_idxs_a,
        );
    }

    if (out_idxs_b.len == 0) {
        _ = main_block.stealCapacity(1);
    } else {
        try l.addScalarizedShuffle(
            &main_block,
            shuffle.operand_b,
            result_ptr,
            index_ptr,
            out_idxs_b,
            in_idxs_b,
        );
    }

    const result_val = main_block.addTyOp(l, .load, shuffle.result_ty, result_ptr).toRef();
    main_block.addBr(l, orig_inst, result_val);

    return .{ .ty_pl = .{
        .ty = .fromType(shuffle.result_ty),
        .payload = try l.addBlockBody(main_block.body()),
    } };
}
/// Adds code to `parent_block` which behaves like this loop:
///
///   for (out_idxs, in_idxs) |i, j| result_vec_ptr[i] = operand_vec[j];
///
/// The actual AIR adds exactly one instruction to `parent_block` itself and 14 instructions
/// overall, and is as follows:
///
///   %1 = block(void, {
///     %2 = store(index_ptr, @zero_usize)
///     %3 = loop({
///       %4 = load(index_ptr)
///       %5 = ptr_elem_val(out_idxs_ptr, %4)
///       %6 = ptr_elem_val(in_idxs_ptr, %4)
///       %7 = legalize_vec_elem_val(operand_vec, %6)
///       %8 = legalize_vec_store_elem(result_vec_ptr, %4, %7)
///       %9 = cmp_eq(%4, <usize, out_idxs.len-1>)
///       %10 = cond_br(%9, {
///         %11 = br(%1, @void_value)
///       }, {
///         %12 = add(%4, @one_usize)
///         %13 = store(index_ptr, %12)
///         %14 = repeat(%3)
///       })
///     })
///   })
///
/// The caller is responsible for reserving space in `l.air_instructions`.
fn addScalarizedShuffle(
    l: *Legalize,
    parent_block: *Block,
    operand_vec: Air.Inst.Ref,
    result_vec_ptr: Air.Inst.Ref,
    index_ptr: Air.Inst.Ref,
    out_idxs: []const InternPool.Index,
    in_idxs: []const InternPool.Index,
) Error!void {
    const pt = l.pt;

    assert(out_idxs.len == in_idxs.len);
    const n = out_idxs.len;

    const idxs_ty = try pt.arrayType(.{ .len = n, .child = .usize_type });
    const idxs_ptr_ty = try pt.singleConstPtrType(idxs_ty);
    const manyptr_usize_ty = try pt.manyConstPtrType(.usize);

    const out_idxs_ptr = try pt.intern(.{ .ptr = .{
        .ty = manyptr_usize_ty.toIntern(),
        .base_addr = .{ .uav = .{
            .val = (try pt.aggregateValue(idxs_ty, out_idxs)).toIntern(),
            .orig_ty = idxs_ptr_ty.toIntern(),
        } },
        .byte_offset = 0,
    } });
    const in_idxs_ptr = try pt.intern(.{ .ptr = .{
        .ty = manyptr_usize_ty.toIntern(),
        .base_addr = .{ .uav = .{
            .val = (try pt.aggregateValue(idxs_ty, in_idxs)).toIntern(),
            .orig_ty = idxs_ptr_ty.toIntern(),
        } },
        .byte_offset = 0,
    } });

    const main_block_inst = parent_block.add(l, .{
        .tag = .block,
        .data = .{ .ty_pl = .{
            .ty = .void_type,
            .payload = undefined,
        } },
    });

    var inst_buf: [13]Air.Inst.Index = undefined;
    var main_block: Block = .init(&inst_buf);

    _ = main_block.addBinOp(l, .store, index_ptr, .zero_usize);

    var loop: Loop = .init(l, &main_block);
    loop.block = .init(main_block.stealRemainingCapacity());

    const index_val = loop.block.addTyOp(l, .load, .usize, index_ptr).toRef();
    const in_idx_val = loop.block.addBinOp(l, .ptr_elem_val, .fromIntern(in_idxs_ptr), index_val).toRef();
    const out_idx_val = loop.block.addBinOp(l, .ptr_elem_val, .fromIntern(out_idxs_ptr), index_val).toRef();

    const elem_val = loop.block.addBinOp(l, .legalize_vec_elem_val, operand_vec, in_idx_val).toRef();
    _ = loop.block.add(l, .{
        .tag = .legalize_vec_store_elem,
        .data = .{ .pl_op = .{
            .operand = result_vec_ptr,
            .payload = try l.addExtra(Air.Bin, .{
                .lhs = out_idx_val,
                .rhs = elem_val,
            }),
        } },
    });

    const is_end_val = loop.block.addBinOp(l, .cmp_eq, index_val, .fromValue(try pt.intValue(.usize, n - 1))).toRef();
    var condbr: CondBr = .init(l, is_end_val, &loop.block, .{});
    condbr.then_block = .init(loop.block.stealRemainingCapacity());
    condbr.then_block.addBr(l, main_block_inst, .void_value);

    condbr.else_block = .init(condbr.then_block.stealRemainingCapacity());
    const new_index_val = condbr.else_block.addBinOp(l, .add, index_val, .one_usize).toRef();
    _ = condbr.else_block.addBinOp(l, .store, index_ptr, new_index_val);
    _ = condbr.else_block.add(l, .{
        .tag = .repeat,
        .data = .{ .repeat = .{ .loop_inst = loop.inst } },
    });

    try condbr.finish(l);
    try loop.finish(l);

    const inst_data = l.air_instructions.items(.data);
    inst_data[@intFromEnum(main_block_inst)].ty_pl.payload = try l.addBlockBody(main_block.body());
}
fn scalarizeBitcastBlockPayload(l: *Legalize, orig_inst: Air.Inst.Index) Error!?Air.Inst.Data {
    const pt = l.pt;
    const zcu = pt.zcu;

    const ty_op = l.air_instructions.items(.data)[@intFromEnum(orig_inst)].ty_op;

    const dest_ty = ty_op.ty.toType();
    const dest_legal = switch (dest_ty.zigTypeTag(zcu)) {
        else => true,
        .array, .vector => legal: {
            if (dest_ty.arrayLen(zcu) == 1) break :legal true;
            const dest_elem_ty = dest_ty.childType(zcu);
            break :legal dest_elem_ty.bitSize(zcu) == 8 * dest_elem_ty.abiSize(zcu);
        },
    };

    const operand_ty = l.typeOf(ty_op.operand);
    const operand_legal = switch (operand_ty.zigTypeTag(zcu)) {
        else => true,
        .array, .vector => legal: {
            if (operand_ty.arrayLen(zcu) == 1) break :legal true;
            const operand_elem_ty = operand_ty.childType(zcu);
            break :legal operand_elem_ty.bitSize(zcu) == 8 * operand_elem_ty.abiSize(zcu);
        },
    };

    if (dest_legal and operand_legal) return null;

    if (!operand_legal and !dest_legal and operand_ty.arrayLen(zcu) == dest_ty.arrayLen(zcu)) {
        // from_ty and to_ty are both arrays or vectors of types with the same bit size,
        // so we can do an elementwise bitcast.
        return try l.scalarizeBlockPayload(orig_inst, .ty_op);
    }

    // Fallback path. Our strategy is to use an unsigned integer type as an intermediate
    // "bag of bits" representation which can be manipulated by bitwise operations.

    const num_bits: u16 = @intCast(dest_ty.bitSize(zcu));
    assert(operand_ty.bitSize(zcu) == num_bits);
    const uint_ty = try pt.intType(.unsigned, num_bits);
    const shift_ty = try pt.intType(.unsigned, std.math.log2_int_ceil(u16, num_bits));

    var inst_buf: [39]Air.Inst.Index = undefined;
    var main_block: Block = .init(&inst_buf);
    try l.air_instructions.ensureUnusedCapacity(zcu.gpa, inst_buf.len);

    // First, convert `operand_ty` to `uint_ty` (`uN`).

    const uint_val: Air.Inst.Ref = uint_val: {
        if (operand_legal) {
            _ = main_block.stealCapacity(19);
            break :uint_val main_block.addBitCast(l, uint_ty, ty_op.operand);
        }

        // %1 = block({
        //   %2 = alloc(*usize)
        //   %3 = alloc(*uN)
        //   %4 = store(%2, <usize, operand_len>)
        //   %5 = store(%3, <uN, 0>)
        //   %6 = loop({
        //     %7 = load(%2)
        //     %8 = array_elem_val(orig_operand, %7)
        //     %9 = bitcast(uE, %8)
        //     %10 = intcast(uN, %9)
        //     %11 = load(%3)
        //     %12 = shl_exact(%11, <uS, E>)
        //     %13 = bit_or(%12, %10)
        //     %14 = cmp_eq(%4, @zero_usize)
        //     %15 = cond_br(%14, {
        //       %16 = br(%1, %13)
        //     }, {
        //       %17 = store(%3, %13)
        //       %18 = sub(%7, @one_usize)
        //       %19 = store(%2, %18)
        //       %20 = repeat(%6)
        //     })
        //   })
        // })

        const elem_bits = operand_ty.childType(zcu).bitSize(zcu);
        const elem_bits_val = try pt.intValue(shift_ty, elem_bits);
        const elem_uint_ty = try pt.intType(.unsigned, @intCast(elem_bits));

        const uint_block_inst = main_block.add(l, .{
            .tag = .block,
            .data = .{ .ty_pl = .{
                .ty = .fromType(uint_ty),
                .payload = undefined,
            } },
        });
        var uint_block: Block = .init(main_block.stealCapacity(19));

        const index_ptr = uint_block.addTy(l, .alloc, .ptr_usize).toRef();
        const result_ptr = uint_block.addTy(l, .alloc, try pt.singleMutPtrType(uint_ty)).toRef();
        _ = uint_block.addBinOp(
            l,
            .store,
            index_ptr,
            .fromValue(try pt.intValue(.usize, operand_ty.arrayLen(zcu))),
        );
        _ = uint_block.addBinOp(l, .store, result_ptr, .fromValue(try pt.intValue(uint_ty, 0)));

        var loop: Loop = .init(l, &uint_block);
        loop.block = .init(uint_block.stealRemainingCapacity());

        const index_val = loop.block.addTyOp(l, .load, .usize, index_ptr).toRef();
        const raw_elem = loop.block.addBinOp(
            l,
            if (operand_ty.zigTypeTag(zcu) == .vector) .legalize_vec_elem_val else .array_elem_val,
            ty_op.operand,
            index_val,
        ).toRef();
        const elem_uint = loop.block.addBitCast(l, elem_uint_ty, raw_elem);
        const elem_extended = loop.block.addTyOp(l, .intcast, uint_ty, elem_uint).toRef();
        const old_result = loop.block.addTyOp(l, .load, uint_ty, result_ptr).toRef();
        const shifted_result = loop.block.addBinOp(l, .shl_exact, old_result, .fromValue(elem_bits_val)).toRef();
        const new_result = loop.block.addBinOp(l, .bit_or, shifted_result, elem_extended).toRef();

        const is_end_val = loop.block.addBinOp(l, .cmp_eq, index_val, .zero_usize).toRef();
        var condbr: CondBr = .init(l, is_end_val, &loop.block, .{});

        condbr.then_block = .init(loop.block.stealRemainingCapacity());
        condbr.then_block.addBr(l, uint_block_inst, new_result);

        condbr.else_block = .init(condbr.then_block.stealRemainingCapacity());
        _ = condbr.else_block.addBinOp(l, .store, result_ptr, new_result);
        const new_index_val = condbr.else_block.addBinOp(l, .sub, index_val, .one_usize).toRef();
        _ = condbr.else_block.addBinOp(l, .store, index_ptr, new_index_val);
        _ = condbr.else_block.add(l, .{
            .tag = .repeat,
            .data = .{ .repeat = .{ .loop_inst = loop.inst } },
        });

        try condbr.finish(l);
        try loop.finish(l);

        const inst_data = l.air_instructions.items(.data);
        inst_data[@intFromEnum(uint_block_inst)].ty_pl.payload = try l.addBlockBody(uint_block.body());

        break :uint_val uint_block_inst.toRef();
    };

    // Now convert `uint_ty` (`uN`) to `dest_ty`.

    if (dest_legal) {
        _ = main_block.stealCapacity(17);
        const result = main_block.addBitCast(l, dest_ty, uint_val);
        main_block.addBr(l, orig_inst, result);
    } else {
        // %1 = alloc(*usize)
        // %2 = alloc(*@Vector(N, Result))
        // %3 = store(%1, @zero_usize)
        // %4 = loop({
        //   %5 = load(%1)
        //   %6 = mul(%5, <usize, E>)
        //   %7 = intcast(uS, %6)
        //   %8 = shr(uint_val, %7)
        //   %9 = trunc(uE, %8)
        //   %10 = bitcast(Result, %9)
        //   %11 = legalize_vec_store_elem(%2, %5, %10)
        //   %12 = cmp_eq(%5, <usize, vec_len>)
        //   %13 = cond_br(%12, {
        //     %14 = load(%2)
        //     %15 = br(%0, %14)
        //   }, {
        //     %16 = add(%5, @one_usize)
        //     %17 = store(%1, %16)
        //     %18 = repeat(%4)
        //   })
        // })
        //
        // The result might be an array, in which case `legalize_vec_store_elem`
        // becomes `ptr_elem_ptr` followed by `store`.

        const elem_ty = dest_ty.childType(zcu);
        const elem_bits = elem_ty.bitSize(zcu);
        const elem_uint_ty = try pt.intType(.unsigned, @intCast(elem_bits));

        const index_ptr = main_block.addTy(l, .alloc, .ptr_usize).toRef();
        const result_ptr = main_block.addTy(l, .alloc, try pt.singleMutPtrType(dest_ty)).toRef();
        _ = main_block.addBinOp(l, .store, index_ptr, .zero_usize);

        var loop: Loop = .init(l, &main_block);
        loop.block = .init(main_block.stealRemainingCapacity());

        const index_val = loop.block.addTyOp(l, .load, .usize, index_ptr).toRef();
        const bit_offset = loop.block.addBinOp(l, .mul, index_val, .fromValue(try pt.intValue(.usize, elem_bits))).toRef();
        const casted_bit_offset = loop.block.addTyOp(l, .intcast, shift_ty, bit_offset).toRef();
        const shifted_uint = loop.block.addBinOp(l, .shr, index_val, casted_bit_offset).toRef();
        const elem_uint = loop.block.addTyOp(l, .trunc, elem_uint_ty, shifted_uint).toRef();
        const elem_val = loop.block.addBitCast(l, elem_ty, elem_uint);
        switch (dest_ty.zigTypeTag(zcu)) {
            .array => {
                const elem_ptr = loop.block.add(l, .{
                    .tag = .ptr_elem_ptr,
                    .data = .{ .ty_pl = .{
                        .ty = .fromType(try pt.singleMutPtrType(elem_ty)),
                        .payload = try l.addExtra(Air.Bin, .{
                            .lhs = result_ptr,
                            .rhs = index_val,
                        }),
                    } },
                }).toRef();
                _ = loop.block.addBinOp(l, .store, elem_ptr, elem_val);
            },
            .vector => {
                _ = loop.block.add(l, .{
                    .tag = .legalize_vec_store_elem,
                    .data = .{ .pl_op = .{
                        .operand = result_ptr,
                        .payload = try l.addExtra(Air.Bin, .{
                            .lhs = index_val,
                            .rhs = elem_val,
                        }),
                    } },
                });
                _ = loop.block.stealCapacity(1);
            },
            else => unreachable,
        }

        const is_end_val = loop.block.addBinOp(l, .cmp_eq, index_val, .fromValue(try pt.intValue(.usize, dest_ty.arrayLen(zcu) - 1))).toRef();

        var condbr: CondBr = .init(l, is_end_val, &loop.block, .{});

        condbr.then_block = .init(loop.block.stealRemainingCapacity());
        const result_val = condbr.then_block.addTyOp(l, .load, dest_ty, result_ptr).toRef();
        condbr.then_block.addBr(l, orig_inst, result_val);

        condbr.else_block = .init(condbr.then_block.stealRemainingCapacity());
        const new_index_val = condbr.else_block.addBinOp(l, .add, index_val, .one_usize).toRef();
        _ = condbr.else_block.addBinOp(l, .store, index_ptr, new_index_val);
        _ = condbr.else_block.add(l, .{
            .tag = .repeat,
            .data = .{ .repeat = .{ .loop_inst = loop.inst } },
        });

        try condbr.finish(l);
        try loop.finish(l);
    }

    return .{ .ty_pl = .{
        .ty = .fromType(dest_ty),
        .payload = try l.addBlockBody(main_block.body()),
    } };
}
fn scalarizeOverflowBlockPayload(l: *Legalize, orig_inst: Air.Inst.Index) Error!Air.Inst.Data {
    const pt = l.pt;
    const zcu = pt.zcu;

    const orig = l.air_instructions.get(@intFromEnum(orig_inst));
    const orig_operands = l.extraData(Air.Bin, orig.data.ty_pl.payload).data;

    const vec_tuple_ty = l.typeOfIndex(orig_inst);
    const vec_int_ty = vec_tuple_ty.fieldType(0, zcu);
    const vec_overflow_ty = vec_tuple_ty.fieldType(1, zcu);

    assert(l.typeOf(orig_operands.lhs).toIntern() == vec_int_ty.toIntern());
    if (orig.tag != .shl_with_overflow) {
        assert(l.typeOf(orig_operands.rhs).toIntern() == vec_int_ty.toIntern());
    }

    const scalar_int_ty = vec_int_ty.childType(zcu);
    const scalar_tuple_ty = try pt.overflowArithmeticTupleType(scalar_int_ty);

    // %1 = block(struct { @Vector(N, Int), @Vector(N, u1) }, {
    //   %2 = alloc(*usize)
    //   %3 = alloc(*struct { @Vector(N, Int), @Vector(N, u1) })
    //   %4 = struct_field_ptr_index_0(*@Vector(N, Int), %3)
    //   %5 = struct_field_ptr_index_1(*@Vector(N, u1), %3)
    //   %6 = store(%2, @zero_usize)
    //   %7 = loop({
    //     %8 = load(%2)
    //     %9 = legalize_vec_elem_val(orig_lhs, %8)
    //     %10 = legalize_vec_elem_val(orig_rhs, %8)
    //     %11 = ???_with_overflow(struct { Int, u1 }, %9, %10)
    //     %12 = struct_field_val(%11, 0)
    //     %13 = struct_field_val(%11, 1)
    //     %14 = legalize_vec_store_elem(%4, %8, %12)
    //     %15 = legalize_vec_store_elem(%4, %8, %13)
    //     %16 = cmp_eq(%8, <usize, N-1>)
    //     %17 = cond_br(%16, {
    //       %18 = load(%3)
    //       %19 = br(%1, %18)
    //     }, {
    //       %20 = add(%8, @one_usize)
    //       %21 = store(%2, %20)
    //       %22 = repeat(%7)
    //     })
    //   })
    // })

    const elems_len = vec_int_ty.vectorLen(zcu);

    var inst_buf: [21]Air.Inst.Index = undefined;
    var main_block: Block = .init(&inst_buf);
    try l.air_instructions.ensureUnusedCapacity(zcu.gpa, inst_buf.len);

    const index_ptr = main_block.addTy(l, .alloc, .ptr_usize).toRef();
    const result_ptr = main_block.addTy(l, .alloc, try pt.singleMutPtrType(vec_tuple_ty)).toRef();
    const result_int_ptr = main_block.addTyOp(
        l,
        .struct_field_ptr_index_0,
        try pt.singleMutPtrType(vec_int_ty),
        result_ptr,
    ).toRef();
    const result_overflow_ptr = main_block.addTyOp(
        l,
        .struct_field_ptr_index_1,
        try pt.singleMutPtrType(vec_overflow_ty),
        result_ptr,
    ).toRef();

    _ = main_block.addBinOp(l, .store, index_ptr, .zero_usize);

    var loop: Loop = .init(l, &main_block);
    loop.block = .init(main_block.stealRemainingCapacity());

    const index_val = loop.block.addTyOp(l, .load, .usize, index_ptr).toRef();
    const lhs = loop.block.addBinOp(l, .legalize_vec_elem_val, orig_operands.lhs, index_val).toRef();
    const rhs = loop.block.addBinOp(l, .legalize_vec_elem_val, orig_operands.rhs, index_val).toRef();
    const elem_result = loop.block.add(l, .{
        .tag = orig.tag,
        .data = .{ .ty_pl = .{
            .ty = .fromType(scalar_tuple_ty),
            .payload = try l.addExtra(Air.Bin, .{ .lhs = lhs, .rhs = rhs }),
        } },
    }).toRef();
    const int_elem = loop.block.add(l, .{
        .tag = .struct_field_val,
        .data = .{ .ty_pl = .{
            .ty = .fromType(scalar_int_ty),
            .payload = try l.addExtra(Air.StructField, .{
                .struct_operand = elem_result,
                .field_index = 0,
            }),
        } },
    }).toRef();
    const overflow_elem = loop.block.add(l, .{
        .tag = .struct_field_val,
        .data = .{ .ty_pl = .{
            .ty = .u1_type,
            .payload = try l.addExtra(Air.StructField, .{
                .struct_operand = elem_result,
                .field_index = 1,
            }),
        } },
    }).toRef();
    _ = loop.block.add(l, .{
        .tag = .legalize_vec_store_elem,
        .data = .{ .pl_op = .{
            .operand = result_int_ptr,
            .payload = try l.addExtra(Air.Bin, .{
                .lhs = index_val,
                .rhs = int_elem,
            }),
        } },
    });
    _ = loop.block.add(l, .{
        .tag = .legalize_vec_store_elem,
        .data = .{ .pl_op = .{
            .operand = result_overflow_ptr,
            .payload = try l.addExtra(Air.Bin, .{
                .lhs = index_val,
                .rhs = overflow_elem,
            }),
        } },
    });

    const is_end_val = loop.block.addBinOp(l, .cmp_eq, index_val, .fromValue(try pt.intValue(.usize, elems_len - 1))).toRef();
    var condbr: CondBr = .init(l, is_end_val, &loop.block, .{});

    condbr.then_block = .init(loop.block.stealRemainingCapacity());
    const result_val = condbr.then_block.addTyOp(l, .load, vec_tuple_ty, result_ptr).toRef();
    condbr.then_block.addBr(l, orig_inst, result_val);

    condbr.else_block = .init(condbr.then_block.stealRemainingCapacity());
    const new_index_val = condbr.else_block.addBinOp(l, .add, index_val, .one_usize).toRef();
    _ = condbr.else_block.addBinOp(l, .store, index_ptr, new_index_val);
    _ = condbr.else_block.add(l, .{
        .tag = .repeat,
        .data = .{ .repeat = .{ .loop_inst = loop.inst } },
    });

    try condbr.finish(l);
    try loop.finish(l);

    return .{ .ty_pl = .{
        .ty = .fromType(vec_tuple_ty),
        .payload = try l.addBlockBody(main_block.body()),
    } };
}
fn scalarizeReduceBlockPayload(l: *Legalize, orig_inst: Air.Inst.Index, optimized: bool) Error!Air.Inst.Data {
    const pt = l.pt;
    const zcu = pt.zcu;

    const reduce = l.air_instructions.items(.data)[@intFromEnum(orig_inst)].reduce;

    const vector_ty = l.typeOf(reduce.operand);
    const scalar_ty = vector_ty.childType(zcu);

    const ident_val: Value = switch (reduce.operation) {
        // identity for add is 0; identity for OR and XOR is all 0 bits
        .Or, .Xor, .Add => switch (scalar_ty.zigTypeTag(zcu)) {
            .int => try pt.intValue(scalar_ty, 0),
            .float => try pt.floatValue(scalar_ty, 0.0),
            else => unreachable,
        },
        // identity for multiplication is 1
        .Mul => switch (scalar_ty.zigTypeTag(zcu)) {
            .int => try pt.intValue(scalar_ty, 1),
            .float => try pt.floatValue(scalar_ty, 1.0),
            else => unreachable,
        },
        // identity for AND is all 1 bits
        .And => switch (scalar_ty.intInfo(zcu).signedness) {
            .unsigned => try scalar_ty.maxIntScalar(pt, scalar_ty),
            .signed => try pt.intValue(scalar_ty, -1),
        },
        // identity for @min is maximum value
        .Min => switch (scalar_ty.zigTypeTag(zcu)) {
            .int => try scalar_ty.maxIntScalar(pt, scalar_ty),
            .float => try pt.floatValue(scalar_ty, std.math.inf(f32)),
            else => unreachable,
        },
        // identity for @max is minimum value
        .Max => switch (scalar_ty.zigTypeTag(zcu)) {
            .int => try scalar_ty.minIntScalar(pt, scalar_ty),
            .float => try pt.floatValue(scalar_ty, -std.math.inf(f32)),
            else => unreachable,
        },
    };

    const op_tag: Air.Inst.Tag = switch (reduce.operation) {
        .Or => .bit_or,
        .And => .bit_and,
        .Xor => .xor,
        .Min => .min,
        .Max => .max,
        .Add => switch (scalar_ty.zigTypeTag(zcu)) {
            .int => .add_wrap,
            .float => if (optimized) .add_optimized else .add,
            else => unreachable,
        },
        .Mul => switch (scalar_ty.zigTypeTag(zcu)) {
            .int => .mul_wrap,
            .float => if (optimized) .mul_optimized else .mul,
            else => unreachable,
        },
    };

    // %1 = block(Scalar, {
    //   %2 = alloc(*usize)
    //   %3 = alloc(*Scalar)
    //   %4 = store(%2, @zero_usize)
    //   %5 = store(%3, <Scalar, 0>)  // or whatever the identity is for this operator
    //   %6 = loop({
    //     %7 = load(%2)
    //     %8 = legalize_vec_elem_val(orig_operand, %7)
    //     %9 = load(%3)
    //     %10 = add(%8, %9)  // or whatever the operator is
    //     %11 = cmp_eq(%7, <usize, N-1>)
    //     %12 = cond_br(%11, {
    //       %13 = br(%1, %10)
    //     }, {
    //       %14 = store(%3, %10)
    //       %15 = add(%7, @one_usize)
    //       %16 = store(%2, %15)
    //       %17 = repeat(%6)
    //     })
    //   })
    // })

    var inst_buf: [16]Air.Inst.Index = undefined;
    var main_block: Block = .init(&inst_buf);
    try l.air_instructions.ensureUnusedCapacity(zcu.gpa, inst_buf.len);

    const index_ptr = main_block.addTy(l, .alloc, .ptr_usize).toRef();
    const accum_ptr = main_block.addTy(l, .alloc, try pt.singleMutPtrType(scalar_ty)).toRef();
    _ = main_block.addBinOp(l, .store, index_ptr, .zero_usize);
    _ = main_block.addBinOp(l, .store, accum_ptr, .fromValue(ident_val));

    var loop: Loop = .init(l, &main_block);
    loop.block = .init(main_block.stealRemainingCapacity());

    const index_val = loop.block.addTyOp(l, .load, .usize, index_ptr).toRef();
    const elem_val = loop.block.addBinOp(l, .legalize_vec_elem_val, reduce.operand, index_val).toRef();
    const old_accum = loop.block.addTyOp(l, .load, scalar_ty, accum_ptr).toRef();
    const new_accum = loop.block.addBinOp(l, op_tag, old_accum, elem_val).toRef();

    const is_end_val = loop.block.addBinOp(l, .cmp_eq, index_val, .fromValue(try pt.intValue(.usize, vector_ty.vectorLen(zcu) - 1))).toRef();

    var condbr: CondBr = .init(l, is_end_val, &loop.block, .{});

    condbr.then_block = .init(loop.block.stealRemainingCapacity());
    condbr.then_block.addBr(l, orig_inst, new_accum);

    condbr.else_block = .init(condbr.then_block.stealRemainingCapacity());
    _ = condbr.else_block.addBinOp(l, .store, accum_ptr, new_accum);
    const new_index_val = condbr.else_block.addBinOp(l, .add, index_val, .one_usize).toRef();
    _ = condbr.else_block.addBinOp(l, .store, index_ptr, new_index_val);
    _ = condbr.else_block.add(l, .{
        .tag = .repeat,
        .data = .{ .repeat = .{ .loop_inst = loop.inst } },
    });

    try condbr.finish(l);
    try loop.finish(l);

    return .{ .ty_pl = .{
        .ty = .fromType(scalar_ty),
        .payload = try l.addBlockBody(main_block.body()),
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
    try l.air_instructions.ensureUnusedCapacity(gpa, inst_buf.len);
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

    const agg_bits: u16 = @intCast(agg_ty.bitSize(zcu));
    const bit_offset = zcu.structPackedFieldBitOffset(zcu.typeToStruct(agg_ty).?, orig_extra.field_index);

    const agg_int_ty = try pt.intType(.unsigned, agg_bits);
    const field_int_ty = try pt.intType(.unsigned, @intCast(field_ty.bitSize(zcu)));

    const agg_shift_ty = try pt.intType(.unsigned, std.math.log2_int_ceil(u16, agg_bits));
    const bit_offset_ref: Air.Inst.Ref = .fromValue(try pt.intValue(agg_shift_ty, bit_offset));

    var inst_buf: [5]Air.Inst.Index = undefined;
    var main_block: Block = .init(&inst_buf);
    try l.air_instructions.ensureUnusedCapacity(zcu.gpa, inst_buf.len);

    const agg_int = main_block.addBitCast(l, agg_int_ty, orig_extra.struct_operand);
    const shifted_agg_int = main_block.addBinOp(l, .shr, agg_int, bit_offset_ref).toRef();
    const field_int = main_block.addTyOp(l, .trunc, field_int_ty, shifted_agg_int).toRef();
    const field_val = main_block.addBitCast(l, field_ty, field_int);
    main_block.addBr(l, orig_inst, field_val);

    return .{ .ty_pl = .{
        .ty = .fromType(field_ty),
        .payload = try l.addBlockBody(main_block.body()),
    } };
}
fn packedAggregateInitBlockPayload(l: *Legalize, orig_inst: Air.Inst.Index) Error!Air.Inst.Data {
    const pt = l.pt;
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    const orig_ty_pl = l.air_instructions.items(.data)[@intFromEnum(orig_inst)].ty_pl;
    const agg_ty = orig_ty_pl.ty.toType();
    const agg_field_count = agg_ty.structFieldCount(zcu);

    var sfba_state = std.heap.stackFallback(@sizeOf([4 * 32 + 2]Air.Inst.Index), gpa);
    const sfba = sfba_state.get();

    const inst_buf = try sfba.alloc(Air.Inst.Index, 4 * agg_field_count + 2);
    defer sfba.free(inst_buf);

    var main_block: Block = .init(inst_buf);
    try l.air_instructions.ensureUnusedCapacity(gpa, inst_buf.len);

    const num_bits: u16 = @intCast(agg_ty.bitSize(zcu));
    const shift_ty = try pt.intType(.unsigned, std.math.log2_int_ceil(u16, num_bits));
    const uint_ty = try pt.intType(.unsigned, num_bits);
    var cur_uint: Air.Inst.Ref = .fromValue(try pt.intValue(uint_ty, 0));

    var field_idx = agg_field_count;
    while (field_idx > 0) {
        field_idx -= 1;
        const field_ty = agg_ty.fieldType(field_idx, zcu);
        const field_uint_ty = try pt.intType(.unsigned, @intCast(field_ty.bitSize(zcu)));
        const field_bit_size_ref: Air.Inst.Ref = .fromValue(try pt.intValue(shift_ty, field_ty.bitSize(zcu)));
        const field_val: Air.Inst.Ref = @enumFromInt(l.air_extra.items[orig_ty_pl.payload + field_idx]);

        const shifted = main_block.addBinOp(l, .shl_exact, cur_uint, field_bit_size_ref).toRef();
        const field_as_uint = main_block.addBitCast(l, field_uint_ty, field_val);
        const field_extended = main_block.addTyOp(l, .intcast, uint_ty, field_as_uint).toRef();
        cur_uint = main_block.addBinOp(l, .bit_or, shifted, field_extended).toRef();
    }

    const result = main_block.addBitCast(l, agg_ty, cur_uint);
    main_block.addBr(l, orig_inst, result);

    return .{ .ty_pl = .{
        .ty = .fromType(agg_ty),
        .payload = try l.addBlockBody(main_block.body()),
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
    fn addBr(b: *Block, l: *Legalize, target: Air.Inst.Index, operand: Air.Inst.Ref) void {
        _ = b.add(l, .{
            .tag = .br,
            .data = .{ .br = .{ .block_inst = target, .operand = operand } },
        });
    }
    fn addTy(b: *Block, l: *Legalize, tag: Air.Inst.Tag, ty: Type) Air.Inst.Index {
        return b.add(l, .{ .tag = tag, .data = .{ .ty = ty } });
    }
    fn addBinOp(b: *Block, l: *Legalize, tag: Air.Inst.Tag, lhs: Air.Inst.Ref, rhs: Air.Inst.Ref) Air.Inst.Index {
        return b.add(l, .{
            .tag = tag,
            .data = .{ .bin_op = .{ .lhs = lhs, .rhs = rhs } },
        });
    }
    fn addUnOp(b: *Block, l: *Legalize, tag: Air.Inst.Tag, operand: Air.Inst.Ref) Air.Inst.Index {
        return b.add(l, .{
            .tag = tag,
            .data = .{ .un_op = operand },
        });
    }
    fn addTyOp(b: *Block, l: *Legalize, tag: Air.Inst.Tag, ty: Type, operand: Air.Inst.Ref) Air.Inst.Index {
        return b.add(l, .{
            .tag = tag,
            .data = .{ .ty_op = .{
                .ty = .fromType(ty),
                .operand = operand,
            } },
        });
    }

    fn addCompilerRtCall(b: *Block, l: *Legalize, func: Air.CompilerRtFunc, args: []const Air.Inst.Ref) Error!Air.Inst.Index {
        return b.add(l, .{
            .tag = .legalize_compiler_rt_call,
            .data = .{ .legalize_compiler_rt_call = .{
                .func = func,
                .payload = payload: {
                    const extra_len = @typeInfo(Air.Call).@"struct".fields.len + args.len;
                    try l.air_extra.ensureUnusedCapacity(l.pt.zcu.gpa, extra_len);
                    const index = l.addExtra(Air.Call, .{ .args_len = @intCast(args.len) }) catch unreachable;
                    l.air_extra.appendSliceAssumeCapacity(@ptrCast(args));
                    break :payload index;
                },
            } },
        });
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
        return addCmpScalar(b, l, op, lhs, rhs, opts.optimized);
    }

    /// Similar to `addCmp`, but for scalars only. Unlike `addCmp`, this function is
    /// infallible, because it doesn't need to add entries to `extra`.
    fn addCmpScalar(
        b: *Block,
        l: *Legalize,
        op: std.math.CompareOperator,
        lhs: Air.Inst.Ref,
        rhs: Air.Inst.Ref,
        optimized: bool,
    ) Air.Inst.Index {
        return b.add(l, .{
            .tag = .fromCmpOp(op, optimized),
            .data = .{ .bin_op = .{
                .lhs = lhs,
                .rhs = rhs,
            } },
        });
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

    /// This function emits *two* instructions.
    fn addSoftFloatCmp(
        b: *Block,
        l: *Legalize,
        float_ty: Type,
        op: std.math.CompareOperator,
        lhs: Air.Inst.Ref,
        rhs: Air.Inst.Ref,
    ) Error!Air.Inst.Ref {
        const pt = l.pt;
        const target = pt.zcu.getTarget();
        const use_aeabi = target.cpu.arch.isArm() and switch (target.abi) {
            .eabi,
            .eabihf,
            .musleabi,
            .musleabihf,
            .gnueabi,
            .gnueabihf,
            .android,
            .androideabi,
            => true,
            else => false,
        };
        const func: Air.CompilerRtFunc, const ret_cmp_op: std.math.CompareOperator = switch (float_ty.floatBits(target)) {
            // zig fmt: off
            16 => switch (op) {
                .eq  => .{ .__eqhf2, .eq  },
                .neq => .{ .__nehf2, .neq },
                .lt  => .{ .__lthf2, .lt  },
                .lte => .{ .__lehf2, .lte },
                .gt  => .{ .__gthf2, .gt  },
                .gte => .{ .__gehf2, .gte },
            },
            32 => switch (op) {
                .eq  => if (use_aeabi) .{ .__aeabi_fcmpeq, .neq } else .{ .__eqsf2, .eq  },
                .neq => if (use_aeabi) .{ .__aeabi_fcmpeq, .eq  } else .{ .__nesf2, .neq },
                .lt  => if (use_aeabi) .{ .__aeabi_fcmplt, .neq } else .{ .__ltsf2, .lt  },
                .lte => if (use_aeabi) .{ .__aeabi_fcmple, .neq } else .{ .__lesf2, .lte },
                .gt  => if (use_aeabi) .{ .__aeabi_fcmpgt, .neq } else .{ .__gtsf2, .gt  },
                .gte => if (use_aeabi) .{ .__aeabi_fcmpge, .neq } else .{ .__gesf2, .gte },
            },
            64 => switch (op) {
                .eq  => if (use_aeabi) .{ .__aeabi_dcmpeq, .neq } else .{ .__eqdf2, .eq  },
                .neq => if (use_aeabi) .{ .__aeabi_dcmpeq, .eq  } else .{ .__nedf2, .neq },
                .lt  => if (use_aeabi) .{ .__aeabi_dcmplt, .neq } else .{ .__ltdf2, .lt  },
                .lte => if (use_aeabi) .{ .__aeabi_dcmple, .neq } else .{ .__ledf2, .lte },
                .gt  => if (use_aeabi) .{ .__aeabi_dcmpgt, .neq } else .{ .__gtdf2, .gt  },
                .gte => if (use_aeabi) .{ .__aeabi_dcmpge, .neq } else .{ .__gedf2, .gte },
            },
            80 => switch (op) {
                .eq  => .{ .__eqxf2, .eq  },
                .neq => .{ .__nexf2, .neq },
                .lt  => .{ .__ltxf2, .lt  },
                .lte => .{ .__lexf2, .lte },
                .gt  => .{ .__gtxf2, .gt  },
                .gte => .{ .__gexf2, .gte },
            },
            128 => switch (op) {
                .eq  => .{ .__eqtf2, .eq  },
                .neq => .{ .__netf2, .neq },
                .lt  => .{ .__lttf2, .lt  },
                .lte => .{ .__letf2, .lte },
                .gt  => .{ .__gttf2, .gt  },
                .gte => .{ .__getf2, .gte },
            },
            else => unreachable,
            // zig fmt: on
        };
        const call_inst = try b.addCompilerRtCall(l, func, &.{ lhs, rhs });
        const raw_result = call_inst.toRef();
        assert(l.typeOf(raw_result).toIntern() == .i32_type);
        const zero_i32: Air.Inst.Ref = .fromValue(try pt.intValue(.i32, 0));
        const ret_cmp_tag: Air.Inst.Tag = .fromCmpOp(ret_cmp_op, false);
        return b.addBinOp(l, ret_cmp_tag, raw_result, zero_i32).toRef();
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

fn compilerRtCall(
    l: *Legalize,
    orig_inst: Air.Inst.Index,
    func: Air.CompilerRtFunc,
    args: []const Air.Inst.Ref,
    result_ty: Type,
) Error!Air.Inst.Tag {
    const zcu = l.pt.zcu;
    const gpa = zcu.gpa;

    const func_ret_ty = func.returnType();

    if (func_ret_ty.toIntern() == result_ty.toIntern()) {
        try l.air_extra.ensureUnusedCapacity(gpa, @typeInfo(Air.Call).@"struct".fields.len + args.len);
        const payload = l.addExtra(Air.Call, .{ .args_len = @intCast(args.len) }) catch unreachable;
        l.air_extra.appendSliceAssumeCapacity(@ptrCast(args));
        return l.replaceInst(orig_inst, .legalize_compiler_rt_call, .{ .legalize_compiler_rt_call = .{
            .func = func,
            .payload = payload,
        } });
    }

    // We need to bitcast the result to an "alias" type (e.g. c_int/i32, c_longdouble/f128).

    assert(func_ret_ty.bitSize(zcu) == result_ty.bitSize(zcu));

    var inst_buf: [3]Air.Inst.Index = undefined;
    var main_block: Block = .init(&inst_buf);
    try l.air_instructions.ensureUnusedCapacity(gpa, inst_buf.len);

    const call_inst = try main_block.addCompilerRtCall(l, func, args);
    const casted_result = main_block.addBitCast(l, result_ty, call_inst.toRef());
    main_block.addBr(l, orig_inst, casted_result);

    return l.replaceInst(orig_inst, .block, .{ .ty_pl = .{
        .ty = .fromType(result_ty),
        .payload = try l.addBlockBody(main_block.body()),
    } });
}

fn softFptruncFunc(l: *const Legalize, src_ty: Type, dst_ty: Type) Air.CompilerRtFunc {
    const target = l.pt.zcu.getTarget();
    const src_bits = src_ty.floatBits(target);
    const dst_bits = dst_ty.floatBits(target);
    assert(dst_bits < src_bits);
    const to_f16_func: Air.CompilerRtFunc = switch (src_bits) {
        128 => .__trunctfhf2,
        80 => .__truncxfhf2,
        64 => .__truncdfhf2,
        32 => .__truncsfhf2,
        else => unreachable,
    };
    const offset: u8 = switch (dst_bits) {
        16 => 0,
        32 => 1,
        64 => 2,
        80 => 3,
        else => unreachable,
    };
    return @enumFromInt(@intFromEnum(to_f16_func) + offset);
}
fn softFpextFunc(l: *const Legalize, src_ty: Type, dst_ty: Type) Air.CompilerRtFunc {
    const target = l.pt.zcu.getTarget();
    const src_bits = src_ty.floatBits(target);
    const dst_bits = dst_ty.floatBits(target);
    assert(dst_bits > src_bits);
    const to_f128_func: Air.CompilerRtFunc = switch (src_bits) {
        16 => .__extendhftf2,
        32 => .__extendsftf2,
        64 => .__extenddftf2,
        80 => .__extendxftf2,
        else => unreachable,
    };
    const offset: u8 = switch (dst_bits) {
        128 => 0,
        80 => 1,
        64 => 2,
        32 => 3,
        else => unreachable,
    };
    return @enumFromInt(@intFromEnum(to_f128_func) + offset);
}
fn softFloatFromInt(l: *Legalize, orig_inst: Air.Inst.Index) Error!union(enum) {
    call: Air.CompilerRtFunc,
    block_payload: Air.Inst.Data,
} {
    const pt = l.pt;
    const zcu = pt.zcu;
    const target = zcu.getTarget();

    const ty_op = l.air_instructions.items(.data)[@intFromEnum(orig_inst)].ty_op;
    const dest_ty = ty_op.ty.toType();
    const src_ty = l.typeOf(ty_op.operand);

    const src_info = src_ty.intInfo(zcu);
    const float_off: u32 = switch (dest_ty.floatBits(target)) {
        16 => 0,
        32 => 1,
        64 => 2,
        80 => 3,
        128 => 4,
        else => unreachable,
    };
    const base: Air.CompilerRtFunc = switch (src_info.signedness) {
        .signed => .__floatsihf,
        .unsigned => .__floatunsihf,
    };
    fixed: {
        const extended_int_bits: u16, const int_bits_off: u32 = switch (src_info.bits) {
            0...32 => .{ 32, 0 },
            33...64 => .{ 64, 5 },
            65...128 => .{ 128, 10 },
            else => break :fixed,
        };
        // x86_64-windows uses an odd callconv for 128-bit integers, so we use the
        // arbitrary-precision routine in that case for simplicity.
        if (target.cpu.arch == .x86_64 and target.os.tag == .windows and extended_int_bits == 128) {
            break :fixed;
        }

        const func: Air.CompilerRtFunc = @enumFromInt(@intFromEnum(base) + int_bits_off + float_off);
        if (extended_int_bits == src_info.bits) return .{ .call = func };

        // We need to emit a block which first sign/zero-extends to the right type and *then* calls
        // the required routine.
        const extended_ty = try l.pt.intType(src_info.signedness, extended_int_bits);

        var inst_buf: [4]Air.Inst.Index = undefined;
        var main_block: Block = .init(&inst_buf);
        try l.air_instructions.ensureUnusedCapacity(zcu.gpa, inst_buf.len);

        const extended_val = main_block.addTyOp(l, .intcast, extended_ty, ty_op.operand).toRef();
        const call_inst = try main_block.addCompilerRtCall(l, func, &.{extended_val});
        const casted_result = main_block.addBitCast(l, dest_ty, call_inst.toRef());
        main_block.addBr(l, orig_inst, casted_result);

        return .{ .block_payload = .{ .ty_pl = .{
            .ty = .fromType(dest_ty),
            .payload = try l.addBlockBody(main_block.body()),
        } } };
    }

    // We need to emit a block which puts the integer into an `alloc` (possibly sign/zero-extended)
    // and calls an arbitrary-width conversion routine.

    const func: Air.CompilerRtFunc = @enumFromInt(@intFromEnum(base) + 15 + float_off);

    // The extended integer routines expect the integer representation where the integer is
    // effectively zero- or sign-extended to its ABI size. We represent that by intcasting to
    // such an integer type and passing a pointer to *that*.
    const extended_ty = try pt.intType(src_info.signedness, @intCast(src_ty.abiSize(zcu) * 8));
    assert(extended_ty.abiSize(zcu) == src_ty.abiSize(zcu));

    var inst_buf: [6]Air.Inst.Index = undefined;
    var main_block: Block = .init(&inst_buf);
    try l.air_instructions.ensureUnusedCapacity(zcu.gpa, inst_buf.len);

    const extended_val: Air.Inst.Ref = if (extended_ty.toIntern() != src_ty.toIntern()) ext: {
        break :ext main_block.addTyOp(l, .intcast, extended_ty, ty_op.operand).toRef();
    } else ext: {
        _ = main_block.stealCapacity(1);
        break :ext ty_op.operand;
    };
    const extended_ptr = main_block.addTy(l, .alloc, try pt.singleMutPtrType(extended_ty)).toRef();
    _ = main_block.addBinOp(l, .store, extended_ptr, extended_val);
    const bits_val = try pt.intValue(.usize, src_info.bits);
    const call_inst = try main_block.addCompilerRtCall(l, func, &.{ extended_ptr, .fromValue(bits_val) });
    const casted_result = main_block.addBitCast(l, dest_ty, call_inst.toRef());
    main_block.addBr(l, orig_inst, casted_result);

    return .{ .block_payload = .{ .ty_pl = .{
        .ty = .fromType(dest_ty),
        .payload = try l.addBlockBody(main_block.body()),
    } } };
}
fn softIntFromFloat(l: *Legalize, orig_inst: Air.Inst.Index) Error!union(enum) {
    call: Air.CompilerRtFunc,
    block_payload: Air.Inst.Data,
} {
    const pt = l.pt;
    const zcu = pt.zcu;
    const target = zcu.getTarget();

    const ty_op = l.air_instructions.items(.data)[@intFromEnum(orig_inst)].ty_op;
    const src_ty = l.typeOf(ty_op.operand);
    const dest_ty = ty_op.ty.toType();

    const dest_info = dest_ty.intInfo(zcu);
    const float_off: u32 = switch (src_ty.floatBits(target)) {
        16 => 0,
        32 => 1,
        64 => 2,
        80 => 3,
        128 => 4,
        else => unreachable,
    };
    const base: Air.CompilerRtFunc = switch (dest_info.signedness) {
        .signed => .__fixhfsi,
        .unsigned => .__fixunshfsi,
    };
    fixed: {
        const extended_int_bits: u16, const int_bits_off: u32 = switch (dest_info.bits) {
            0...32 => .{ 32, 0 },
            33...64 => .{ 64, 5 },
            65...128 => .{ 128, 10 },
            else => break :fixed,
        };
        // x86_64-windows uses an odd callconv for 128-bit integers, so we use the
        // arbitrary-precision routine in that case for simplicity.
        if (target.cpu.arch == .x86_64 and target.os.tag == .windows and extended_int_bits == 128) {
            break :fixed;
        }

        const func: Air.CompilerRtFunc = @enumFromInt(@intFromEnum(base) + int_bits_off + float_off);
        if (extended_int_bits == dest_info.bits) return .{ .call = func };

        // We need to emit a block which calls the routine and then casts to the required type.

        var inst_buf: [3]Air.Inst.Index = undefined;
        var main_block: Block = .init(&inst_buf);
        try l.air_instructions.ensureUnusedCapacity(zcu.gpa, inst_buf.len);

        const call_inst = try main_block.addCompilerRtCall(l, func, &.{ty_op.operand});
        const casted_val = main_block.addTyOp(l, .intcast, dest_ty, call_inst.toRef()).toRef();
        main_block.addBr(l, orig_inst, casted_val);

        return .{ .block_payload = .{ .ty_pl = .{
            .ty = .fromType(dest_ty),
            .payload = try l.addBlockBody(main_block.body()),
        } } };
    }

    // We need to emit a block which calls an arbitrary-width conversion routine, then loads the
    // integer from an `alloc` and possibly truncates it.
    const func: Air.CompilerRtFunc = @enumFromInt(@intFromEnum(base) + 15 + float_off);

    const extended_ty = try pt.intType(dest_info.signedness, @intCast(dest_ty.abiSize(zcu) * 8));
    assert(extended_ty.abiSize(zcu) == dest_ty.abiSize(zcu));

    var inst_buf: [5]Air.Inst.Index = undefined;
    var main_block: Block = .init(&inst_buf);
    try l.air_instructions.ensureUnusedCapacity(zcu.gpa, inst_buf.len);

    const extended_ptr = main_block.addTy(l, .alloc, try pt.singleMutPtrType(extended_ty)).toRef();
    const bits_val = try pt.intValue(.usize, dest_info.bits);
    _ = try main_block.addCompilerRtCall(l, func, &.{ extended_ptr, .fromValue(bits_val), ty_op.operand });
    const extended_val = main_block.addTyOp(l, .load, extended_ty, extended_ptr).toRef();
    const result_val = main_block.addTyOp(l, .intcast, dest_ty, extended_val).toRef();
    main_block.addBr(l, orig_inst, result_val);

    return .{ .block_payload = .{ .ty_pl = .{
        .ty = .fromType(dest_ty),
        .payload = try l.addBlockBody(main_block.body()),
    } } };
}
fn softFloatFunc(op: Air.Inst.Tag, float_ty: Type, zcu: *const Zcu) Air.CompilerRtFunc {
    const f16_func: Air.CompilerRtFunc = switch (op) {
        .add, .add_optimized => .__addhf3,
        .sub, .sub_optimized => .__subhf3,
        .mul, .mul_optimized => .__mulhf3,

        .div_float,
        .div_float_optimized,
        .div_exact,
        .div_exact_optimized,
        => .__divhf3,

        .min => .__fminh,
        .max => .__fmaxh,

        .ceil => .__ceilh,
        .floor => .__floorh,
        .trunc_float => .__trunch,
        .round => .__roundh,

        .log => .__logh,
        .log2 => .__log2h,
        .log10 => .__log10h,

        .exp => .__exph,
        .exp2 => .__exp2h,

        .sin => .__sinh,
        .cos => .__cosh,
        .tan => .__tanh,

        .abs => .__fabsh,
        .sqrt => .__sqrth,
        .rem, .rem_optimized => .__fmodh,
        .mul_add => .__fmah,

        else => unreachable,
    };
    const offset: u8 = switch (float_ty.floatBits(zcu.getTarget())) {
        16 => 0,
        32 => 1,
        64 => 2,
        80 => 3,
        128 => 4,
        else => unreachable,
    };
    return @enumFromInt(@intFromEnum(f16_func) + offset);
}

fn softFloatNegBlockPayload(
    l: *Legalize,
    orig_inst: Air.Inst.Index,
    operand: Air.Inst.Ref,
) Error!Air.Inst.Data {
    const pt = l.pt;
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    const float_ty = l.typeOfIndex(orig_inst);

    const int_ty: Type, const sign_bit: Value = switch (float_ty.floatBits(zcu.getTarget())) {
        16 => .{ .u16, try pt.intValue(.u16, @as(u16, 1) << 15) },
        32 => .{ .u32, try pt.intValue(.u32, @as(u32, 1) << 31) },
        64 => .{ .u64, try pt.intValue(.u64, @as(u64, 1) << 63) },
        80 => .{ .u80, try pt.intValue(.u80, @as(u80, 1) << 79) },
        128 => .{ .u128, try pt.intValue(.u128, @as(u128, 1) << 127) },
        else => unreachable,
    };

    const sign_bit_ref: Air.Inst.Ref = .fromValue(sign_bit);

    var inst_buf: [4]Air.Inst.Index = undefined;
    var main_block: Block = .init(&inst_buf);
    try l.air_instructions.ensureUnusedCapacity(gpa, inst_buf.len);

    const operand_as_int = main_block.addBitCast(l, int_ty, operand);
    const result_as_int = main_block.addBinOp(l, .xor, operand_as_int, sign_bit_ref).toRef();
    const result = main_block.addBitCast(l, float_ty, result_as_int);
    main_block.addBr(l, orig_inst, result);

    return .{ .ty_pl = .{
        .ty = .fromType(float_ty),
        .payload = try l.addBlockBody(main_block.body()),
    } };
}

fn softFloatDivTruncFloorBlockPayload(
    l: *Legalize,
    orig_inst: Air.Inst.Index,
    lhs: Air.Inst.Ref,
    rhs: Air.Inst.Ref,
    air_tag: Air.Inst.Tag,
) Error!Air.Inst.Data {
    const zcu = l.pt.zcu;
    const gpa = zcu.gpa;

    const float_ty = l.typeOfIndex(orig_inst);

    const floor_tag: Air.Inst.Tag = switch (air_tag) {
        .div_trunc, .div_trunc_optimized => .trunc_float,
        .div_floor, .div_floor_optimized => .floor,
        else => unreachable,
    };

    var inst_buf: [4]Air.Inst.Index = undefined;
    var main_block: Block = .init(&inst_buf);
    try l.air_instructions.ensureUnusedCapacity(gpa, inst_buf.len);

    const div_inst = try main_block.addCompilerRtCall(l, softFloatFunc(.div_float, float_ty, zcu), &.{ lhs, rhs });
    const floor_inst = try main_block.addCompilerRtCall(l, softFloatFunc(floor_tag, float_ty, zcu), &.{div_inst.toRef()});
    const casted_result = main_block.addBitCast(l, float_ty, floor_inst.toRef());
    main_block.addBr(l, orig_inst, casted_result);

    return .{ .ty_pl = .{
        .ty = .fromType(float_ty),
        .payload = try l.addBlockBody(main_block.body()),
    } };
}
fn softFloatModBlockPayload(
    l: *Legalize,
    orig_inst: Air.Inst.Index,
    lhs: Air.Inst.Ref,
    rhs: Air.Inst.Ref,
) Error!Air.Inst.Data {
    const pt = l.pt;
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    const float_ty = l.typeOfIndex(orig_inst);

    var inst_buf: [10]Air.Inst.Index = undefined;
    var main_block: Block = .init(&inst_buf);
    try l.air_instructions.ensureUnusedCapacity(gpa, inst_buf.len);

    const rem = try main_block.addCompilerRtCall(l, softFloatFunc(.rem, float_ty, zcu), &.{ lhs, rhs });
    const lhs_lt_zero = try main_block.addSoftFloatCmp(l, float_ty, .lt, lhs, .fromValue(try pt.floatValue(float_ty, 0.0)));

    var condbr: CondBr = .init(l, lhs_lt_zero, &main_block, .{});
    condbr.then_block = .init(main_block.stealRemainingCapacity());
    {
        const add = try condbr.then_block.addCompilerRtCall(l, softFloatFunc(.add, float_ty, zcu), &.{ rem.toRef(), rhs });
        const inner_rem = try condbr.then_block.addCompilerRtCall(l, softFloatFunc(.rem, float_ty, zcu), &.{ add.toRef(), rhs });
        const casted_result = condbr.then_block.addBitCast(l, float_ty, inner_rem.toRef());
        condbr.then_block.addBr(l, orig_inst, casted_result);
    }
    condbr.else_block = .init(condbr.then_block.stealRemainingCapacity());
    {
        const casted_result = condbr.else_block.addBitCast(l, float_ty, rem.toRef());
        condbr.else_block.addBr(l, orig_inst, casted_result);
    }

    try condbr.finish(l);

    return .{ .ty_pl = .{
        .ty = .fromType(float_ty),
        .payload = try l.addBlockBody(main_block.body()),
    } };
}
fn softFloatCmpBlockPayload(
    l: *Legalize,
    orig_inst: Air.Inst.Index,
    float_ty: Type,
    op: std.math.CompareOperator,
    lhs: Air.Inst.Ref,
    rhs: Air.Inst.Ref,
) Error!Air.Inst.Data {
    const pt = l.pt;
    const gpa = pt.zcu.gpa;

    var inst_buf: [3]Air.Inst.Index = undefined;
    var main_block: Block = .init(&inst_buf);
    try l.air_instructions.ensureUnusedCapacity(gpa, inst_buf.len);

    const result = try main_block.addSoftFloatCmp(l, float_ty, op, lhs, rhs);
    main_block.addBr(l, orig_inst, result);

    return .{ .ty_pl = .{
        .ty = .bool_type,
        .payload = try l.addBlockBody(main_block.body()),
    } };
}

/// `inline` to propagate potentially comptime-known return value.
inline fn wantScalarizeOrSoftFloat(
    l: *const Legalize,
    comptime air_tag: Air.Inst.Tag,
    ty: Type,
) enum {
    none,
    scalarize,
    soft_float,
} {
    const zcu = l.pt.zcu;
    const is_vec, const scalar_ty = switch (ty.zigTypeTag(zcu)) {
        .vector => .{ true, ty.childType(zcu) },
        else => .{ false, ty },
    };

    if (is_vec and l.features.has(.scalarize(air_tag))) return .scalarize;

    if (l.wantSoftFloatScalar(scalar_ty)) {
        return if (is_vec) .scalarize else .soft_float;
    }
    return .none;
}

/// `inline` to propagate potentially comptime-known return value.
inline fn wantSoftFloatScalar(l: *const Legalize, ty: Type) bool {
    const zcu = l.pt.zcu;
    return switch (ty.zigTypeTag(zcu)) {
        .vector => unreachable,
        .float => switch (ty.floatBits(zcu.getTarget())) {
            16 => l.features.has(.soft_f16),
            32 => l.features.has(.soft_f32),
            64 => l.features.has(.soft_f64),
            80 => l.features.has(.soft_f80),
            128 => l.features.has(.soft_f128),
            else => unreachable,
        },
        else => false,
    };
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
