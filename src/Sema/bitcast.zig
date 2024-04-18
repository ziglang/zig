//! This file contains logic for bit-casting arbitrary values at comptime, including splicing
//! bits together for comptime stores of bit-pointers. The strategy is to "flatten" values to
//! a sequence of values in *packed* memory, and then unflatten through a combination of special
//! cases (particularly for pointers and `undefined` values) and in-memory buffer reinterprets.
//!
//! This is a little awkward on big-endian targets, as non-packed datastructures (e.g. `extern struct`)
//! have their fields reversed when represented as packed memory on such targets.

/// If `host_bits` is `0`, attempts to convert the memory at offset
/// `byte_offset` into `val` to a non-packed value of type `dest_ty`,
/// ignoring `bit_offset`.
///
/// Otherwise, `byte_offset` is an offset in bytes into `val` to a
/// non-packed value consisting of `host_bits` bits. A value of type
/// `dest_ty` will be interpreted at a packed offset of `bit_offset`
/// into this value.
///
/// Returns `null` if the operation must be performed at runtime.
pub fn bitCast(
    sema: *Sema,
    val: Value,
    dest_ty: Type,
    byte_offset: u64,
    host_bits: u64,
    bit_offset: u64,
) CompileError!?Value {
    return bitCastInner(sema, val, dest_ty, byte_offset, host_bits, bit_offset) catch |err| switch (err) {
        error.ReinterpretDeclRef => return null,
        error.IllDefinedMemoryLayout => unreachable,
        error.Unimplemented => @panic("unimplemented bitcast"),
        else => |e| return e,
    };
}

/// Uses bitcasting to splice the value `splice_val` into `val`,
/// replacing overlapping bits and returning the modified value.
///
/// If `host_bits` is `0`, splices `splice_val` at an offset
/// `byte_offset` bytes into the virtual memory of `val`, ignoring
/// `bit_offset`.
///
/// Otherwise, `byte_offset` is an offset into bytes into `val` to
/// a non-packed value consisting of `host_bits` bits. The value
/// `splice_val` will be placed at a packed offset of `bit_offset`
/// into this value.
pub fn bitCastSplice(
    sema: *Sema,
    val: Value,
    splice_val: Value,
    byte_offset: u64,
    host_bits: u64,
    bit_offset: u64,
) CompileError!?Value {
    return bitCastSpliceInner(sema, val, splice_val, byte_offset, host_bits, bit_offset) catch |err| switch (err) {
        error.ReinterpretDeclRef => return null,
        error.IllDefinedMemoryLayout => unreachable,
        error.Unimplemented => @panic("unimplemented bitcast"),
        else => |e| return e,
    };
}

const BitCastError = CompileError || error{ ReinterpretDeclRef, IllDefinedMemoryLayout, Unimplemented };

fn bitCastInner(
    sema: *Sema,
    val: Value,
    dest_ty: Type,
    byte_offset: u64,
    host_bits: u64,
    bit_offset: u64,
) BitCastError!Value {
    const zcu = sema.mod;
    const endian = zcu.getTarget().cpu.arch.endian();

    if (dest_ty.toIntern() == val.typeOf(zcu).toIntern() and bit_offset == 0) {
        return val;
    }

    const val_ty = val.typeOf(zcu);

    try sema.resolveTypeLayout(val_ty);
    try sema.resolveTypeLayout(dest_ty);

    assert(val_ty.hasWellDefinedLayout(zcu));

    const abi_pad_bits, const host_pad_bits = if (host_bits > 0)
        .{ val_ty.abiSize(zcu) * 8 - host_bits, host_bits - val_ty.bitSize(zcu) }
    else
        .{ val_ty.abiSize(zcu) * 8 - val_ty.bitSize(zcu), 0 };

    const skip_bits = switch (endian) {
        .little => bit_offset + byte_offset * 8,
        .big => if (host_bits > 0)
            val_ty.abiSize(zcu) * 8 - byte_offset * 8 - host_bits + bit_offset
        else
            val_ty.abiSize(zcu) * 8 - byte_offset * 8 - dest_ty.bitSize(zcu),
    };

    var unpack: UnpackValueBits = .{
        .zcu = zcu,
        .arena = sema.arena,
        .skip_bits = skip_bits,
        .remaining_bits = dest_ty.bitSize(zcu),
        .unpacked = std.ArrayList(InternPool.Index).init(sema.arena),
    };
    switch (endian) {
        .little => {
            try unpack.add(val);
            try unpack.padding(abi_pad_bits);
        },
        .big => {
            try unpack.padding(abi_pad_bits);
            try unpack.add(val);
        },
    }
    try unpack.padding(host_pad_bits);

    var pack: PackValueBits = .{
        .zcu = zcu,
        .arena = sema.arena,
        .unpacked = unpack.unpacked.items,
    };
    return pack.get(dest_ty);
}

