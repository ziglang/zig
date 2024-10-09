pub const ComptimeLoadResult = union(enum) {
    success: MutableValue,

    runtime_load,
    undef,
    err_payload: InternPool.NullTerminatedString,
    null_payload,
    inactive_union_field,
    needed_well_defined: Type,
    out_of_bounds: Type,
    exceeds_host_size,
};

pub fn loadComptimePtr(sema: *Sema, block: *Block, src: LazySrcLoc, ptr: Value) !ComptimeLoadResult {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const ptr_info = ptr.typeOf(pt.zcu).ptrInfo(pt.zcu);
    // TODO: host size for vectors is terrible
    const host_bits = switch (ptr_info.flags.vector_index) {
        .none => ptr_info.packed_offset.host_size * 8,
        else => ptr_info.packed_offset.host_size * Type.fromInterned(ptr_info.child).bitSize(zcu),
    };
    const bit_offset = if (host_bits != 0) bit_offset: {
        const child_bits = Type.fromInterned(ptr_info.child).bitSize(zcu);
        const bit_offset = ptr_info.packed_offset.bit_offset + switch (ptr_info.flags.vector_index) {
            .none => 0,
            .runtime => return .runtime_load,
            else => |idx| switch (pt.zcu.getTarget().cpu.arch.endian()) {
                .little => child_bits * @intFromEnum(idx),
                .big => host_bits - child_bits * (@intFromEnum(idx) + 1), // element order reversed on big endian
            },
        };
        if (child_bits + bit_offset > host_bits) {
            return .exceeds_host_size;
        }
        break :bit_offset bit_offset;
    } else 0;
    return loadComptimePtrInner(sema, block, src, ptr, bit_offset, host_bits, Type.fromInterned(ptr_info.child), 0);
}

pub const ComptimeStoreResult = union(enum) {
    success,

    runtime_store,
    comptime_field_mismatch: Value,
    undef,
    err_payload: InternPool.NullTerminatedString,
    null_payload,
    inactive_union_field,
    needed_well_defined: Type,
    out_of_bounds: Type,
    exceeds_host_size,
};

/// Perform a comptime load of value `store_val` to a pointer.
/// The pointer's type is ignored.
pub fn storeComptimePtr(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    ptr: Value,
    store_val: Value,
) !ComptimeStoreResult {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const ptr_info = ptr.typeOf(zcu).ptrInfo(zcu);
    assert(store_val.typeOf(zcu).toIntern() == ptr_info.child);
    // TODO: host size for vectors is terrible
    const host_bits = switch (ptr_info.flags.vector_index) {
        .none => ptr_info.packed_offset.host_size * 8,
        else => ptr_info.packed_offset.host_size * Type.fromInterned(ptr_info.child).bitSize(zcu),
    };
    const bit_offset = ptr_info.packed_offset.bit_offset + switch (ptr_info.flags.vector_index) {
        .none => 0,
        .runtime => return .runtime_store,
        else => |idx| switch (zcu.getTarget().cpu.arch.endian()) {
            .little => Type.fromInterned(ptr_info.child).bitSize(zcu) * @intFromEnum(idx),
            .big => host_bits - Type.fromInterned(ptr_info.child).bitSize(zcu) * (@intFromEnum(idx) + 1), // element order reversed on big endian
        },
    };
    const pseudo_store_ty = if (host_bits > 0) t: {
        const need_bits = Type.fromInterned(ptr_info.child).bitSize(zcu);
        if (need_bits + bit_offset > host_bits) {
            return .exceeds_host_size;
        }
        break :t try sema.pt.intType(.unsigned, @intCast(host_bits));
    } else Type.fromInterned(ptr_info.child);

    const strat = try prepareComptimePtrStore(sema, block, src, ptr, pseudo_store_ty, 0);

    // Propagate errors and handle comptime fields.
    switch (strat) {
        .direct, .index, .flat_index, .reinterpret => {},
        .comptime_field => {
            // To "store" to a comptime field, just perform a load of the field
            // and see if the store value matches.
            const expected_mv = switch (try loadComptimePtr(sema, block, src, ptr)) {
                .success => |mv| mv,
                .runtime_load => unreachable, // this is a comptime field
                .exceeds_host_size => unreachable, // checked above
                .undef => return .undef,
                .err_payload => |err| return .{ .err_payload = err },
                .null_payload => return .null_payload,
                .inactive_union_field => return .inactive_union_field,
                .needed_well_defined => |ty| return .{ .needed_well_defined = ty },
                .out_of_bounds => |ty| return .{ .out_of_bounds = ty },
            };
            const expected = try expected_mv.intern(pt, sema.arena);
            if (store_val.toIntern() != expected.toIntern()) {
                return .{ .comptime_field_mismatch = expected };
            }
            return .success;
        },
        .runtime_store => return .runtime_store,
        .undef => return .undef,
        .err_payload => |err| return .{ .err_payload = err },
        .null_payload => return .null_payload,
        .inactive_union_field => return .inactive_union_field,
        .needed_well_defined => |ty| return .{ .needed_well_defined = ty },
        .out_of_bounds => |ty| return .{ .out_of_bounds = ty },
    }

    // Check the store is not inside a runtime condition
    try checkComptimeVarStore(sema, block, src, strat.alloc());

    if (host_bits == 0) {
        // We can attempt a direct store depending on the strategy.
        switch (strat) {
            .direct => |direct| {
                const want_ty = direct.val.typeOf(zcu);
                const coerced_store_val = try pt.getCoerced(store_val, want_ty);
                direct.val.* = .{ .interned = coerced_store_val.toIntern() };
                return .success;
            },
            .index => |index| {
                const want_ty = index.val.typeOf(zcu).childType(zcu);
                const coerced_store_val = try pt.getCoerced(store_val, want_ty);
                try index.val.setElem(pt, sema.arena, @intCast(index.elem_index), .{ .interned = coerced_store_val.toIntern() });
                return .success;
            },
            .flat_index => |flat| {
                const store_elems = store_val.typeOf(zcu).arrayBase(zcu)[1];
                const flat_elems = try sema.arena.alloc(InternPool.Index, @intCast(store_elems));
                {
                    var next_idx: u64 = 0;
                    var skip: u64 = 0;
                    try flattenArray(sema, .{ .interned = store_val.toIntern() }, &skip, &next_idx, flat_elems);
                }
                for (flat_elems, 0..) |elem, idx| {
                    // TODO: recursiveIndex in a loop does a lot of redundant work!
                    // Better would be to gather all the store targets into an array.
                    var index: u64 = flat.flat_elem_index + idx;
                    const val_ptr, const final_idx = (try recursiveIndex(sema, flat.val, &index)).?;
                    try val_ptr.setElem(pt, sema.arena, @intCast(final_idx), .{ .interned = elem });
                }
                return .success;
            },
            .reinterpret => {},
            else => unreachable,
        }
    }

    // Either there is a bit offset, or the strategy required reinterpreting.
    // Therefore, we must perform a bitcast.

    const val_ptr: *MutableValue, const byte_offset: u64 = switch (strat) {
        .direct => |direct| .{ direct.val, 0 },
        .index => |index| .{
            index.val,
            index.elem_index * index.val.typeOf(zcu).childType(zcu).abiSize(zcu),
        },
        .flat_index => |flat| .{ flat.val, flat.flat_elem_index * flat.val.typeOf(zcu).arrayBase(zcu)[0].abiSize(zcu) },
        .reinterpret => |reinterpret| .{ reinterpret.val, reinterpret.byte_offset },
        else => unreachable,
    };

    if (!val_ptr.typeOf(zcu).hasWellDefinedLayout(zcu)) {
        return .{ .needed_well_defined = val_ptr.typeOf(zcu) };
    }

    if (!store_val.typeOf(zcu).hasWellDefinedLayout(zcu)) {
        return .{ .needed_well_defined = store_val.typeOf(zcu) };
    }

    const new_val = try sema.bitCastSpliceVal(
        try val_ptr.intern(pt, sema.arena),
        store_val,
        byte_offset,
        host_bits,
        bit_offset,
    ) orelse return .runtime_store;
    val_ptr.* = .{ .interned = new_val.toIntern() };
    return .success;
}

