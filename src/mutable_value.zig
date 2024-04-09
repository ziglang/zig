const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Zcu = @import("Module.zig");
const InternPool = @import("InternPool.zig");
const Type = @import("type.zig").Type;
const Value = @import("Value.zig");

/// We use a tagged union here because while it wastes a few bytes for some tags, having a fixed
/// size for the type makes the common `aggregate` representation more efficient.
/// For aggregates, the sentinel value, if any, *is* stored.
pub const MutableValue = union(enum) {
    /// An interned value.
    interned: InternPool.Index,
    /// An error union value which is a payload (not an error).
    eu_payload: SubValue,
    /// An optional value which is a payload (not `null`).
    opt_payload: SubValue,
    /// An aggregate consisting of a single repeated value.
    repeated: SubValue,
    /// An aggregate of `u8` consisting of "plain" bytes (no lazy or undefined elements).
    bytes: Bytes,
    /// An aggregate with arbitrary sub-values.
    aggregate: Aggregate,
    /// A slice, containing a pointer and length.
    slice: Slice,
    /// An instance of a union.
    un: Union,

    pub const SubValue = struct {
        ty: InternPool.Index,
        child: *MutableValue,
    };
    pub const Bytes = struct {
        ty: InternPool.Index,
        data: []u8,
    };
    pub const Aggregate = struct {
        ty: InternPool.Index,
        elems: []MutableValue,
    };
    pub const Slice = struct {
        ty: InternPool.Index,
        /// Must have the appropriate many-ptr type.
        /// TODO: we want this to be an `InternPool.Index`, but `Sema.beginComptimePtrMutation` doesn't support it.
        ptr: *MutableValue,
        /// Must be of type `usize`.
        /// TODO: we want this to be an `InternPool.Index`, but `Sema.beginComptimePtrMutation` doesn't support it.
        len: *MutableValue,
    };
    pub const Union = struct {
        ty: InternPool.Index,
        tag: InternPool.Index,
        payload: *MutableValue,
    };

    pub fn intern(mv: MutableValue, zcu: *Zcu, arena: Allocator) Allocator.Error!InternPool.Index {
        const ip = &zcu.intern_pool;
        const gpa = zcu.gpa;
        return switch (mv) {
            .interned => |ip_index| ip_index,
            .eu_payload => |sv| try ip.get(gpa, .{ .error_union = .{
                .ty = sv.ty,
                .val = .{ .payload = try sv.child.intern(zcu, arena) },
            } }),
            .opt_payload => |sv| try ip.get(gpa, .{ .opt = .{
                .ty = sv.ty,
                .val = try sv.child.intern(zcu, arena),
            } }),
            .repeated => |sv| try ip.get(gpa, .{ .aggregate = .{
                .ty = sv.ty,
                .storage = .{ .repeated_elem = try sv.child.intern(zcu, arena) },
            } }),
            .bytes => |b| try ip.get(gpa, .{ .aggregate = .{
                .ty = b.ty,
                .storage = .{ .bytes = try ip.getOrPutString(gpa, b.data, .maybe_embedded_nulls) },
            } }),
            .aggregate => |a| {
                const elems = try arena.alloc(InternPool.Index, a.elems.len);
                for (a.elems, elems) |mut_elem, *interned_elem| {
                    interned_elem.* = try mut_elem.intern(zcu, arena);
                }
                return ip.get(gpa, .{ .aggregate = .{
                    .ty = a.ty,
                    .storage = .{ .elems = elems },
                } });
            },
            .slice => |s| try ip.get(gpa, .{ .slice = .{
                .ty = s.ty,
                .ptr = try s.ptr.intern(zcu, arena),
                .len = try s.len.intern(zcu, arena),
            } }),
            .un => |u| try ip.get(gpa, .{ .un = .{
                .ty = u.ty,
                .tag = u.tag,
                .val = try u.payload.intern(zcu, arena),
            } }),
        };
    }

    /// Un-interns the top level of this `MutableValue`, if applicable.
    /// * Non-error error unions use `eu_payload`
    /// * Non-null optionals use `eu_payload
    /// * Slices use `slice`
    /// * Unions use `un`
    /// * Aggregates use `repeated` or `bytes` or `aggregate`
    /// If `!allow_bytes`, the `bytes` representation will not be used.
    /// If `!allow_repeated`, the `repeated` representation will not be used.
    pub fn unintern(
        mv: *MutableValue,
        zcu: *Zcu,
        arena: Allocator,
        allow_bytes: bool,
        allow_repeated: bool,
    ) Allocator.Error!void {
        const ip = &zcu.intern_pool;
        const gpa = zcu.gpa;
        switch (mv.*) {
            .interned => |ip_index| switch (ip.indexToKey(ip_index)) {
                .opt => |opt| if (opt.val != .none) {
                    const mut_payload = try arena.create(MutableValue);
                    mut_payload.* = .{ .interned = opt.val };
                    mv.* = .{ .opt_payload = .{
                        .ty = opt.ty,
                        .child = mut_payload,
                    } };
                },
                .error_union => |eu| switch (eu.val) {
                    .err_name => {},
                    .payload => |payload| {
                        const mut_payload = try arena.create(MutableValue);
                        mut_payload.* = .{ .interned = payload };
                        mv.* = .{ .eu_payload = .{
                            .ty = eu.ty,
                            .child = mut_payload,
                        } };
                    },
                },
                .slice => |slice| {
                    const ptr = try arena.create(MutableValue);
                    const len = try arena.create(MutableValue);
                    ptr.* = .{ .interned = slice.ptr };
                    len.* = .{ .interned = slice.len };
                    mv.* = .{ .slice = .{
                        .ty = slice.ty,
                        .ptr = ptr,
                        .len = len,
                    } };
                },
                .un => |un| {
                    const payload = try arena.create(MutableValue);
                    payload.* = .{ .interned = un.val };
                    mv.* = .{ .un = .{
                        .ty = un.ty,
                        .tag = un.tag,
                        .payload = payload,
                    } };
                },
                .aggregate => |agg| switch (agg.storage) {
                    .bytes => |bytes| {
                        const len: usize = @intCast(ip.aggregateTypeLenIncludingSentinel(agg.ty));
                        assert(ip.childType(agg.ty) == .u8_type);
                        if (allow_bytes) {
                            const arena_bytes = try arena.alloc(u8, len);
                            @memcpy(arena_bytes, bytes.toSlice(len, ip));
                            mv.* = .{ .bytes = .{
                                .ty = agg.ty,
                                .data = arena_bytes,
                            } };
                        } else {
                            const mut_elems = try arena.alloc(MutableValue, len);
                            for (bytes.toSlice(len, ip), mut_elems) |b, *mut_elem| {
                                mut_elem.* = .{ .interned = try ip.get(gpa, .{ .int = .{
                                    .ty = .u8_type,
                                    .storage = .{ .u64 = b },
                                } }) };
                            }
                            mv.* = .{ .aggregate = .{
                                .ty = agg.ty,
                                .elems = mut_elems,
                            } };
                        }
                    },
                    .elems => |elems| {
                        assert(elems.len == ip.aggregateTypeLenIncludingSentinel(agg.ty));
                        const mut_elems = try arena.alloc(MutableValue, elems.len);
                        for (elems, mut_elems) |interned_elem, *mut_elem| {
                            mut_elem.* = .{ .interned = interned_elem };
                        }
                        mv.* = .{ .aggregate = .{
                            .ty = agg.ty,
                            .elems = mut_elems,
                        } };
                    },
                    .repeated_elem => |val| {
                        if (allow_repeated) {
                            const repeated_val = try arena.create(MutableValue);
                            repeated_val.* = .{ .interned = val };
                            mv.* = .{ .repeated = .{
                                .ty = agg.ty,
                                .child = repeated_val,
                            } };
                        } else {
                            const len = ip.aggregateTypeLenIncludingSentinel(agg.ty);
                            const mut_elems = try arena.alloc(MutableValue, @intCast(len));
                            @memset(mut_elems, .{ .interned = val });
                            mv.* = .{ .aggregate = .{
                                .ty = agg.ty,
                                .elems = mut_elems,
                            } };
                        }
                    },
                },
                .undef => |ty_ip| switch (Type.fromInterned(ty_ip).zigTypeTag(zcu)) {
                    .Struct, .Array, .Vector => |type_tag| {
                        const ty = Type.fromInterned(ty_ip);
                        const opt_sent = ty.sentinel(zcu);
                        if (type_tag == .Struct or opt_sent != null or !allow_repeated) {
                            const len_no_sent = ip.aggregateTypeLen(ty_ip);
                            const elems = try arena.alloc(MutableValue, @intCast(len_no_sent + @intFromBool(opt_sent != null)));
                            switch (type_tag) {
                                .Array, .Vector => {
                                    const elem_ty = ip.childType(ty_ip);
                                    const undef_elem = try ip.get(gpa, .{ .undef = elem_ty });
                                    @memset(elems[0..@intCast(len_no_sent)], .{ .interned = undef_elem });
                                },
                                .Struct => for (elems[0..@intCast(len_no_sent)], 0..) |*mut_elem, i| {
                                    const field_ty = ty.structFieldType(i, zcu).toIntern();
                                    mut_elem.* = .{ .interned = try ip.get(gpa, .{ .undef = field_ty }) };
                                },
                                else => unreachable,
                            }
                            if (opt_sent) |s| elems[@intCast(len_no_sent)] = .{ .interned = s.toIntern() };
                            mv.* = .{ .aggregate = .{
                                .ty = ty_ip,
                                .elems = elems,
                            } };
                        } else {
                            const repeated_val = try arena.create(MutableValue);
                            repeated_val.* = .{
                                .interned = try ip.get(gpa, .{ .undef = ip.childType(ty_ip) }),
                            };
                            mv.* = .{ .repeated = .{
                                .ty = ty_ip,
                                .child = repeated_val,
                            } };
                        }
                    },
                    .Union => {
                        const payload = try arena.create(MutableValue);
                        // HACKHACK: this logic is silly, but Sema detects it and reverts the change where needed.
                        // See comment at the top of `Sema.beginComptimePtrMutationInner`.
                        payload.* = .{ .interned = .undef };
                        mv.* = .{ .un = .{
                            .ty = ty_ip,
                            .tag = .none,
                            .payload = payload,
                        } };
                    },
                    .Pointer => {
                        const ptr_ty = ip.indexToKey(ty_ip).ptr_type;
                        if (ptr_ty.flags.size != .Slice) return;
                        const ptr = try arena.create(MutableValue);
                        const len = try arena.create(MutableValue);
                        ptr.* = .{ .interned = try ip.get(gpa, .{ .undef = ip.slicePtrType(ty_ip) }) };
                        len.* = .{ .interned = try ip.get(gpa, .{ .undef = .usize_type }) };
                        mv.* = .{ .slice = .{
                            .ty = ty_ip,
                            .ptr = ptr,
                            .len = len,
                        } };
                    },
                    else => {},
                },
                else => {},
            },
            .bytes => |bytes| if (!allow_bytes) {
                const elems = try arena.alloc(MutableValue, bytes.data.len);
                for (bytes.data, elems) |byte, *interned_byte| {
                    interned_byte.* = .{ .interned = try ip.get(gpa, .{ .int = .{
                        .ty = .u8_type,
                        .storage = .{ .u64 = byte },
                    } }) };
                }
                mv.* = .{ .aggregate = .{
                    .ty = bytes.ty,
                    .elems = elems,
                } };
            },
            else => {},
        }
    }

    /// Get a pointer to the `MutableValue` associated with a field/element.
    /// The returned pointer can be safety mutated through to modify the field value.
    /// The returned pointer is valid until the representation of `mv` changes.
    /// This function does *not* support accessing the ptr/len field of slices.
    pub fn elem(
        mv: *MutableValue,
        zcu: *Zcu,
        arena: Allocator,
        field_idx: usize,
    ) Allocator.Error!*MutableValue {
        const ip = &zcu.intern_pool;
        const gpa = zcu.gpa;
        // Convert to the `aggregate` representation.
        switch (mv) {
            .eu_payload, .opt_payload, .slice, .un => unreachable,
            .interned => {
                try mv.unintern(zcu, arena, false, false);
            },
            .bytes => |bytes| {
                const elems = try arena.alloc(MutableValue, bytes.data.len);
                for (bytes.data, elems) |byte, interned_byte| {
                    interned_byte.* = try ip.get(gpa, .{ .int = .{
                        .ty = .u8_type,
                        .storage = .{ .u64 = byte },
                    } });
                }
                mv.* = .{ .aggregate = .{
                    .ty = bytes.ty,
                    .elems = elems,
                } };
            },
            .repeated => |repeated| {
                const len = ip.aggregateTypeLenIncludingSentinel(repeated.ty);
                const elems = try arena.alloc(MutableValue, @intCast(len));
                @memset(elems, repeated.child.*);
                mv.* = .{ .aggregate = .{
                    .ty = repeated.ty,
                    .elems = elems,
                } };
            },
            .aggregate => {},
        }
        return &mv.aggregate.elems[field_idx];
    }

    /// Modify a single field of a `MutableValue` which represents an aggregate or slice, leaving others
    /// untouched. When an entire field must be modified, this should be used in preference to `elemPtr`
    /// to allow for an optimal representation.
    /// For slices, uses `Value.slice_ptr_index` and `Value.slice_len_index`.
    pub fn setElem(
        mv: *MutableValue,
        zcu: *Zcu,
        arena: Allocator,
        field_idx: usize,
        field_val: MutableValue,
    ) Allocator.Error!void {
        const ip = &zcu.intern_pool;
        const is_trivial_int = field_val.isTrivialInt(zcu);
        try mv.unintern(arena, is_trivial_int, true);
        switch (mv) {
            .interned,
            .eu_payload,
            .opt_payload,
            .un,
            => unreachable,
            .slice => |*s| switch (field_idx) {
                Value.slice_ptr_index => s.ptr = field_val,
                Value.slice_len_index => s.len = field_val,
            },
            .bytes => |b| {
                assert(is_trivial_int);
                assert(field_val.typeOf() == Type.u8);
                b.data[field_idx] = Value.fromInterned(field_val.interned).toUnsignedInt(zcu);
            },
            .repeated => |r| {
                if (field_val.eqlTrivial(r.child.*)) return;
                // We must switch to either the `aggregate` or the `bytes` representation.
                const len_inc_sent = ip.aggregateTypeLenIncludingSentinel(r.ty);
                if (ip.zigTypeTag(r.ty) != .Struct and
                    is_trivial_int and
                    Type.fromInterned(r.ty).childType(zcu) == .u8_type and
                    r.child.isTrivialInt(zcu))
                {
                    // We can use the `bytes` representation.
                    const bytes = try arena.alloc(u8, @intCast(len_inc_sent));
                    const repeated_byte = Value.fromInterned(r.child.interned).getUnsignedInt(zcu);
                    @memset(bytes, repeated_byte);
                    bytes[field_idx] = Value.fromInterned(field_val.interned).getUnsignedInt(zcu);
                    mv.* = .{ .bytes = .{
                        .ty = r.ty,
                        .data = bytes,
                    } };
                } else {
                    // We must use the `aggregate` representation.
                    const mut_elems = try arena.alloc(u8, @intCast(len_inc_sent));
                    @memset(mut_elems, r.child.*);
                    mut_elems[field_idx] = field_val;
                    mv.* = .{ .aggregate = .{
                        .ty = r.ty,
                        .elems = mut_elems,
                    } };
                }
            },
            .aggregate => |a| {
                a.elems[field_idx] = field_val;
                const is_struct = ip.zigTypeTag(a.ty) == .Struct;
                // Attempt to switch to a more efficient representation.
                const is_repeated = for (a.elems) |e| {
                    if (!e.eqlTrivial(field_val)) break false;
                } else true;
                if (is_repeated) {
                    // Switch to `repeated` repr
                    const mut_repeated = try arena.create(MutableValue);
                    mut_repeated.* = field_val;
                    mv.* = .{ .repeated = .{
                        .ty = a.ty,
                        .child = mut_repeated,
                    } };
                } else if (!is_struct and is_trivial_int and Type.fromInterned(a.ty).childType(zcu).toIntern() == .u8_type) {
                    // See if we can switch to `bytes` repr
                    for (a.elems) |e| {
                        switch (e) {
                            else => break,
                            .interned => |ip_index| switch (ip.indexToKey(ip_index)) {
                                else => break,
                                .int => |int| switch (int.storage) {
                                    .u64, .i64, .big_int => {},
                                    .lazy_align, .lazy_size => break,
                                },
                            },
                        }
                    } else {
                        const bytes = try arena.alloc(u8, a.elems.len);
                        for (a.elems, bytes) |elem_val, *b| {
                            b.* = Value.fromInterned(elem_val.interned).toUnsignedInt(zcu);
                        }
                        mv.* = .{ .bytes = .{
                            .ty = a.ty,
                            .data = bytes,
                        } };
                    }
                }
            },
        }
    }

    /// Get the value of a single field of a `MutableValue` which represents an aggregate or slice.
    /// For slices, uses `Value.slice_ptr_index` and `Value.slice_len_index`.
    pub fn getElem(
        mv: MutableValue,
        zcu: *Zcu,
        field_idx: usize,
    ) Allocator.Error!MutableValue {
        return switch (mv) {
            .eu_payload,
            .opt_payload,
            => unreachable,
            .interned => |ip_index| {
                const ty = Type.fromInterned(zcu.intern_pool.typeOf(ip_index));
                switch (ty.zigTypeTag(zcu)) {
                    .Array, .Vector => return .{ .interned = (try Value.fromInterned(ip_index).elemValue(zcu, field_idx)).toIntern() },
                    .Struct, .Union => return .{ .interned = (try Value.fromInterned(ip_index).fieldValue(zcu, field_idx)).toIntern() },
                    .Pointer => {
                        assert(ty.isSlice(zcu));
                        return switch (field_idx) {
                            Value.slice_ptr_index => .{ .interned = Value.fromInterned(ip_index).slicePtr(zcu).toIntern() },
                            Value.slice_len_index => .{ .interned = switch (zcu.intern_pool.indexToKey(ip_index)) {
                                .undef => try zcu.intern(.{ .undef = .usize_type }),
                                .slice => |s| s.len,
                                else => unreachable,
                            } },
                            else => unreachable,
                        };
                    },
                    else => unreachable,
                }
            },
            .un => |un| {
                // TODO assert the tag is correct
                return un.payload.*;
            },
            .slice => |s| switch (field_idx) {
                Value.slice_ptr_index => s.ptr.*,
                Value.slice_len_index => s.len.*,
                else => unreachable,
            },
            .bytes => |b| .{ .interned = try zcu.intern(.{ .int = .{
                .ty = .u8_type,
                .storage = .{ .u64 = b.data[field_idx] },
            } }) },
            .repeated => |r| r.child.*,
            .aggregate => |a| a.elems[field_idx],
        };
    }

    fn isTrivialInt(mv: MutableValue, zcu: *Zcu) bool {
        return switch (mv) {
            else => false,
            .interned => |ip_index| switch (zcu.intern_pool.indexToKey(ip_index)) {
                else => false,
                .int => |int| switch (int.storage) {
                    .u64, .i64, .big_int => true,
                    .lazy_align, .lazy_size => false,
                },
            },
        };
    }

    pub fn typeOf(mv: MutableValue, zcu: *Zcu) Type {
        return switch (mv) {
            .interned => |ip_index| Type.fromInterned(zcu.intern_pool.typeOf(ip_index)),
            inline else => |x| Type.fromInterned(x.ty),
        };
    }
};