fn bitCastSpliceInner(
    sema: *Sema,
    val: Value,
    splice_val: Value,
    byte_offset: u64,
    host_bits: u64,
    bit_offset: u64,
) BitCastError!Value {
    const zcu = sema.mod;
    const endian = zcu.getTarget().cpu.arch.endian();
    const val_ty = val.typeOf(zcu);
    const splice_val_ty = splice_val.typeOf(zcu);

    try sema.resolveTypeLayout(val_ty);
    try sema.resolveTypeLayout(splice_val_ty);

    const splice_bits = splice_val_ty.bitSize(zcu);

    const splice_offset = switch (endian) {
        .little => bit_offset + byte_offset * 8,
        .big => if (host_bits > 0)
            val_ty.abiSize(zcu) * 8 - byte_offset * 8 - host_bits + bit_offset
        else
            val_ty.abiSize(zcu) * 8 - byte_offset * 8 - splice_bits,
    };

    assert(splice_offset + splice_bits <= val_ty.abiSize(zcu) * 8);

    const abi_pad_bits, const host_pad_bits = if (host_bits > 0)
        .{ val_ty.abiSize(zcu) * 8 - host_bits, host_bits - val_ty.bitSize(zcu) }
    else
        .{ val_ty.abiSize(zcu) * 8 - val_ty.bitSize(zcu), 0 };

    var unpack: UnpackValueBits = .{
        .zcu = zcu,
        .arena = sema.arena,
        .skip_bits = 0,
        .remaining_bits = splice_offset,
        .unpacked = std.ArrayList(InternPool.Index).init(sema.arena),
    };
    switch (endian) {
        .little => {
            try unpack.add(val);
            try unpack.padding(abi_pad_bits);
        },
        .big => {
            try unpack.padding(abi_pad_bits);
            try unpack.add(val);
        },
    }
    try unpack.padding(host_pad_bits);

    unpack.remaining_bits = splice_bits;
    try unpack.add(splice_val);

    unpack.skip_bits = splice_offset + splice_bits;
    unpack.remaining_bits = val_ty.abiSize(zcu) * 8 - splice_offset - splice_bits;
    switch (endian) {
        .little => {
            try unpack.add(val);
            try unpack.padding(abi_pad_bits);
        },
        .big => {
            try unpack.padding(abi_pad_bits);
            try unpack.add(val);
        },
    }
    try unpack.padding(host_pad_bits);

    var pack: PackValueBits = .{
        .zcu = zcu,
        .arena = sema.arena,
        .unpacked = unpack.unpacked.items,
    };
    switch (endian) {
        .little => {},
        .big => try pack.padding(abi_pad_bits),
    }
    return pack.get(val_ty);
}