/// Perform a comptime load of type `load_ty` from a pointer.
/// The pointer's type is ignored.
fn loadComptimePtrInner(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    ptr_val: Value,
    bit_offset: u64,
    host_bits: u64,
    load_ty: Type,
    /// If `load_ty` is an array, this is the number of array elements to skip
    /// before `load_ty`. Otherwise, it is ignored and may be `undefined`.
    array_offset: u64,
) !ComptimeLoadResult {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;

    const ptr = switch (ip.indexToKey(ptr_val.toIntern())) {
        .undef => return .undef,
        .ptr => |ptr| ptr,
        else => unreachable,
    };

    const base_val: MutableValue = switch (ptr.base_addr) {
        .nav => |nav| val: {
            try sema.declareDependency(.{ .nav_val = nav });
            try sema.ensureNavResolved(src, nav);
            const val = ip.getNav(nav).status.resolved.val;
            switch (ip.indexToKey(val)) {
                .variable => return .runtime_load,
                // We let `.@"extern"` through here if it's a function.
                // This allows you to alias `extern fn`s.
                .@"extern" => |e| if (Type.fromInterned(e.ty).zigTypeTag(zcu) == .@"fn")
                    break :val .{ .interned = val }
                else
                    return .runtime_load,
                else => break :val .{ .interned = val },
            }
        },
        .comptime_alloc => |alloc_index| sema.getComptimeAlloc(alloc_index).val,
        .uav => |uav| .{ .interned = uav.val },
        .comptime_field => |val| .{ .interned = val },
        .int => return .runtime_load,
        .eu_payload => |base_ptr_ip| val: {
            const base_ptr = Value.fromInterned(base_ptr_ip);
            const base_ty = base_ptr.typeOf(zcu).childType(zcu);
            switch (try loadComptimePtrInner(sema, block, src, base_ptr, 0, 0, base_ty, undefined)) {
                .success => |eu_val| switch (eu_val.unpackErrorUnion(zcu)) {
                    .undef => return .undef,
                    .err => |err| return .{ .err_payload = err },
                    .payload => |payload| break :val payload,
                },
                else => |err| return err,
            }
        },
        .opt_payload => |base_ptr_ip| val: {
            const base_ptr = Value.fromInterned(base_ptr_ip);
            const base_ty = base_ptr.typeOf(zcu).childType(zcu);
            switch (try loadComptimePtrInner(sema, block, src, base_ptr, 0, 0, base_ty, undefined)) {
                .success => |eu_val| switch (eu_val.unpackOptional(zcu)) {
                    .undef => return .undef,
                    .null => return .null_payload,
                    .payload => |payload| break :val payload,
                },
                else => |err| return err,
            }
        },
        .arr_elem => |base_index| val: {
            const base_ptr = Value.fromInterned(base_index.base);
            const base_ty = base_ptr.typeOf(zcu).childType(zcu);

            // We have a comptime-only array. This case is a little nasty.
            // To avoid loading too much data, we want to figure out how many elements we need.
            // If `load_ty` and the array share a base type, we'll load the correct number of elements.
            // Otherwise, we'll be reinterpreting (which we can't do, since it's comptime-only); just
            // load a single element and let the logic below emit its error.

            const load_one_ty, const load_count = load_ty.arrayBase(zcu);
            const count = if (load_one_ty.toIntern() == base_ty.toIntern()) load_count else 1;

            const want_ty = try sema.pt.arrayType(.{
                .len = count,
                .child = base_ty.toIntern(),
            });

            switch (try loadComptimePtrInner(sema, block, src, base_ptr, 0, 0, want_ty, base_index.index)) {
                .success => |arr_val| break :val arr_val,
                else => |err| return err,
            }
        },
        .field => |base_index| val: {
            const base_ptr = Value.fromInterned(base_index.base);
            const base_ty = base_ptr.typeOf(zcu).childType(zcu);

            // Field of a slice, or of an auto-layout struct or union.
            const agg_val = switch (try loadComptimePtrInner(sema, block, src, base_ptr, 0, 0, base_ty, undefined)) {
                .success => |val| val,
                else => |err| return err,
            };

            const agg_ty = agg_val.typeOf(zcu);
            switch (agg_ty.zigTypeTag(zcu)) {
                .@"struct", .pointer => break :val try agg_val.getElem(sema.pt, @intCast(base_index.index)),
                .@"union" => {
                    const tag_val: Value, const payload_mv: MutableValue = switch (agg_val) {
                        .un => |un| .{ Value.fromInterned(un.tag), un.payload.* },
                        .interned => |ip_index| switch (ip.indexToKey(ip_index)) {
                            .undef => return .undef,
                            .un => |un| .{ Value.fromInterned(un.tag), .{ .interned = un.val } },
                            else => unreachable,
                        },
                        else => unreachable,
                    };
                    const tag_ty = agg_ty.unionTagTypeHypothetical(zcu);
                    if (tag_ty.enumTagFieldIndex(tag_val, zcu).? != base_index.index) {
                        return .inactive_union_field;
                    }
                    break :val payload_mv;
                },
                else => unreachable,
            }

            break :val try agg_val.getElem(zcu, base_index.index);
        },
    };

    if (ptr.byte_offset == 0 and host_bits == 0) {
        if (load_ty.zigTypeTag(zcu) != .array or array_offset == 0) {
            if (.ok == try sema.coerceInMemoryAllowed(
                block,
                load_ty,
                base_val.typeOf(zcu),
                false,
                zcu.getTarget(),
                src,
                src,
                null,
            )) {
                // We already have a value which is IMC to the desired type.
                return .{ .success = base_val };
            }
        }
    }

    restructure_array: {
        if (host_bits != 0) break :restructure_array;

        // We might also be changing the length of an array, or restructuring it.
        // e.g. [1][2][3]T -> [3][2]T.
        // This case is important because it's permitted for types with ill-defined layouts.

        const load_one_ty, const load_count = load_ty.arrayBase(zcu);

        const extra_base_index: u64 = if (ptr.byte_offset == 0) 0 else idx: {
            if (try load_one_ty.comptimeOnlySema(pt)) break :restructure_array;
            const elem_len = try load_one_ty.abiSizeSema(pt);
            if (ptr.byte_offset % elem_len != 0) break :restructure_array;
            break :idx @divExact(ptr.byte_offset, elem_len);
        };

        const val_one_ty, const val_count = base_val.typeOf(zcu).arrayBase(zcu);
        if (.ok == try sema.coerceInMemoryAllowed(
            block,
            load_one_ty,
            val_one_ty,
            false,
            zcu.getTarget(),
            src,
            src,
            null,
        )) {
            // Changing the length of an array.
            const skip_base: u64 = extra_base_index + if (load_ty.zigTypeTag(zcu) == .array) skip: {
                break :skip load_ty.childType(zcu).arrayBase(zcu)[1] * array_offset;
            } else 0;
            if (skip_base + load_count > val_count) return .{ .out_of_bounds = base_val.typeOf(zcu) };
            const elems = try sema.arena.alloc(InternPool.Index, @intCast(load_count));
            var skip: u64 = skip_base;
            var next_idx: u64 = 0;
            try flattenArray(sema, base_val, &skip, &next_idx, elems);
            next_idx = 0;
            const val = try unflattenArray(sema, load_ty, elems, &next_idx);
            return .{ .success = .{ .interned = val.toIntern() } };
        }
    }

    // We need to reinterpret memory, which is only possible if neither the load
    // type nor the type of the base value are comptime-only.

    if (!load_ty.hasWellDefinedLayout(zcu)) {
        return .{ .needed_well_defined = load_ty };
    }

    if (!base_val.typeOf(zcu).hasWellDefinedLayout(zcu)) {
        return .{ .needed_well_defined = base_val.typeOf(zcu) };
    }

    var cur_val = base_val;
    var cur_offset = ptr.byte_offset;

    if (load_ty.zigTypeTag(zcu) == .array and array_offset > 0) {
        cur_offset += try load_ty.childType(zcu).abiSizeSema(pt) * array_offset;
    }

    const need_bytes = if (host_bits > 0) (host_bits + 7) / 8 else try load_ty.abiSizeSema(pt);

    if (cur_offset + need_bytes > try cur_val.typeOf(zcu).abiSizeSema(pt)) {
        return .{ .out_of_bounds = cur_val.typeOf(zcu) };
    }

    // In the worst case, we can reinterpret the entire value - however, that's
    // pretty wasteful. If the memory region we're interested in refers to one
    // field or array element, let's just look at that.
    while (true) {
        const cur_ty = cur_val.typeOf(zcu);
        switch (cur_ty.zigTypeTag(zcu)) {
            .noreturn,
            .type,
            .comptime_int,
            .comptime_float,
            .null,
            .undefined,
            .enum_literal,
            .@"opaque",
            .@"fn",
            .error_union,
            => unreachable, // ill-defined layout
            .int,
            .float,
            .bool,
            .void,
            .pointer,
            .error_set,
            .@"anyframe",
            .frame,
            .@"enum",
            .vector,
            => break, // terminal types (no sub-values)
            .optional => break, // this can only be a pointer-like optional so is terminal
            .array => {
                const elem_ty = cur_ty.childType(zcu);
                const elem_size = try elem_ty.abiSizeSema(pt);
                const elem_idx = cur_offset / elem_size;
                const next_elem_off = elem_size * (elem_idx + 1);
                if (cur_offset + need_bytes <= next_elem_off) {
                    // We can look at a single array element.
                    cur_val = try cur_val.getElem(sema.pt, @intCast(elem_idx));
                    cur_offset -= elem_idx * elem_size;
                } else {
                    break;
                }
            },
            .@"struct" => switch (cur_ty.containerLayout(zcu)) {
                .auto => unreachable, // ill-defined layout
                .@"packed" => break, // let the bitcast logic handle this
                .@"extern" => for (0..cur_ty.structFieldCount(zcu)) |field_idx| {
                    const start_off = cur_ty.structFieldOffset(field_idx, zcu);
                    const end_off = start_off + try cur_ty.fieldType(field_idx, zcu).abiSizeSema(pt);
                    if (cur_offset >= start_off and cur_offset + need_bytes <= end_off) {
                        cur_val = try cur_val.getElem(sema.pt, field_idx);
                        cur_offset -= start_off;
                        break;
                    }
                } else break, // pointer spans multiple fields
            },
            .@"union" => switch (cur_ty.containerLayout(zcu)) {
                .auto => unreachable, // ill-defined layout
                .@"packed" => break, // let the bitcast logic handle this
                .@"extern" => {
                    // TODO: we have to let bitcast logic handle this for now.
                    // Otherwise, we might traverse into a union field which doesn't allow pointers.
                    // Figure out a solution!
                    if (true) break;
                    const payload: MutableValue = switch (cur_val) {
                        .un => |un| un.payload.*,
                        .interned => |ip_index| switch (ip.indexToKey(ip_index)) {
                            .un => |un| .{ .interned = un.val },
                            .undef => return .undef,
                            else => unreachable,
                        },
                        else => unreachable,
                    };
                    // The payload always has offset 0. If it's big enough
                    // to represent the whole load type, we can use it.
                    if (try payload.typeOf(zcu).abiSizeSema(pt) >= need_bytes) {
                        cur_val = payload;
                    } else {
                        break;
                    }
                },
            },
        }
    }

    // Fast path: check again if we're now at the type we want to load.
    // If so, just return the loaded value.
    if (cur_offset == 0 and host_bits == 0 and cur_val.typeOf(zcu).toIntern() == load_ty.toIntern()) {
        return .{ .success = cur_val };
    }

    const result_val = try sema.bitCastVal(
        try cur_val.intern(sema.pt, sema.arena),
        load_ty,
        cur_offset,
        host_bits,
        bit_offset,
    ) orelse return .runtime_load;
    return .{ .success = .{ .interned = result_val.toIntern() } };
}

const ComptimeStoreStrategy = union(enum) {
    /// The store should be performed directly to this value, which `store_ty`
    /// is in-memory coercible to.
    direct: struct {
        alloc: ComptimeAllocIndex,
        val: *MutableValue,
    },
    /// The store should be performed at the index `elem_index` into `val`,
    /// which is an array.
    /// This strategy exists to avoid the need to convert the parent value
    /// to the `aggregate` representation when `repeated` or `bytes` may
    /// suffice.
    index: struct {
        alloc: ComptimeAllocIndex,
        val: *MutableValue,
        elem_index: u64,
    },
    /// The store should be performed on this array value, but it is being
    /// restructured, e.g. [3][2][1]T -> [2][3]T.
    /// This includes the case where it is a sub-array, e.g. [3]T -> [2]T.
    /// This is only returned if `store_ty` is an array type, and its array
    /// base type is IMC to that of the type of `val`.
    flat_index: struct {
        alloc: ComptimeAllocIndex,
        val: *MutableValue,
        flat_elem_index: u64,
    },
    /// This value should be reinterpreted using bitcast logic to perform the
    /// store. Only returned if `store_ty` and the type of `val` both have
    /// well-defined layouts.
    reinterpret: struct {
        alloc: ComptimeAllocIndex,
        val: *MutableValue,
        byte_offset: u64,
    },

    comptime_field,
    runtime_store,
    undef,
    err_payload: InternPool.NullTerminatedString,
    null_payload,
    inactive_union_field,
    needed_well_defined: Type,
    out_of_bounds: Type,

    fn alloc(strat: ComptimeStoreStrategy) ComptimeAllocIndex {
        return switch (strat) {
            inline .direct, .index, .flat_index, .reinterpret => |info| info.alloc,
            .comptime_field,
            .runtime_store,
            .undef,
            .err_payload,
            .null_payload,
            .inactive_union_field,
            .needed_well_defined,
            .out_of_bounds,
            => unreachable,
        };
    }
};