/// Recurses through struct fields, array elements, etc, to get a sequence of "primitive" values
/// which are bit-packed in memory to represent a single value. `unpacked` represents a series
/// of values in *packed* memory - therefore, on big-endian targets, the first element of this
/// list contains bits from the *final* byte of the value.
const UnpackValueBits = struct {
    zcu: *Zcu,
    arena: Allocator,
    skip_bits: u64,
    remaining_bits: u64,
    extra_bits: u64 = undefined,
    unpacked: std.ArrayList(InternPool.Index),

    fn add(unpack: *UnpackValueBits, val: Value) BitCastError!void {
        const zcu = unpack.zcu;
        const endian = zcu.getTarget().cpu.arch.endian();
        const ip = &zcu.intern_pool;

        if (unpack.remaining_bits == 0) {
            return;
        }

        const ty = val.typeOf(zcu);
        const bit_size = ty.bitSize(zcu);

        if (unpack.skip_bits >= bit_size) {
            unpack.skip_bits -= bit_size;
            return;
        }

        switch (ip.indexToKey(val.toIntern())) {
            .int_type,
            .ptr_type,
            .array_type,
            .vector_type,
            .opt_type,
            .anyframe_type,
            .error_union_type,
            .simple_type,
            .struct_type,
            .anon_struct_type,
            .union_type,
            .opaque_type,
            .enum_type,
            .func_type,
            .error_set_type,
            .inferred_error_set_type,
            .variable,
            .extern_func,
            .func,
            .err,
            .error_union,
            .enum_literal,
            .slice,
            .memoized_call,
            => unreachable, // ill-defined layout or not real values

            .undef,
            .int,
            .enum_tag,
            .simple_value,
            .empty_enum_value,
            .float,
            .ptr,
            .opt,
            => try unpack.primitive(val),

            .aggregate => switch (ty.zigTypeTag(zcu)) {
                .Vector => {
                    const len: usize = @intCast(ty.arrayLen(zcu));
                    for (0..len) |i| {
                        // We reverse vector elements in packed memory on BE targets.
                        const real_idx = switch (endian) {
                            .little => i,
                            .big => len - i - 1,
                        };
                        const elem_val = try val.elemValue(zcu, real_idx);
                        try unpack.add(elem_val);
                    }
                },
                .Array => {
                    // Each element is padded up to its ABI size. Padding bits are undefined.
                    // The final element does not have trailing padding.
                    // Elements are reversed in packed memory on BE targets.
                    const elem_ty = ty.childType(zcu);
                    const pad_bits = elem_ty.abiSize(zcu) * 8 - elem_ty.bitSize(zcu);
                    const len = ty.arrayLen(zcu);
                    const maybe_sent = ty.sentinel(zcu);

                    if (endian == .big) if (maybe_sent) |s| {
                        try unpack.add(s);
                        if (len != 0) try unpack.padding(pad_bits);
                    };

                    for (0..@intCast(len)) |i| {
                        // We reverse array elements in packed memory on BE targets.
                        const real_idx = switch (endian) {
                            .little => i,
                            .big => len - i - 1,
                        };
                        const elem_val = try val.elemValue(zcu, @intCast(real_idx));
                        try unpack.add(elem_val);
                        if (i != len - 1) try unpack.padding(pad_bits);
                    }

                    if (endian == .little) if (maybe_sent) |s| {
                        if (len != 0) try unpack.padding(pad_bits);
                        try unpack.add(s);
                    };
                },
                .Struct => switch (ty.containerLayout(zcu)) {
                    .auto => unreachable, // ill-defined layout
                    .@"extern" => switch (endian) {
                        .little => {
                            var cur_bit_off: u64 = 0;
                            var it = zcu.typeToStruct(ty).?.iterateRuntimeOrder(ip);
                            while (it.next()) |field_idx| {
                                const want_bit_off = ty.structFieldOffset(field_idx, zcu) * 8;
                                const pad_bits = want_bit_off - cur_bit_off;
                                const field_val = try val.fieldValue(zcu, field_idx);
                                try unpack.padding(pad_bits);
                                try unpack.add(field_val);
                                cur_bit_off = want_bit_off + field_val.typeOf(zcu).bitSize(zcu);
                            }
                            // Add trailing padding bits.
                            try unpack.padding(bit_size - cur_bit_off);
                        },
                        .big => {
                            var cur_bit_off: u64 = bit_size;
                            var it = zcu.typeToStruct(ty).?.iterateRuntimeOrderReverse(ip);
                            while (it.next()) |field_idx| {
                                const field_val = try val.fieldValue(zcu, field_idx);
                                const field_ty = field_val.typeOf(zcu);
                                const want_bit_off = ty.structFieldOffset(field_idx, zcu) * 8 + field_ty.bitSize(zcu);
                                const pad_bits = cur_bit_off - want_bit_off;
                                try unpack.padding(pad_bits);
                                try unpack.add(field_val);
                                cur_bit_off = want_bit_off - field_ty.bitSize(zcu);
                            }
                            assert(cur_bit_off == 0);
                        },
                    },
                    .@"packed" => {
                        // Just add all fields in order. There are no padding bits.
                        // This is identical between LE and BE targets.
                        for (0..ty.structFieldCount(zcu)) |i| {
                            const field_val = try val.fieldValue(zcu, i);
                            try unpack.add(field_val);
                        }
                    },
                },
                else => unreachable,
            },

            .un => |un| {
                // We actually don't care about the tag here!
                // Instead, we just need to write the payload value, plus any necessary padding.
                // This correctly handles the case where `tag == .none`, since the payload is then
                // either an integer or a byte array, both of which we can unpack.
                const payload_val = Value.fromInterned(un.val);
                const pad_bits = bit_size - payload_val.typeOf(zcu).bitSize(zcu);
                if (endian == .little or ty.containerLayout(zcu) == .@"packed") {
                    try unpack.add(payload_val);
                    try unpack.padding(pad_bits);
                } else {
                    try unpack.padding(pad_bits);
                    try unpack.add(payload_val);
                }
            },
        }
    }

    fn padding(unpack: *UnpackValueBits, pad_bits: u64) BitCastError!void {
        if (pad_bits == 0) return;
        const zcu = unpack.zcu;
        // Figure out how many full bytes and leftover bits there are.
        const bytes = pad_bits / 8;
        const bits = pad_bits % 8;
        // Add undef u8 values for the bytes...
        const undef_u8 = try zcu.undefValue(Type.u8);
        for (0..@intCast(bytes)) |_| {
            try unpack.primitive(undef_u8);
        }
        // ...and an undef int for the leftover bits.
        if (bits == 0) return;
        const bits_ty = try zcu.intType(.unsigned, @intCast(bits));
        const bits_val = try zcu.undefValue(bits_ty);
        try unpack.primitive(bits_val);
    }

    fn primitive(unpack: *UnpackValueBits, val: Value) BitCastError!void {
        const zcu = unpack.zcu;

        if (unpack.remaining_bits == 0) {
            return;
        }

        const ty = val.typeOf(zcu);
        const bit_size = ty.bitSize(zcu);

        // Note that this skips all zero-bit types.
        if (unpack.skip_bits >= bit_size) {
            unpack.skip_bits -= bit_size;
            return;
        }

        if (unpack.skip_bits > 0) {
            const skip = unpack.skip_bits;
            unpack.skip_bits = 0;
            return unpack.splitPrimitive(val, skip, bit_size - skip);
        }

        if (unpack.remaining_bits < bit_size) {
            return unpack.splitPrimitive(val, 0, unpack.remaining_bits);
        }

        unpack.remaining_bits -|= bit_size;

        try unpack.unpacked.append(val.toIntern());
    }

    fn splitPrimitive(unpack: *UnpackValueBits, val: Value, bit_offset: u64, bit_count: u64) BitCastError!void {
        const zcu = unpack.zcu;
        const ty = val.typeOf(zcu);

        const val_bits = ty.bitSize(zcu);
        assert(bit_offset + bit_count <= val_bits);

        switch (zcu.intern_pool.indexToKey(val.toIntern())) {
            // In the `ptr` case, this will return `error.ReinterpretDeclRef`
            // if we're trying to split a non-integer pointer value.
            .int, .float, .enum_tag, .ptr, .opt => {
                // This @intCast is okay because no primitive can exceed the size of a u16.
                const int_ty = try zcu.intType(.unsigned, @intCast(bit_count));
                const buf = try unpack.arena.alloc(u8, @intCast((val_bits + 7) / 8));
                try val.writeToPackedMemory(ty, zcu, buf, 0);
                const sub_val = try Value.readFromPackedMemory(int_ty, zcu, buf, @intCast(bit_offset), unpack.arena);
                try unpack.primitive(sub_val);
            },
            .undef => try unpack.padding(bit_count),
            // The only values here with runtime bits are `true` and `false.
            // These are both 1 bit, so will never need truncating.
            .simple_value => unreachable,
            .empty_enum_value => unreachable, // zero-bit
            else => unreachable, // zero-bit or not primitives
        }
    }
};