/// Decide the strategy we will use to perform a comptime store of type `store_ty` to a pointer.
/// The pointer's type is ignored.
fn prepareComptimePtrStore(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    ptr_val: Value,
    store_ty: Type,
    /// If `store_ty` is an array, this is the number of array elements to skip
    /// before `store_ty`. Otherwise, it is ignored and may be `undefined`.
    array_offset: u64,
) !ComptimeStoreStrategy {
    const pt = sema.pt;
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;

    const ptr = switch (ip.indexToKey(ptr_val.toIntern())) {
        .undef => return .undef,
        .ptr => |ptr| ptr,
        else => unreachable,
    };

    // `base_strat` will not be an error case.
    const base_strat: ComptimeStoreStrategy = switch (ptr.base_addr) {
        .nav, .uav, .int => return .runtime_store,
        .comptime_field => return .comptime_field,
        .comptime_alloc => |alloc_index| .{ .direct = .{
            .alloc = alloc_index,
            .val = &sema.getComptimeAlloc(alloc_index).val,
        } },
        .eu_payload => |base_ptr_ip| base_val: {
            const base_ptr = Value.fromInterned(base_ptr_ip);
            const base_ty = base_ptr.typeOf(zcu).childType(zcu);
            const eu_val_ptr, const alloc = switch (try prepareComptimePtrStore(sema, block, src, base_ptr, base_ty, undefined)) {
                .direct => |direct| .{ direct.val, direct.alloc },
                .index => |index| .{
                    try index.val.elem(pt, sema.arena, @intCast(index.elem_index)),
                    index.alloc,
                },
                .flat_index => unreachable, // base_ty is not an array
                .reinterpret => unreachable, // base_ty has ill-defined layout
                else => |err| return err,
            };
            try eu_val_ptr.unintern(pt, sema.arena, false, false);
            switch (eu_val_ptr.*) {
                .interned => |ip_index| switch (ip.indexToKey(ip_index)) {
                    .undef => return .undef,
                    .error_union => |eu| return .{ .err_payload = eu.val.err_name },
                    else => unreachable,
                },
                .eu_payload => |data| break :base_val .{ .direct = .{
                    .val = data.child,
                    .alloc = alloc,
                } },
                else => unreachable,
            }
        },
        .opt_payload => |base_ptr_ip| base_val: {
            const base_ptr = Value.fromInterned(base_ptr_ip);
            const base_ty = base_ptr.typeOf(zcu).childType(zcu);
            const opt_val_ptr, const alloc = switch (try prepareComptimePtrStore(sema, block, src, base_ptr, base_ty, undefined)) {
                .direct => |direct| .{ direct.val, direct.alloc },
                .index => |index| .{
                    try index.val.elem(pt, sema.arena, @intCast(index.elem_index)),
                    index.alloc,
                },
                .flat_index => unreachable, // base_ty is not an array
                .reinterpret => unreachable, // base_ty has ill-defined layout
                else => |err| return err,
            };
            try opt_val_ptr.unintern(pt, sema.arena, false, false);
            switch (opt_val_ptr.*) {
                .interned => |ip_index| switch (ip.indexToKey(ip_index)) {
                    .undef => return .undef,
                    .opt => return .null_payload,
                    else => unreachable,
                },
                .opt_payload => |data| break :base_val .{ .direct = .{
                    .val = data.child,
                    .alloc = alloc,
                } },
                else => unreachable,
            }
        },
        .arr_elem => |base_index| base_val: {
            const base_ptr = Value.fromInterned(base_index.base);
            const base_ty = base_ptr.typeOf(zcu).childType(zcu);

            // We have a comptime-only array. This case is a little nasty.
            // To avoid messing with too much data, we want to figure out how many elements we need to store.
            // If `store_ty` and the array share a base type, we'll store the correct number of elements.
            // Otherwise, we'll be reinterpreting (which we can't do, since it's comptime-only); just
            // load a single element and let the logic below emit its error.

            const store_one_ty, const store_count = store_ty.arrayBase(zcu);
            const count = if (store_one_ty.toIntern() == base_ty.toIntern()) store_count else 1;

            const want_ty = try pt.arrayType(.{
                .len = count,
                .child = base_ty.toIntern(),
            });

            const result = try prepareComptimePtrStore(sema, block, src, base_ptr, want_ty, base_index.index);
            switch (result) {
                .direct, .index, .flat_index => break :base_val result,
                .reinterpret => unreachable, // comptime-only array so ill-defined layout
                else => |err| return err,
            }
        },
        .field => |base_index| strat: {
            const base_ptr = Value.fromInterned(base_index.base);
            const base_ty = base_ptr.typeOf(zcu).childType(zcu);

            // Field of a slice, or of an auto-layout struct or union.
            const agg_val, const alloc = switch (try prepareComptimePtrStore(sema, block, src, base_ptr, base_ty, undefined)) {
                .direct => |direct| .{ direct.val, direct.alloc },
                .index => |index| .{
                    try index.val.elem(pt, sema.arena, @intCast(index.elem_index)),
                    index.alloc,
                },
                .flat_index => unreachable, // base_ty is not an array
                .reinterpret => unreachable, // base_ty has ill-defined layout
                else => |err| return err,
            };

            const agg_ty = agg_val.typeOf(zcu);
            switch (agg_ty.zigTypeTag(zcu)) {
                .@"struct", .pointer => break :strat .{ .direct = .{
                    .val = try agg_val.elem(pt, sema.arena, @intCast(base_index.index)),
                    .alloc = alloc,
                } },
                .@"union" => {
                    if (agg_val.* == .interned and Value.fromInterned(agg_val.interned).isUndef(zcu)) {
                        return .undef;
                    }
                    try agg_val.unintern(pt, sema.arena, false, false);
                    const un = agg_val.un;
                    const tag_ty = agg_ty.unionTagTypeHypothetical(zcu);
                    if (tag_ty.enumTagFieldIndex(Value.fromInterned(un.tag), zcu).? != base_index.index) {
                        return .inactive_union_field;
                    }
                    break :strat .{ .direct = .{
                        .val = un.payload,
                        .alloc = alloc,
                    } };
                },
                else => unreachable,
            }
        },
    };

    if (ptr.byte_offset == 0) {
        if (store_ty.zigTypeTag(zcu) != .array or array_offset == 0) direct: {
            const base_val_ty = switch (base_strat) {
                .direct => |direct| direct.val.typeOf(zcu),
                .index => |index| index.val.typeOf(zcu).childType(zcu),
                .flat_index, .reinterpret => break :direct,
                else => unreachable,
            };
            if (.ok == try sema.coerceInMemoryAllowed(
                block,
                base_val_ty,
                store_ty,
                true,
                zcu.getTarget(),
                src,
                src,
                null,
            )) {
                // The base strategy already gets us a value which the desired type is IMC to.
                return base_strat;
            }
        }
    }

    restructure_array: {
        // We might also be changing the length of an array, or restructuring it.
        // e.g. [1][2][3]T -> [3][2]T.
        // This case is important because it's permitted for types with ill-defined layouts.

        const store_one_ty, const store_count = store_ty.arrayBase(zcu);
        const extra_base_index: u64 = if (ptr.byte_offset == 0) 0 else idx: {
            if (try store_one_ty.comptimeOnlySema(pt)) break :restructure_array;
            const elem_len = try store_one_ty.abiSizeSema(pt);
            if (ptr.byte_offset % elem_len != 0) break :restructure_array;
            break :idx @divExact(ptr.byte_offset, elem_len);
        };

        const base_val, const base_elem_offset, const oob_ty = switch (base_strat) {
            .direct => |direct| .{ direct.val, 0, direct.val.typeOf(zcu) },
            .index => |index| restructure_info: {
                const elem_ty = index.val.typeOf(zcu).childType(zcu);
                const elem_off = elem_ty.arrayBase(zcu)[1] * index.elem_index;
                break :restructure_info .{ index.val, elem_off, elem_ty };
            },
            .flat_index => |flat| .{ flat.val, flat.flat_elem_index, flat.val.typeOf(zcu) },
            .reinterpret => break :restructure_array,
            else => unreachable,
        };
        const val_one_ty, const val_count = base_val.typeOf(zcu).arrayBase(zcu);
        if (.ok != try sema.coerceInMemoryAllowed(block, val_one_ty, store_one_ty, true, zcu.getTarget(), src, src, null)) {
            break :restructure_array;
        }
        if (base_elem_offset + extra_base_index + store_count > val_count) return .{ .out_of_bounds = oob_ty };

        if (store_ty.zigTypeTag(zcu) == .array) {
            const skip = store_ty.childType(zcu).arrayBase(zcu)[1] * array_offset;
            return .{ .flat_index = .{
                .alloc = base_strat.alloc(),
                .val = base_val,
                .flat_elem_index = skip + base_elem_offset + extra_base_index,
            } };
        }

        // `base_val` must be an array, since otherwise the "direct reinterpret" logic above noticed it.
        assert(base_val.typeOf(zcu).zigTypeTag(zcu) == .array);

        var index: u64 = base_elem_offset + extra_base_index;
        const arr_val, const arr_index = (try recursiveIndex(sema, base_val, &index)).?;
        return .{ .index = .{
            .alloc = base_strat.alloc(),
            .val = arr_val,
            .elem_index = arr_index,
        } };
    }

    // We need to reinterpret memory, which is only possible if neither the store
    // type nor the type of the base value have an ill-defined layout.

    if (!store_ty.hasWellDefinedLayout(zcu)) {
        return .{ .needed_well_defined = store_ty };
    }

    var cur_val: *MutableValue, var cur_offset: u64 = switch (base_strat) {
        .direct => |direct| .{ direct.val, 0 },
        // It's okay to do `abiSize` - the comptime-only case will be caught below.
        .index => |index| .{ index.val, index.elem_index * try index.val.typeOf(zcu).childType(zcu).abiSizeSema(pt) },
        .flat_index => |flat_index| .{
            flat_index.val,
            // It's okay to do `abiSize` - the comptime-only case will be caught below.
            flat_index.flat_elem_index * try flat_index.val.typeOf(zcu).arrayBase(zcu)[0].abiSizeSema(pt),
        },
        .reinterpret => |r| .{ r.val, r.byte_offset },
        else => unreachable,
    };
    cur_offset += ptr.byte_offset;

    if (!cur_val.typeOf(zcu).hasWellDefinedLayout(zcu)) {
        return .{ .needed_well_defined = cur_val.typeOf(zcu) };
    }

    if (store_ty.zigTypeTag(zcu) == .array and array_offset > 0) {
        cur_offset += try store_ty.childType(zcu).abiSizeSema(pt) * array_offset;
    }

    const need_bytes = try store_ty.abiSizeSema(pt);

    if (cur_offset + need_bytes > try cur_val.typeOf(zcu).abiSizeSema(pt)) {
        return .{ .out_of_bounds = cur_val.typeOf(zcu) };
    }

    // In the worst case, we can reinterpret the entire value - however, that's
    // pretty wasteful. If the memory region we're interested in refers to one
    // field or array element, let's just look at that.
    while (true) {
        const cur_ty = cur_val.typeOf(zcu);
        switch (cur_ty.zigTypeTag(zcu)) {
            .noreturn,
            .type,
            .comptime_int,
            .comptime_float,
            .null,
            .undefined,
            .enum_literal,
            .@"opaque",
            .@"fn",
            .error_union,
            => unreachable, // ill-defined layout
            .int,
            .float,
            .bool,
            .void,
            .pointer,
            .error_set,
            .@"anyframe",
            .frame,
            .@"enum",
            .vector,
            => break, // terminal types (no sub-values)
            .optional => break, // this can only be a pointer-like optional so is terminal
            .array => {
                const elem_ty = cur_ty.childType(zcu);
                const elem_size = try elem_ty.abiSizeSema(pt);
                const elem_idx = cur_offset / elem_size;
                const next_elem_off = elem_size * (elem_idx + 1);
                if (cur_offset + need_bytes <= next_elem_off) {
                    // We can look at a single array element.
                    cur_val = try cur_val.elem(pt, sema.arena, @intCast(elem_idx));
                    cur_offset -= elem_idx * elem_size;
                } else {
                    break;
                }
            },
            .@"struct" => switch (cur_ty.containerLayout(zcu)) {
                .auto => unreachable, // ill-defined layout
                .@"packed" => break, // let the bitcast logic handle this
                .@"extern" => for (0..cur_ty.structFieldCount(zcu)) |field_idx| {
                    const start_off = cur_ty.structFieldOffset(field_idx, zcu);
                    const end_off = start_off + try cur_ty.fieldType(field_idx, zcu).abiSizeSema(pt);
                    if (cur_offset >= start_off and cur_offset + need_bytes <= end_off) {
                        cur_val = try cur_val.elem(pt, sema.arena, field_idx);
                        cur_offset -= start_off;
                        break;
                    }
                } else break, // pointer spans multiple fields
            },
            .@"union" => switch (cur_ty.containerLayout(zcu)) {
                .auto => unreachable, // ill-defined layout
                .@"packed" => break, // let the bitcast logic handle this
                .@"extern" => {
                    // TODO: we have to let bitcast logic handle this for now.
                    // Otherwise, we might traverse into a union field which doesn't allow pointers.
                    // Figure out a solution!
                    if (true) break;
                    try cur_val.unintern(pt, sema.arena, false, false);
                    const payload = switch (cur_val.*) {
                        .un => |un| un.payload,
                        else => unreachable,
                    };
                    // The payload always has offset 0. If it's big enough
                    // to represent the whole load type, we can use it.
                    if (try payload.typeOf(zcu).abiSizeSema(pt) >= need_bytes) {
                        cur_val = payload;
                    } else {
                        break;
                    }
                },
            },
        }
    }

    // Fast path: check again if we're now at the type we want to store.
    // If so, we can use the `direct` strategy.
    if (cur_offset == 0 and cur_val.typeOf(zcu).toIntern() == store_ty.toIntern()) {
        return .{ .direct = .{
            .alloc = base_strat.alloc(),
            .val = cur_val,
        } };
    }

    return .{ .reinterpret = .{
        .alloc = base_strat.alloc(),
        .val = cur_val,
        .byte_offset = cur_offset,
    } };
}