/// Given a sequence of bit-packed values in packed memory (see `UnpackValueBits`),
/// reconstructs a value of an arbitrary type, with correct handling of `undefined`
/// values and of pointers which align in virtual memory.
const PackValueBits = struct {
    zcu: *Zcu,
    arena: Allocator,
    bit_offset: u64 = 0,
    unpacked: []const InternPool.Index,

    fn get(pack: *PackValueBits, ty: Type) BitCastError!Value {
        const zcu = pack.zcu;
        const endian = zcu.getTarget().cpu.arch.endian();
        const ip = &zcu.intern_pool;
        const arena = pack.arena;
        switch (ty.zigTypeTag(zcu)) {
            .Vector => {
                // Elements are bit-packed.
                const len = ty.arrayLen(zcu);
                const elem_ty = ty.childType(zcu);
                const elems = try arena.alloc(InternPool.Index, @intCast(len));
                // We reverse vector elements in packed memory on BE targets.
                switch (endian) {
                    .little => for (elems) |*elem| {
                        elem.* = (try pack.get(elem_ty)).toIntern();
                    },
                    .big => {
                        var i = elems.len;
                        while (i > 0) {
                            i -= 1;
                            elems[i] = (try pack.get(elem_ty)).toIntern();
                        }
                    },
                }
                return Value.fromInterned(try zcu.intern(.{ .aggregate = .{
                    .ty = ty.toIntern(),
                    .storage = .{ .elems = elems },
                } }));
            },
            .Array => {
                // Each element is padded up to its ABI size. The final element does not have trailing padding.
                const len = ty.arrayLen(zcu);
                const elem_ty = ty.childType(zcu);
                const maybe_sent = ty.sentinel(zcu);
                const pad_bits = elem_ty.abiSize(zcu) * 8 - elem_ty.bitSize(zcu);
                const elems = try arena.alloc(InternPool.Index, @intCast(len));

                if (endian == .big and maybe_sent != null) {
                    // TODO: validate sentinel was preserved!
                    try pack.padding(elem_ty.bitSize(zcu));
                    if (len != 0) try pack.padding(pad_bits);
                }

                for (0..elems.len) |i| {
                    const real_idx = switch (endian) {
                        .little => i,
                        .big => len - i - 1,
                    };
                    elems[@intCast(real_idx)] = (try pack.get(elem_ty)).toIntern();
                    if (i != len - 1) try pack.padding(pad_bits);
                }

                if (endian == .little and maybe_sent != null) {
                    // TODO: validate sentinel was preserved!
                    if (len != 0) try pack.padding(pad_bits);
                    try pack.padding(elem_ty.bitSize(zcu));
                }

                return Value.fromInterned(try zcu.intern(.{ .aggregate = .{
                    .ty = ty.toIntern(),
                    .storage = .{ .elems = elems },
                } }));
            },
            .Struct => switch (ty.containerLayout(zcu)) {
                .auto => unreachable, // ill-defined layout
                .@"extern" => {
                    const elems = try arena.alloc(InternPool.Index, ty.structFieldCount(zcu));
                    @memset(elems, .none);
                    switch (endian) {
                        .little => {
                            var cur_bit_off: u64 = 0;
                            var it = zcu.typeToStruct(ty).?.iterateRuntimeOrder(ip);
                            while (it.next()) |field_idx| {
                                const want_bit_off = ty.structFieldOffset(field_idx, zcu) * 8;
                                try pack.padding(want_bit_off - cur_bit_off);
                                const field_ty = ty.structFieldType(field_idx, zcu);
                                elems[field_idx] = (try pack.get(field_ty)).toIntern();
                                cur_bit_off = want_bit_off + field_ty.bitSize(zcu);
                            }
                            try pack.padding(ty.bitSize(zcu) - cur_bit_off);
                        },
                        .big => {
                            var cur_bit_off: u64 = ty.bitSize(zcu);
                            var it = zcu.typeToStruct(ty).?.iterateRuntimeOrderReverse(ip);
                            while (it.next()) |field_idx| {
                                const field_ty = ty.structFieldType(field_idx, zcu);
                                const want_bit_off = ty.structFieldOffset(field_idx, zcu) * 8 + field_ty.bitSize(zcu);
                                try pack.padding(cur_bit_off - want_bit_off);
                                elems[field_idx] = (try pack.get(field_ty)).toIntern();
                                cur_bit_off = want_bit_off - field_ty.bitSize(zcu);
                            }
                            assert(cur_bit_off == 0);
                        },
                    }
                    // Any fields which do not have runtime bits should be OPV or comptime fields.
                    // Fill those values now.
                    for (elems, 0..) |*elem, field_idx| {
                        if (elem.* != .none) continue;
                        const val = (try ty.structFieldValueComptime(zcu, field_idx)).?;
                        elem.* = val.toIntern();
                    }
                    return Value.fromInterned(try zcu.intern(.{ .aggregate = .{
                        .ty = ty.toIntern(),
                        .storage = .{ .elems = elems },
                    } }));
                },
                .@"packed" => {
                    // All fields are in order with no padding.
                    // This is identical between LE and BE targets.
                    const elems = try arena.alloc(InternPool.Index, ty.structFieldCount(zcu));
                    for (elems, 0..) |*elem, i| {
                        const field_ty = ty.structFieldType(i, zcu);
                        elem.* = (try pack.get(field_ty)).toIntern();
                    }
                    return Value.fromInterned(try zcu.intern(.{ .aggregate = .{
                        .ty = ty.toIntern(),
                        .storage = .{ .elems = elems },
                    } }));
                },
            },
            .Union => {
                // We will attempt to read as the backing representation. If this emits
                // `error.ReinterpretDeclRef`, we will try each union field, preferring larger ones.
                // We will also attempt smaller fields when we get `undefined`, as if some bits are
                // defined we want to include them.
                // TODO: this is very very bad. We need a more sophisticated union representation.

                const prev_unpacked = pack.unpacked;
                const prev_bit_offset = pack.bit_offset;

                const backing_ty = try ty.unionBackingType(zcu);

                backing: {
                    const backing_val = pack.get(backing_ty) catch |err| switch (err) {
                        error.ReinterpretDeclRef => {
                            pack.unpacked = prev_unpacked;
                            pack.bit_offset = prev_bit_offset;
                            break :backing;
                        },
                        else => |e| return e,
                    };
                    if (backing_val.isUndef(zcu)) {
                        pack.unpacked = prev_unpacked;
                        pack.bit_offset = prev_bit_offset;
                        break :backing;
                    }
                    return Value.fromInterned(try zcu.intern(.{ .un = .{
                        .ty = ty.toIntern(),
                        .tag = .none,
                        .val = backing_val.toIntern(),
                    } }));
                }

                const field_order = try pack.arena.alloc(u32, ty.unionTagTypeHypothetical(zcu).enumFieldCount(zcu));
                for (field_order, 0..) |*f, i| f.* = @intCast(i);
                // Sort `field_order` to put the fields with the largest bit sizes first.
                const SizeSortCtx = struct {
                    zcu: *Zcu,
                    field_types: []const InternPool.Index,
                    fn lessThan(ctx: @This(), a_idx: u32, b_idx: u32) bool {
                        const a_ty = Type.fromInterned(ctx.field_types[a_idx]);
                        const b_ty = Type.fromInterned(ctx.field_types[b_idx]);
                        return a_ty.bitSize(ctx.zcu) > b_ty.bitSize(ctx.zcu);
                    }
                };
                std.mem.sortUnstable(u32, field_order, SizeSortCtx{
                    .zcu = zcu,
                    .field_types = zcu.typeToUnion(ty).?.field_types.get(ip),
                }, SizeSortCtx.lessThan);

                const padding_after = endian == .little or ty.containerLayout(zcu) == .@"packed";

                for (field_order) |field_idx| {
                    const field_ty = Type.fromInterned(zcu.typeToUnion(ty).?.field_types.get(ip)[field_idx]);
                    const pad_bits = ty.bitSize(zcu) - field_ty.bitSize(zcu);
                    if (!padding_after) try pack.padding(pad_bits);
                    const field_val = pack.get(field_ty) catch |err| switch (err) {
                        error.ReinterpretDeclRef => {
                            pack.unpacked = prev_unpacked;
                            pack.bit_offset = prev_bit_offset;
                            continue;
                        },
                        else => |e| return e,
                    };
                    if (padding_after) try pack.padding(pad_bits);
                    if (field_val.isUndef(zcu)) {
                        pack.unpacked = prev_unpacked;
                        pack.bit_offset = prev_bit_offset;
                        continue;
                    }
                    const tag_val = try zcu.enumValueFieldIndex(ty.unionTagTypeHypothetical(zcu), field_idx);
                    return Value.fromInterned(try zcu.intern(.{ .un = .{
                        .ty = ty.toIntern(),
                        .tag = tag_val.toIntern(),
                        .val = field_val.toIntern(),
                    } }));
                }

                // No field could represent the value. Just do whatever happens when we try to read
                // the backing type - either `undefined` or `error.ReinterpretDeclRef`.
                const backing_val = try pack.get(backing_ty);
                return Value.fromInterned(try zcu.intern(.{ .un = .{
                    .ty = ty.toIntern(),
                    .tag = .none,
                    .val = backing_val.toIntern(),
                } }));
            },
            else => return pack.primitive(ty),
        }
    }

    fn padding(pack: *PackValueBits, pad_bits: u64) BitCastError!void {
        _ = pack.prepareBits(pad_bits);
    }

    fn primitive(pack: *PackValueBits, want_ty: Type) BitCastError!Value {
        const zcu = pack.zcu;
        const vals, const bit_offset = pack.prepareBits(want_ty.bitSize(zcu));

        for (vals) |val| {
            if (!Value.fromInterned(val).isUndef(zcu)) break;
        } else {
            // All bits of the value are `undefined`.
            return zcu.undefValue(want_ty);
        }

        // TODO: we need to decide how to handle partially-undef values here.
        // Currently, a value with some undefined bits becomes `0xAA` so that we
        // preserve the well-defined bits, because we can't currently represent
        // a partially-undefined primitive (e.g. an int with some undef bits).
        // In future, we probably want to take one of these two routes:
        // * Define that if any bits are `undefined`, the entire value is `undefined`.
        //   This is a major breaking change, and probably a footgun.
        // * Introduce tracking for partially-undef values at comptime.
        //   This would complicate a lot of operations in Sema, such as basic
        //   arithmetic.
        // This design complexity is tracked by #19634.

        ptr_cast: {
            if (vals.len != 1) break :ptr_cast;
            const val = Value.fromInterned(vals[0]);
            if (!val.typeOf(zcu).isPtrAtRuntime(zcu)) break :ptr_cast;
            if (!want_ty.isPtrAtRuntime(zcu)) break :ptr_cast;
            return zcu.getCoerced(val, want_ty);
        }

        // Reinterpret via an in-memory buffer.

        var buf_bits: u64 = 0;
        for (vals) |ip_val| {
            const val = Value.fromInterned(ip_val);
            const ty = val.typeOf(zcu);
            buf_bits += ty.bitSize(zcu);
        }

        const buf = try pack.arena.alloc(u8, @intCast((buf_bits + 7) / 8));
        // We will skip writing undefined values, so mark the buffer as `0xAA` so we get "undefined" bits.
        @memset(buf, 0xAA);
        var cur_bit_off: usize = 0;
        for (vals) |ip_val| {
            const val = Value.fromInterned(ip_val);
            const ty = val.typeOf(zcu);
            if (!val.isUndef(zcu)) {
                try val.writeToPackedMemory(ty, zcu, buf, cur_bit_off);
            }
            cur_bit_off += @intCast(ty.bitSize(zcu));
        }

        return Value.readFromPackedMemory(want_ty, zcu, buf, @intCast(bit_offset), pack.arena);
    }

    fn prepareBits(pack: *PackValueBits, need_bits: u64) struct { []const InternPool.Index, u64 } {
        if (need_bits == 0) return .{ &.{}, 0 };

        const zcu = pack.zcu;

        var bits: u64 = 0;
        var len: usize = 0;
        while (bits < pack.bit_offset + need_bits) {
            bits += Value.fromInterned(pack.unpacked[len]).typeOf(zcu).bitSize(zcu);
            len += 1;
        }

        const result_vals = pack.unpacked[0..len];
        const result_offset = pack.bit_offset;

        const extra_bits = bits - pack.bit_offset - need_bits;
        if (extra_bits == 0) {
            pack.unpacked = pack.unpacked[len..];
            pack.bit_offset = 0;
        } else {
            pack.unpacked = pack.unpacked[len - 1 ..];
            pack.bit_offset = Value.fromInterned(pack.unpacked[0]).typeOf(zcu).bitSize(zcu) - extra_bits;
        }

        return .{ result_vals, result_offset };
    }
};

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const Sema = @import("../Sema.zig");
const Zcu = @import("../Module.zig");
const InternPool = @import("../InternPool.zig");
const Type = @import("../type.zig").Type;
const Value = @import("../Value.zig");
const CompileError = Zcu.CompileError;