/// Given a potentially-nested array value, recursively flatten all of its elements into the given
/// output array. The result can be used by `unflattenArray` to restructure array values.
fn flattenArray(
    sema: *Sema,
    val: MutableValue,
    skip: *u64,
    next_idx: *u64,
    out: []InternPool.Index,
) Allocator.Error!void {
    if (next_idx.* == out.len) return;

    const zcu = sema.pt.zcu;

    const ty = val.typeOf(zcu);
    const base_elem_count = ty.arrayBase(zcu)[1];
    if (skip.* >= base_elem_count) {
        skip.* -= base_elem_count;
        return;
    }

    if (ty.zigTypeTag(zcu) != .array) {
        out[@intCast(next_idx.*)] = (try val.intern(sema.pt, sema.arena)).toIntern();
        next_idx.* += 1;
        return;
    }

    const arr_base_elem_count = ty.childType(zcu).arrayBase(zcu)[1];
    for (0..@intCast(ty.arrayLen(zcu))) |elem_idx| {
        // Optimization: the `getElem` here may be expensive since we might intern an
        // element of the `bytes` representation, so avoid doing it unnecessarily.
        if (next_idx.* == out.len) return;
        if (skip.* >= arr_base_elem_count) {
            skip.* -= arr_base_elem_count;
            continue;
        }
        try flattenArray(sema, try val.getElem(sema.pt, elem_idx), skip, next_idx, out);
    }
    if (ty.sentinel(zcu)) |s| {
        try flattenArray(sema, .{ .interned = s.toIntern() }, skip, next_idx, out);
    }
}

/// Given a sequence of non-array elements, "unflatten" them into the given array type.
/// Asserts that values of `elems` are in-memory coercible to the array base type of `ty`.
fn unflattenArray(
    sema: *Sema,
    ty: Type,
    elems: []const InternPool.Index,
    next_idx: *u64,
) Allocator.Error!Value {
    const zcu = sema.pt.zcu;
    const arena = sema.arena;

    if (ty.zigTypeTag(zcu) != .array) {
        const val = Value.fromInterned(elems[@intCast(next_idx.*)]);
        next_idx.* += 1;
        return sema.pt.getCoerced(val, ty);
    }

    const elem_ty = ty.childType(zcu);
    const buf = try arena.alloc(InternPool.Index, @intCast(ty.arrayLen(zcu)));
    for (buf) |*elem| {
        elem.* = (try unflattenArray(sema, elem_ty, elems, next_idx)).toIntern();
    }
    if (ty.sentinel(zcu) != null) {
        // TODO: validate sentinel
        _ = try unflattenArray(sema, elem_ty, elems, next_idx);
    }
    return Value.fromInterned(try sema.pt.intern(.{ .aggregate = .{
        .ty = ty.toIntern(),
        .storage = .{ .elems = buf },
    } }));
}

/// Given a `MutableValue` representing a potentially-nested array, treats `index` as an index into
/// the array's base type. For instance, given a [3][3]T, the index 5 represents 'val[1][2]'.
/// The final level of array is not dereferenced. This allows use sites to use `setElem` to prevent
/// unnecessary `MutableValue` representation changes.
fn recursiveIndex(
    sema: *Sema,
    mv: *MutableValue,
    index: *u64,
) !?struct { *MutableValue, u64 } {
    const pt = sema.pt;

    const ty = mv.typeOf(pt.zcu);
    assert(ty.zigTypeTag(pt.zcu) == .array);

    const ty_base_elems = ty.arrayBase(pt.zcu)[1];
    if (index.* >= ty_base_elems) {
        index.* -= ty_base_elems;
        return null;
    }

    const elem_ty = ty.childType(pt.zcu);
    if (elem_ty.zigTypeTag(pt.zcu) != .array) {
        assert(index.* < ty.arrayLenIncludingSentinel(pt.zcu)); // should be handled by initial check
        return .{ mv, index.* };
    }

    for (0..@intCast(ty.arrayLenIncludingSentinel(pt.zcu))) |elem_index| {
        if (try recursiveIndex(sema, try mv.elem(pt, sema.arena, elem_index), index)) |result| {
            return result;
        }
    }
    unreachable; // should be handled by initial check
}

fn checkComptimeVarStore(
    sema: *Sema,
    block: *Block,
    src: LazySrcLoc,
    alloc_index: ComptimeAllocIndex,
) !void {
    const runtime_index = sema.getComptimeAlloc(alloc_index).runtime_index;
    if (@intFromEnum(runtime_index) < @intFromEnum(block.runtime_index)) {
        if (block.runtime_cond) |cond_src| {
            const msg = msg: {
                const msg = try sema.errMsg(src, "store to comptime variable depends on runtime condition", .{});
                errdefer msg.destroy(sema.gpa);
                try sema.errNote(cond_src, msg, "runtime condition here", .{});
                break :msg msg;
            };
            return sema.failWithOwnedErrorMsg(block, msg);
        }
        if (block.runtime_loop) |loop_src| {
            const msg = msg: {
                const msg = try sema.errMsg(src, "cannot store to comptime variable in non-inline loop", .{});
                errdefer msg.destroy(sema.gpa);
                try sema.errNote(loop_src, msg, "non-inline loop here", .{});
                break :msg msg;
            };
            return sema.failWithOwnedErrorMsg(block, msg);
        }
        unreachable;
    }
}

const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

const InternPool = @import("../InternPool.zig");
const ComptimeAllocIndex = InternPool.ComptimeAllocIndex;
const Sema = @import("../Sema.zig");
const Block = Sema.Block;
const MutableValue = @import("../mutable_value.zig").MutableValue;
const Type = @import("../Type.zig");
const Value = @import("../Value.zig");
const Zcu = @import("../Zcu.zig");
const LazySrcLoc = Zcu.LazySrcLoc;
