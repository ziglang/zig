const std = @import("std");
const Value = @import("value.zig").Value;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Target = std.Target;
const Module = @import("Module.zig");
const log = std.log.scoped(.Type);
const target_util = @import("target.zig");
const TypedValue = @import("TypedValue.zig");

const file_struct = @This();

/// This is the raw data, with no bookkeeping, no memory awareness, no de-duplication.
/// It's important for this type to be small.
/// Types are not de-duplicated, which helps with multi-threading since it obviates the requirement
/// of obtaining a lock on a global type table, as well as making the
/// garbage collection bookkeeping simpler.
/// This union takes advantage of the fact that the first page of memory
/// is unmapped, giving us 4096 possible enum tags that have no payload.
pub const Type = extern union {
    /// If the tag value is less than Tag.no_payload_count, then no pointer
    /// dereference is needed.
    tag_if_small_enough: Tag,
    ptr_otherwise: *Payload,

    pub fn zigTypeTag(ty: Type) std.builtin.TypeId {
        return ty.zigTypeTagOrPoison() catch unreachable;
    }

    pub fn zigTypeTagOrPoison(ty: Type) error{GenericPoison}!std.builtin.TypeId {
        switch (ty.tag()) {
            .generic_poison => return error.GenericPoison,

            .u1,
            .u8,
            .i8,
            .u16,
            .i16,
            .u29,
            .u32,
            .i32,
            .u64,
            .i64,
            .u128,
            .i128,
            .usize,
            .isize,
            .c_short,
            .c_ushort,
            .c_int,
            .c_uint,
            .c_long,
            .c_ulong,
            .c_longlong,
            .c_ulonglong,
            .int_signed,
            .int_unsigned,
            => return .Int,

            .f16,
            .f32,
            .f64,
            .f80,
            .f128,
            .c_longdouble,
            => return .Float,

            .error_set,
            .error_set_single,
            .anyerror,
            .error_set_inferred,
            .error_set_merged,
            => return .ErrorSet,

            .anyopaque, .@"opaque" => return .Opaque,
            .bool => return .Bool,
            .void => return .Void,
            .type => return .Type,
            .comptime_int => return .ComptimeInt,
            .comptime_float => return .ComptimeFloat,
            .noreturn => return .NoReturn,
            .@"null" => return .Null,
            .@"undefined" => return .Undefined,

            .fn_noreturn_no_args => return .Fn,
            .fn_void_no_args => return .Fn,
            .fn_naked_noreturn_no_args => return .Fn,
            .fn_ccc_void_no_args => return .Fn,
            .function => return .Fn,

            .array,
            .array_u8_sentinel_0,
            .array_u8,
            .array_sentinel,
            => return .Array,

            .vector => return .Vector,

            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            .const_slice_u8_sentinel_0,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            .pointer,
            .inferred_alloc_const,
            .inferred_alloc_mut,
            .manyptr_u8,
            .manyptr_const_u8,
            .manyptr_const_u8_sentinel_0,
            => return .Pointer,

            .optional,
            .optional_single_const_pointer,
            .optional_single_mut_pointer,
            => return .Optional,
            .enum_literal => return .EnumLiteral,

            .anyerror_void_error_union, .error_union => return .ErrorUnion,

            .anyframe_T, .@"anyframe" => return .AnyFrame,

            .empty_struct,
            .empty_struct_literal,
            .@"struct",
            .call_options,
            .prefetch_options,
            .export_options,
            .extern_options,
            .tuple,
            .anon_struct,
            => return .Struct,

            .enum_full,
            .enum_nonexhaustive,
            .enum_simple,
            .enum_numbered,
            .atomic_order,
            .atomic_rmw_op,
            .calling_convention,
            .address_space,
            .float_mode,
            .reduce_op,
            => return .Enum,

            .@"union",
            .union_tagged,
            .type_info,
            => return .Union,

            .bound_fn => unreachable,
            .var_args_param => unreachable, // can be any type
        }
    }

    pub fn isSelfComparable(ty: Type, is_equality_cmp: bool) bool {
        return switch (ty.zigTypeTag()) {
            .Int,
            .Float,
            .ComptimeFloat,
            .ComptimeInt,
            .Vector, // TODO some vectors require is_equality_cmp==true
            => true,

            .Bool,
            .Type,
            .Void,
            .ErrorSet,
            .Fn,
            .BoundFn,
            .Opaque,
            .AnyFrame,
            .Enum,
            .EnumLiteral,
            => is_equality_cmp,

            .NoReturn,
            .Array,
            .Struct,
            .Undefined,
            .Null,
            .ErrorUnion,
            .Union,
            .Frame,
            => false,

            .Pointer => !ty.isSlice() and (is_equality_cmp or ty.isCPtr()),
            .Optional => {
                if (!is_equality_cmp) return false;
                var buf: Payload.ElemType = undefined;
                return ty.optionalChild(&buf).isSelfComparable(is_equality_cmp);
            },
        };
    }

    pub fn initTag(comptime small_tag: Tag) Type {
        comptime assert(@enumToInt(small_tag) < Tag.no_payload_count);
        return .{ .tag_if_small_enough = small_tag };
    }

    pub fn initPayload(payload: *Payload) Type {
        assert(@enumToInt(payload.tag) >= Tag.no_payload_count);
        return .{ .ptr_otherwise = payload };
    }

    pub fn tag(self: Type) Tag {
        if (@enumToInt(self.tag_if_small_enough) < Tag.no_payload_count) {
            return self.tag_if_small_enough;
        } else {
            return self.ptr_otherwise.tag;
        }
    }

    /// Prefer `castTag` to this.
    pub fn cast(self: Type, comptime T: type) ?*T {
        if (@hasField(T, "base_tag")) {
            return self.castTag(T.base_tag);
        }
        if (@enumToInt(self.tag_if_small_enough) < Tag.no_payload_count) {
            return null;
        }
        inline for (@typeInfo(Tag).Enum.fields) |field| {
            if (field.value < Tag.no_payload_count)
                continue;
            const t = @intToEnum(Tag, field.value);
            if (self.ptr_otherwise.tag == t) {
                if (T == t.Type()) {
                    return @fieldParentPtr(T, "base", self.ptr_otherwise);
                }
                return null;
            }
        }
        unreachable;
    }

    pub fn castTag(self: Type, comptime t: Tag) ?*t.Type() {
        if (@enumToInt(self.tag_if_small_enough) < Tag.no_payload_count)
            return null;

        if (self.ptr_otherwise.tag == t)
            return @fieldParentPtr(t.Type(), "base", self.ptr_otherwise);

        return null;
    }

    pub fn castPointer(self: Type) ?*Payload.ElemType {
        return switch (self.tag()) {
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            .optional_single_const_pointer,
            .optional_single_mut_pointer,
            .manyptr_u8,
            .manyptr_const_u8,
            .manyptr_const_u8_sentinel_0,
            => self.cast(Payload.ElemType),

            .inferred_alloc_const => unreachable,
            .inferred_alloc_mut => unreachable,

            else => null,
        };
    }

    /// If it is a function pointer, returns the function type. Otherwise returns null.
    pub fn castPtrToFn(ty: Type) ?Type {
        if (ty.zigTypeTag() != .Pointer) return null;
        const elem_ty = ty.childType();
        if (elem_ty.zigTypeTag() != .Fn) return null;
        return elem_ty;
    }

    pub fn ptrIsMutable(ty: Type) bool {
        return switch (ty.tag()) {
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            .const_slice_u8_sentinel_0,
            .single_const_pointer,
            .many_const_pointer,
            .manyptr_const_u8,
            .manyptr_const_u8_sentinel_0,
            .c_const_pointer,
            .const_slice,
            => false,

            .single_mut_pointer,
            .many_mut_pointer,
            .manyptr_u8,
            .c_mut_pointer,
            .mut_slice,
            => true,

            .pointer => ty.castTag(.pointer).?.data.mutable,

            else => unreachable,
        };
    }

    pub const ArrayInfo = struct { elem_type: Type, sentinel: ?Value = null, len: u64 };
    pub fn arrayInfo(self: Type) ArrayInfo {
        return .{
            .len = self.arrayLen(),
            .sentinel = self.sentinel(),
            .elem_type = self.elemType(),
        };
    }

    pub fn ptrInfo(self: Type) Payload.Pointer {
        switch (self.tag()) {
            .single_const_pointer_to_comptime_int => return .{ .data = .{
                .pointee_type = Type.initTag(.comptime_int),
                .sentinel = null,
                .@"align" = 0,
                .@"addrspace" = .generic,
                .bit_offset = 0,
                .host_size = 0,
                .@"allowzero" = false,
                .mutable = false,
                .@"volatile" = false,
                .size = .One,
            } },
            .const_slice_u8 => return .{ .data = .{
                .pointee_type = Type.initTag(.u8),
                .sentinel = null,
                .@"align" = 0,
                .@"addrspace" = .generic,
                .bit_offset = 0,
                .host_size = 0,
                .@"allowzero" = false,
                .mutable = false,
                .@"volatile" = false,
                .size = .Slice,
            } },
            .const_slice_u8_sentinel_0 => return .{ .data = .{
                .pointee_type = Type.initTag(.u8),
                .sentinel = Value.zero,
                .@"align" = 0,
                .@"addrspace" = .generic,
                .bit_offset = 0,
                .host_size = 0,
                .@"allowzero" = false,
                .mutable = false,
                .@"volatile" = false,
                .size = .Slice,
            } },
            .single_const_pointer => return .{ .data = .{
                .pointee_type = self.castPointer().?.data,
                .sentinel = null,
                .@"align" = 0,
                .@"addrspace" = .generic,
                .bit_offset = 0,
                .host_size = 0,
                .@"allowzero" = false,
                .mutable = false,
                .@"volatile" = false,
                .size = .One,
            } },
            .single_mut_pointer => return .{ .data = .{
                .pointee_type = self.castPointer().?.data,
                .sentinel = null,
                .@"align" = 0,
                .@"addrspace" = .generic,
                .bit_offset = 0,
                .host_size = 0,
                .@"allowzero" = false,
                .mutable = true,
                .@"volatile" = false,
                .size = .One,
            } },
            .many_const_pointer => return .{ .data = .{
                .pointee_type = self.castPointer().?.data,
                .sentinel = null,
                .@"align" = 0,
                .@"addrspace" = .generic,
                .bit_offset = 0,
                .host_size = 0,
                .@"allowzero" = false,
                .mutable = false,
                .@"volatile" = false,
                .size = .Many,
            } },
            .manyptr_const_u8 => return .{ .data = .{
                .pointee_type = Type.initTag(.u8),
                .sentinel = null,
                .@"align" = 0,
                .@"addrspace" = .generic,
                .bit_offset = 0,
                .host_size = 0,
                .@"allowzero" = false,
                .mutable = false,
                .@"volatile" = false,
                .size = .Many,
            } },
            .manyptr_const_u8_sentinel_0 => return .{ .data = .{
                .pointee_type = Type.initTag(.u8),
                .sentinel = Value.zero,
                .@"align" = 0,
                .@"addrspace" = .generic,
                .bit_offset = 0,
                .host_size = 0,
                .@"allowzero" = false,
                .mutable = false,
                .@"volatile" = false,
                .size = .Many,
            } },
            .many_mut_pointer => return .{ .data = .{
                .pointee_type = self.castPointer().?.data,
                .sentinel = null,
                .@"align" = 0,
                .@"addrspace" = .generic,
                .bit_offset = 0,
                .host_size = 0,
                .@"allowzero" = false,
                .mutable = true,
                .@"volatile" = false,
                .size = .Many,
            } },
            .manyptr_u8 => return .{ .data = .{
                .pointee_type = Type.initTag(.u8),
                .sentinel = null,
                .@"align" = 0,
                .@"addrspace" = .generic,
                .bit_offset = 0,
                .host_size = 0,
                .@"allowzero" = false,
                .mutable = true,
                .@"volatile" = false,
                .size = .Many,
            } },
            .c_const_pointer => return .{ .data = .{
                .pointee_type = self.castPointer().?.data,
                .sentinel = null,
                .@"align" = 0,
                .@"addrspace" = .generic,
                .bit_offset = 0,
                .host_size = 0,
                .@"allowzero" = true,
                .mutable = false,
                .@"volatile" = false,
                .size = .C,
            } },
            .c_mut_pointer => return .{ .data = .{
                .pointee_type = self.castPointer().?.data,
                .sentinel = null,
                .@"align" = 0,
                .@"addrspace" = .generic,
                .bit_offset = 0,
                .host_size = 0,
                .@"allowzero" = true,
                .mutable = true,
                .@"volatile" = false,
                .size = .C,
            } },
            .const_slice => return .{ .data = .{
                .pointee_type = self.castPointer().?.data,
                .sentinel = null,
                .@"align" = 0,
                .@"addrspace" = .generic,
                .bit_offset = 0,
                .host_size = 0,
                .@"allowzero" = false,
                .mutable = false,
                .@"volatile" = false,
                .size = .Slice,
            } },
            .mut_slice => return .{ .data = .{
                .pointee_type = self.castPointer().?.data,
                .sentinel = null,
                .@"align" = 0,
                .@"addrspace" = .generic,
                .bit_offset = 0,
                .host_size = 0,
                .@"allowzero" = false,
                .mutable = true,
                .@"volatile" = false,
                .size = .Slice,
            } },

            .pointer => return self.castTag(.pointer).?.*,

            .optional_single_mut_pointer => return .{ .data = .{
                .pointee_type = self.castPointer().?.data,
                .sentinel = null,
                .@"align" = 0,
                .@"addrspace" = .generic,
                .bit_offset = 0,
                .host_size = 0,
                .@"allowzero" = false,
                .mutable = true,
                .@"volatile" = false,
                .size = .One,
            } },
            .optional_single_const_pointer => return .{ .data = .{
                .pointee_type = self.castPointer().?.data,
                .sentinel = null,
                .@"align" = 0,
                .@"addrspace" = .generic,
                .bit_offset = 0,
                .host_size = 0,
                .@"allowzero" = false,
                .mutable = false,
                .@"volatile" = false,
                .size = .One,
            } },
            .optional => {
                var buf: Payload.ElemType = undefined;
                const child_type = self.optionalChild(&buf);
                return child_type.ptrInfo();
            },

            else => unreachable,
        }
    }

    pub fn eql(a: Type, b: Type, mod: *Module) bool {
        // As a shortcut, if the small tags / addresses match, we're done.
        if (a.tag_if_small_enough == b.tag_if_small_enough) return true;

        switch (a.tag()) {
            .generic_poison => unreachable,

            // Detect that e.g. u64 != usize, even if the bits match on a particular target.
            .usize,
            .isize,
            .c_short,
            .c_ushort,
            .c_int,
            .c_uint,
            .c_long,
            .c_ulong,
            .c_longlong,
            .c_ulonglong,

            .f16,
            .f32,
            .f64,
            .f80,
            .f128,
            .c_longdouble,

            .bool,
            .void,
            .type,
            .comptime_int,
            .comptime_float,
            .noreturn,
            .@"null",
            .@"undefined",
            .@"anyopaque",
            .@"anyframe",
            .enum_literal,
            => |a_tag| {
                assert(a_tag != b.tag()); // because of the comparison at the top of the function.
                return false;
            },

            .u1,
            .u8,
            .i8,
            .u16,
            .i16,
            .u29,
            .u32,
            .i32,
            .u64,
            .i64,
            .u128,
            .i128,
            .int_signed,
            .int_unsigned,
            => {
                if (b.zigTypeTag() != .Int) return false;
                if (b.isNamedInt()) return false;

                // Arbitrary sized integers. The target will not be branched upon,
                // because we handled target-dependent cases above.
                const info_a = a.intInfo(@as(Target, undefined));
                const info_b = b.intInfo(@as(Target, undefined));
                return info_a.signedness == info_b.signedness and info_a.bits == info_b.bits;
            },

            .error_set_inferred => {
                // Inferred error sets are only equal if both are inferred
                // and they share the same pointer.
                const a_ies = a.castTag(.error_set_inferred).?.data;
                const b_ies = (b.castTag(.error_set_inferred) orelse return false).data;
                return a_ies == b_ies;
            },

            .anyerror => {
                return b.tag() == .anyerror;
            },

            .error_set,
            .error_set_single,
            .error_set_merged,
            => {
                switch (b.tag()) {
                    .error_set, .error_set_single, .error_set_merged => {},
                    else => return false,
                }

                // Two resolved sets match if their error set names match.
                // Since they are pre-sorted we compare them element-wise.
                const a_set = a.errorSetNames();
                const b_set = b.errorSetNames();
                if (a_set.len != b_set.len) return false;
                for (a_set) |a_item, i| {
                    const b_item = b_set[i];
                    if (!std.mem.eql(u8, a_item, b_item)) return false;
                }
                return true;
            },

            .@"opaque" => {
                const opaque_obj_a = a.castTag(.@"opaque").?.data;
                const opaque_obj_b = (b.castTag(.@"opaque") orelse return false).data;
                return opaque_obj_a == opaque_obj_b;
            },

            .fn_noreturn_no_args,
            .fn_void_no_args,
            .fn_naked_noreturn_no_args,
            .fn_ccc_void_no_args,
            .function,
            => {
                if (b.zigTypeTag() != .Fn) return false;

                const a_info = a.fnInfo();
                const b_info = b.fnInfo();

                if (!eql(a_info.return_type, b_info.return_type, mod))
                    return false;

                if (a_info.is_var_args != b_info.is_var_args)
                    return false;

                if (a_info.is_generic != b_info.is_generic)
                    return false;

                if (a_info.noalias_bits != b_info.noalias_bits)
                    return false;

                if (!a_info.cc_is_generic and a_info.cc != b_info.cc)
                    return false;

                if (!a_info.align_is_generic and a_info.alignment != b_info.alignment)
                    return false;

                if (a_info.param_types.len != b_info.param_types.len)
                    return false;

                for (a_info.param_types) |a_param_ty, i| {
                    const b_param_ty = b_info.param_types[i];
                    if (a_info.comptime_params[i] != b_info.comptime_params[i])
                        return false;

                    if (a_param_ty.tag() == .generic_poison) continue;
                    if (b_param_ty.tag() == .generic_poison) continue;

                    if (!eql(a_param_ty, b_param_ty, mod))
                        return false;
                }

                return true;
            },

            .array,
            .array_u8_sentinel_0,
            .array_u8,
            .array_sentinel,
            .vector,
            => {
                if (a.zigTypeTag() != b.zigTypeTag()) return false;

                if (a.arrayLen() != b.arrayLen())
                    return false;
                const elem_ty = a.elemType();
                if (!elem_ty.eql(b.elemType(), mod))
                    return false;
                const sentinel_a = a.sentinel();
                const sentinel_b = b.sentinel();
                if (sentinel_a) |sa| {
                    if (sentinel_b) |sb| {
                        return sa.eql(sb, elem_ty, mod);
                    } else {
                        return false;
                    }
                } else {
                    return sentinel_b == null;
                }
            },

            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            .const_slice_u8_sentinel_0,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            .pointer,
            .inferred_alloc_const,
            .inferred_alloc_mut,
            .manyptr_u8,
            .manyptr_const_u8,
            .manyptr_const_u8_sentinel_0,
            => {
                if (b.zigTypeTag() != .Pointer) return false;

                const info_a = a.ptrInfo().data;
                const info_b = b.ptrInfo().data;
                if (!info_a.pointee_type.eql(info_b.pointee_type, mod))
                    return false;
                if (info_a.@"align" != info_b.@"align")
                    return false;
                if (info_a.@"addrspace" != info_b.@"addrspace")
                    return false;
                if (info_a.bit_offset != info_b.bit_offset)
                    return false;
                if (info_a.host_size != info_b.host_size)
                    return false;
                if (info_a.@"allowzero" != info_b.@"allowzero")
                    return false;
                if (info_a.mutable != info_b.mutable)
                    return false;
                if (info_a.@"volatile" != info_b.@"volatile")
                    return false;
                if (info_a.size != info_b.size)
                    return false;

                const sentinel_a = info_a.sentinel;
                const sentinel_b = info_b.sentinel;
                if (sentinel_a) |sa| {
                    if (sentinel_b) |sb| {
                        if (!sa.eql(sb, info_a.pointee_type, mod))
                            return false;
                    } else {
                        return false;
                    }
                } else {
                    if (sentinel_b != null)
                        return false;
                }

                return true;
            },

            .optional,
            .optional_single_const_pointer,
            .optional_single_mut_pointer,
            => {
                if (b.zigTypeTag() != .Optional) return false;

                var buf_a: Payload.ElemType = undefined;
                var buf_b: Payload.ElemType = undefined;
                return a.optionalChild(&buf_a).eql(b.optionalChild(&buf_b), mod);
            },

            .anyerror_void_error_union, .error_union => {
                if (b.zigTypeTag() != .ErrorUnion) return false;

                const a_set = a.errorUnionSet();
                const b_set = b.errorUnionSet();
                if (!a_set.eql(b_set, mod)) return false;

                const a_payload = a.errorUnionPayload();
                const b_payload = b.errorUnionPayload();
                if (!a_payload.eql(b_payload, mod)) return false;

                return true;
            },

            .anyframe_T => {
                if (b.zigTypeTag() != .AnyFrame) return false;
                return a.elemType2().eql(b.elemType2(), mod);
            },

            .empty_struct => {
                const a_namespace = a.castTag(.empty_struct).?.data;
                const b_namespace = (b.castTag(.empty_struct) orelse return false).data;
                return a_namespace == b_namespace;
            },
            .@"struct" => {
                const a_struct_obj = a.castTag(.@"struct").?.data;
                const b_struct_obj = (b.castTag(.@"struct") orelse return false).data;
                return a_struct_obj == b_struct_obj;
            },
            .tuple, .empty_struct_literal => {
                if (!b.isTuple()) return false;

                const a_tuple = a.tupleFields();
                const b_tuple = b.tupleFields();

                if (a_tuple.types.len != b_tuple.types.len) return false;

                for (a_tuple.types) |a_ty, i| {
                    const b_ty = b_tuple.types[i];
                    if (!eql(a_ty, b_ty, mod)) return false;
                }

                for (a_tuple.values) |a_val, i| {
                    const ty = a_tuple.types[i];
                    const b_val = b_tuple.values[i];
                    if (a_val.tag() == .unreachable_value) {
                        if (b_val.tag() == .unreachable_value) {
                            continue;
                        } else {
                            return false;
                        }
                    } else {
                        if (b_val.tag() == .unreachable_value) {
                            return false;
                        } else {
                            if (!Value.eql(a_val, b_val, ty, mod)) return false;
                        }
                    }
                }

                return true;
            },
            .anon_struct => {
                const a_struct_obj = a.castTag(.anon_struct).?.data;
                const b_struct_obj = (b.castTag(.anon_struct) orelse return false).data;

                if (a_struct_obj.types.len != b_struct_obj.types.len) return false;

                for (a_struct_obj.names) |a_name, i| {
                    const b_name = b_struct_obj.names[i];
                    if (!std.mem.eql(u8, a_name, b_name)) return false;
                }

                for (a_struct_obj.types) |a_ty, i| {
                    const b_ty = b_struct_obj.types[i];
                    if (!eql(a_ty, b_ty, mod)) return false;
                }

                for (a_struct_obj.values) |a_val, i| {
                    const ty = a_struct_obj.types[i];
                    const b_val = b_struct_obj.values[i];
                    if (a_val.tag() == .unreachable_value) {
                        if (b_val.tag() == .unreachable_value) {
                            continue;
                        } else {
                            return false;
                        }
                    } else {
                        if (b_val.tag() == .unreachable_value) {
                            return false;
                        } else {
                            if (!Value.eql(a_val, b_val, ty, mod)) return false;
                        }
                    }
                }

                return true;
            },

            // we can't compare these based on tags because it wouldn't detect if,
            // for example, a was resolved into .@"struct" but b was one of these tags.
            .call_options,
            .prefetch_options,
            .export_options,
            .extern_options,
            => unreachable, // needed to resolve the type before now

            .enum_full, .enum_nonexhaustive => {
                const a_enum_obj = a.cast(Payload.EnumFull).?.data;
                const b_enum_obj = (b.cast(Payload.EnumFull) orelse return false).data;
                return a_enum_obj == b_enum_obj;
            },
            .enum_simple => {
                const a_enum_obj = a.cast(Payload.EnumSimple).?.data;
                const b_enum_obj = (b.cast(Payload.EnumSimple) orelse return false).data;
                return a_enum_obj == b_enum_obj;
            },
            .enum_numbered => {
                const a_enum_obj = a.cast(Payload.EnumNumbered).?.data;
                const b_enum_obj = (b.cast(Payload.EnumNumbered) orelse return false).data;
                return a_enum_obj == b_enum_obj;
            },
            // we can't compare these based on tags because it wouldn't detect if,
            // for example, a was resolved into .enum_simple but b was one of these tags.
            .atomic_order,
            .atomic_rmw_op,
            .calling_convention,
            .address_space,
            .float_mode,
            .reduce_op,
            => unreachable, // needed to resolve the type before now

            .@"union", .union_tagged => {
                const a_union_obj = a.cast(Payload.Union).?.data;
                const b_union_obj = (b.cast(Payload.Union) orelse return false).data;
                return a_union_obj == b_union_obj;
            },
            // we can't compare these based on tags because it wouldn't detect if,
            // for example, a was resolved into .union_tagged but b was one of these tags.
            .type_info => unreachable, // needed to resolve the type before now

            .bound_fn => unreachable,
            .var_args_param => unreachable, // can be any type
        }
    }

    pub fn hash(self: Type, mod: *Module) u64 {
        var hasher = std.hash.Wyhash.init(0);
        self.hashWithHasher(&hasher, mod);
        return hasher.final();
    }

    pub fn hashWithHasher(ty: Type, hasher: *std.hash.Wyhash, mod: *Module) void {
        switch (ty.tag()) {
            .generic_poison => unreachable,

            .usize,
            .isize,
            .c_short,
            .c_ushort,
            .c_int,
            .c_uint,
            .c_long,
            .c_ulong,
            .c_longlong,
            .c_ulonglong,
            => |ty_tag| {
                std.hash.autoHash(hasher, std.builtin.TypeId.Int);
                std.hash.autoHash(hasher, ty_tag);
            },

            .f16,
            .f32,
            .f64,
            .f80,
            .f128,
            .c_longdouble,
            => |ty_tag| {
                std.hash.autoHash(hasher, std.builtin.TypeId.Float);
                std.hash.autoHash(hasher, ty_tag);
            },

            .bool => std.hash.autoHash(hasher, std.builtin.TypeId.Bool),
            .void => std.hash.autoHash(hasher, std.builtin.TypeId.Void),
            .type => std.hash.autoHash(hasher, std.builtin.TypeId.Type),
            .comptime_int => std.hash.autoHash(hasher, std.builtin.TypeId.ComptimeInt),
            .comptime_float => std.hash.autoHash(hasher, std.builtin.TypeId.ComptimeFloat),
            .noreturn => std.hash.autoHash(hasher, std.builtin.TypeId.NoReturn),
            .@"null" => std.hash.autoHash(hasher, std.builtin.TypeId.Null),
            .@"undefined" => std.hash.autoHash(hasher, std.builtin.TypeId.Undefined),

            .@"anyopaque" => {
                std.hash.autoHash(hasher, std.builtin.TypeId.Opaque);
                std.hash.autoHash(hasher, Tag.@"anyopaque");
            },

            .@"anyframe" => {
                std.hash.autoHash(hasher, std.builtin.TypeId.AnyFrame);
                std.hash.autoHash(hasher, Tag.@"anyframe");
            },

            .enum_literal => {
                std.hash.autoHash(hasher, std.builtin.TypeId.EnumLiteral);
                std.hash.autoHash(hasher, Tag.enum_literal);
            },

            .u1,
            .u8,
            .i8,
            .u16,
            .i16,
            .u29,
            .u32,
            .i32,
            .u64,
            .i64,
            .u128,
            .i128,
            .int_signed,
            .int_unsigned,
            => {
                // Arbitrary sized integers. The target will not be branched upon,
                // because we handled target-dependent cases above.
                std.hash.autoHash(hasher, std.builtin.TypeId.Int);
                const info = ty.intInfo(@as(Target, undefined));
                std.hash.autoHash(hasher, info.signedness);
                std.hash.autoHash(hasher, info.bits);
            },

            .error_set,
            .error_set_single,
            .error_set_merged,
            => {
                // all are treated like an "error set" for hashing
                std.hash.autoHash(hasher, std.builtin.TypeId.ErrorSet);
                std.hash.autoHash(hasher, Tag.error_set);

                const names = ty.errorSetNames();
                std.hash.autoHash(hasher, names.len);
                assert(std.sort.isSorted([]const u8, names, u8, std.mem.lessThan));
                for (names) |name| hasher.update(name);
            },

            .anyerror => {
                // anyerror is distinct from other error sets
                std.hash.autoHash(hasher, std.builtin.TypeId.ErrorSet);
                std.hash.autoHash(hasher, Tag.anyerror);
            },

            .error_set_inferred => {
                // inferred error sets are compared using their data pointer
                const ies: *Module.Fn.InferredErrorSet = ty.castTag(.error_set_inferred).?.data;
                std.hash.autoHash(hasher, std.builtin.TypeId.ErrorSet);
                std.hash.autoHash(hasher, Tag.error_set_inferred);
                std.hash.autoHash(hasher, ies);
            },

            .@"opaque" => {
                std.hash.autoHash(hasher, std.builtin.TypeId.Opaque);
                const opaque_obj = ty.castTag(.@"opaque").?.data;
                std.hash.autoHash(hasher, opaque_obj);
            },

            .fn_noreturn_no_args,
            .fn_void_no_args,
            .fn_naked_noreturn_no_args,
            .fn_ccc_void_no_args,
            .function,
            => {
                std.hash.autoHash(hasher, std.builtin.TypeId.Fn);

                const fn_info = ty.fnInfo();
                if (fn_info.return_type.tag() != .generic_poison) {
                    hashWithHasher(fn_info.return_type, hasher, mod);
                }
                if (!fn_info.align_is_generic) {
                    std.hash.autoHash(hasher, fn_info.alignment);
                }
                if (!fn_info.cc_is_generic) {
                    std.hash.autoHash(hasher, fn_info.cc);
                }
                std.hash.autoHash(hasher, fn_info.is_var_args);
                std.hash.autoHash(hasher, fn_info.is_generic);
                std.hash.autoHash(hasher, fn_info.noalias_bits);

                std.hash.autoHash(hasher, fn_info.param_types.len);
                for (fn_info.param_types) |param_ty, i| {
                    std.hash.autoHash(hasher, fn_info.paramIsComptime(i));
                    if (param_ty.tag() == .generic_poison) continue;
                    hashWithHasher(param_ty, hasher, mod);
                }
            },

            .array,
            .array_u8_sentinel_0,
            .array_u8,
            .array_sentinel,
            => {
                std.hash.autoHash(hasher, std.builtin.TypeId.Array);

                const elem_ty = ty.elemType();
                std.hash.autoHash(hasher, ty.arrayLen());
                hashWithHasher(elem_ty, hasher, mod);
                hashSentinel(ty.sentinel(), elem_ty, hasher, mod);
            },

            .vector => {
                std.hash.autoHash(hasher, std.builtin.TypeId.Vector);

                const elem_ty = ty.elemType();
                std.hash.autoHash(hasher, ty.vectorLen());
                hashWithHasher(elem_ty, hasher, mod);
            },

            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            .const_slice_u8_sentinel_0,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            .pointer,
            .inferred_alloc_const,
            .inferred_alloc_mut,
            .manyptr_u8,
            .manyptr_const_u8,
            .manyptr_const_u8_sentinel_0,
            => {
                std.hash.autoHash(hasher, std.builtin.TypeId.Pointer);

                const info = ty.ptrInfo().data;
                hashWithHasher(info.pointee_type, hasher, mod);
                hashSentinel(info.sentinel, info.pointee_type, hasher, mod);
                std.hash.autoHash(hasher, info.@"align");
                std.hash.autoHash(hasher, info.@"addrspace");
                std.hash.autoHash(hasher, info.bit_offset);
                std.hash.autoHash(hasher, info.host_size);
                std.hash.autoHash(hasher, info.@"allowzero");
                std.hash.autoHash(hasher, info.mutable);
                std.hash.autoHash(hasher, info.@"volatile");
                std.hash.autoHash(hasher, info.size);
            },

            .optional,
            .optional_single_const_pointer,
            .optional_single_mut_pointer,
            => {
                std.hash.autoHash(hasher, std.builtin.TypeId.Optional);

                var buf: Payload.ElemType = undefined;
                hashWithHasher(ty.optionalChild(&buf), hasher, mod);
            },

            .anyerror_void_error_union, .error_union => {
                std.hash.autoHash(hasher, std.builtin.TypeId.ErrorUnion);

                const set_ty = ty.errorUnionSet();
                hashWithHasher(set_ty, hasher, mod);

                const payload_ty = ty.errorUnionPayload();
                hashWithHasher(payload_ty, hasher, mod);
            },

            .anyframe_T => {
                std.hash.autoHash(hasher, std.builtin.TypeId.AnyFrame);
                hashWithHasher(ty.childType(), hasher, mod);
            },

            .empty_struct => {
                std.hash.autoHash(hasher, std.builtin.TypeId.Struct);
                const namespace: *const Module.Namespace = ty.castTag(.empty_struct).?.data;
                std.hash.autoHash(hasher, namespace);
            },
            .@"struct" => {
                const struct_obj: *const Module.Struct = ty.castTag(.@"struct").?.data;
                std.hash.autoHash(hasher, struct_obj);
            },
            .tuple, .empty_struct_literal => {
                std.hash.autoHash(hasher, std.builtin.TypeId.Struct);

                const tuple = ty.tupleFields();
                std.hash.autoHash(hasher, tuple.types.len);

                for (tuple.types) |field_ty, i| {
                    hashWithHasher(field_ty, hasher, mod);
                    const field_val = tuple.values[i];
                    if (field_val.tag() == .unreachable_value) continue;
                    field_val.hash(field_ty, hasher, mod);
                }
            },
            .anon_struct => {
                const struct_obj = ty.castTag(.anon_struct).?.data;
                std.hash.autoHash(hasher, std.builtin.TypeId.Struct);
                std.hash.autoHash(hasher, struct_obj.types.len);

                for (struct_obj.types) |field_ty, i| {
                    const field_name = struct_obj.names[i];
                    const field_val = struct_obj.values[i];
                    hasher.update(field_name);
                    hashWithHasher(field_ty, hasher, mod);
                    if (field_val.tag() == .unreachable_value) continue;
                    field_val.hash(field_ty, hasher, mod);
                }
            },

            // we can't hash these based on tags because they wouldn't match the expanded version.
            .call_options,
            .prefetch_options,
            .export_options,
            .extern_options,
            => unreachable, // needed to resolve the type before now

            .enum_full, .enum_nonexhaustive => {
                const enum_obj: *const Module.EnumFull = ty.cast(Payload.EnumFull).?.data;
                std.hash.autoHash(hasher, std.builtin.TypeId.Enum);
                std.hash.autoHash(hasher, enum_obj);
            },
            .enum_simple => {
                const enum_obj: *const Module.EnumSimple = ty.cast(Payload.EnumSimple).?.data;
                std.hash.autoHash(hasher, std.builtin.TypeId.Enum);
                std.hash.autoHash(hasher, enum_obj);
            },
            .enum_numbered => {
                const enum_obj: *const Module.EnumNumbered = ty.cast(Payload.EnumNumbered).?.data;
                std.hash.autoHash(hasher, std.builtin.TypeId.Enum);
                std.hash.autoHash(hasher, enum_obj);
            },
            // we can't hash these based on tags because they wouldn't match the expanded version.
            .atomic_order,
            .atomic_rmw_op,
            .calling_convention,
            .address_space,
            .float_mode,
            .reduce_op,
            => unreachable, // needed to resolve the type before now

            .@"union", .union_tagged => {
                const union_obj: *const Module.Union = ty.cast(Payload.Union).?.data;
                std.hash.autoHash(hasher, std.builtin.TypeId.Union);
                std.hash.autoHash(hasher, union_obj);
            },
            // we can't hash these based on tags because they wouldn't match the expanded version.
            .type_info => unreachable, // needed to resolve the type before now

            .bound_fn => unreachable, // TODO delete from the language
            .var_args_param => unreachable, // can be any type
        }
    }

    fn hashSentinel(opt_val: ?Value, ty: Type, hasher: *std.hash.Wyhash, mod: *Module) void {
        if (opt_val) |s| {
            std.hash.autoHash(hasher, true);
            s.hash(ty, hasher, mod);
        } else {
            std.hash.autoHash(hasher, false);
        }
    }

    pub const HashContext64 = struct {
        mod: *Module,

        pub fn hash(self: @This(), t: Type) u64 {
            return t.hash(self.mod);
        }
        pub fn eql(self: @This(), a: Type, b: Type) bool {
            return a.eql(b, self.mod);
        }
    };

    pub const HashContext32 = struct {
        mod: *Module,

        pub fn hash(self: @This(), t: Type) u32 {
            return @truncate(u32, t.hash(self.mod));
        }
        pub fn eql(self: @This(), a: Type, b: Type, b_index: usize) bool {
            _ = b_index;
            return a.eql(b, self.mod);
        }
    };

    pub fn copy(self: Type, allocator: Allocator) error{OutOfMemory}!Type {
        if (@enumToInt(self.tag_if_small_enough) < Tag.no_payload_count) {
            return Type{ .tag_if_small_enough = self.tag_if_small_enough };
        } else switch (self.ptr_otherwise.tag) {
            .u1,
            .u8,
            .i8,
            .u16,
            .i16,
            .u29,
            .u32,
            .i32,
            .u64,
            .i64,
            .u128,
            .i128,
            .usize,
            .isize,
            .c_short,
            .c_ushort,
            .c_int,
            .c_uint,
            .c_long,
            .c_ulong,
            .c_longlong,
            .c_ulonglong,
            .c_longdouble,
            .anyopaque,
            .f16,
            .f32,
            .f64,
            .f80,
            .f128,
            .bool,
            .void,
            .type,
            .anyerror,
            .comptime_int,
            .comptime_float,
            .noreturn,
            .@"null",
            .@"undefined",
            .fn_noreturn_no_args,
            .fn_void_no_args,
            .fn_naked_noreturn_no_args,
            .fn_ccc_void_no_args,
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            .const_slice_u8_sentinel_0,
            .enum_literal,
            .anyerror_void_error_union,
            .inferred_alloc_const,
            .inferred_alloc_mut,
            .var_args_param,
            .empty_struct_literal,
            .manyptr_u8,
            .manyptr_const_u8,
            .manyptr_const_u8_sentinel_0,
            .atomic_order,
            .atomic_rmw_op,
            .calling_convention,
            .address_space,
            .float_mode,
            .reduce_op,
            .call_options,
            .prefetch_options,
            .export_options,
            .extern_options,
            .type_info,
            .@"anyframe",
            .generic_poison,
            .bound_fn,
            => unreachable,

            .array_u8,
            .array_u8_sentinel_0,
            => return self.copyPayloadShallow(allocator, Payload.Len),

            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            .optional,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            .anyframe_T,
            => {
                const payload = self.cast(Payload.ElemType).?;
                const new_payload = try allocator.create(Payload.ElemType);
                new_payload.* = .{
                    .base = .{ .tag = payload.base.tag },
                    .data = try payload.data.copy(allocator),
                };
                return Type{ .ptr_otherwise = &new_payload.base };
            },

            .int_signed,
            .int_unsigned,
            => return self.copyPayloadShallow(allocator, Payload.Bits),

            .vector => {
                const payload = self.castTag(.vector).?.data;
                return Tag.vector.create(allocator, .{
                    .len = payload.len,
                    .elem_type = try payload.elem_type.copy(allocator),
                });
            },
            .array => {
                const payload = self.castTag(.array).?.data;
                return Tag.array.create(allocator, .{
                    .len = payload.len,
                    .elem_type = try payload.elem_type.copy(allocator),
                });
            },
            .array_sentinel => {
                const payload = self.castTag(.array_sentinel).?.data;
                return Tag.array_sentinel.create(allocator, .{
                    .len = payload.len,
                    .sentinel = try payload.sentinel.copy(allocator),
                    .elem_type = try payload.elem_type.copy(allocator),
                });
            },
            .tuple => {
                const payload = self.castTag(.tuple).?.data;
                const types = try allocator.alloc(Type, payload.types.len);
                const values = try allocator.alloc(Value, payload.values.len);
                for (payload.types) |ty, i| {
                    types[i] = try ty.copy(allocator);
                }
                for (payload.values) |val, i| {
                    values[i] = try val.copy(allocator);
                }
                return Tag.tuple.create(allocator, .{
                    .types = types,
                    .values = values,
                });
            },
            .anon_struct => {
                const payload = self.castTag(.anon_struct).?.data;
                const names = try allocator.alloc([]const u8, payload.names.len);
                const types = try allocator.alloc(Type, payload.types.len);
                const values = try allocator.alloc(Value, payload.values.len);
                for (payload.names) |name, i| {
                    names[i] = try allocator.dupe(u8, name);
                }
                for (payload.types) |ty, i| {
                    types[i] = try ty.copy(allocator);
                }
                for (payload.values) |val, i| {
                    values[i] = try val.copy(allocator);
                }
                return Tag.anon_struct.create(allocator, .{
                    .names = names,
                    .types = types,
                    .values = values,
                });
            },
            .function => {
                const payload = self.castTag(.function).?.data;
                const param_types = try allocator.alloc(Type, payload.param_types.len);
                for (payload.param_types) |param_ty, i| {
                    param_types[i] = try param_ty.copy(allocator);
                }
                const other_comptime_params = payload.comptime_params[0..payload.param_types.len];
                const comptime_params = try allocator.dupe(bool, other_comptime_params);
                return Tag.function.create(allocator, .{
                    .return_type = try payload.return_type.copy(allocator),
                    .param_types = param_types,
                    .cc = payload.cc,
                    .alignment = payload.alignment,
                    .is_var_args = payload.is_var_args,
                    .is_generic = payload.is_generic,
                    .comptime_params = comptime_params.ptr,
                    .align_is_generic = payload.align_is_generic,
                    .cc_is_generic = payload.cc_is_generic,
                    .section_is_generic = payload.section_is_generic,
                    .addrspace_is_generic = payload.addrspace_is_generic,
                    .noalias_bits = payload.noalias_bits,
                });
            },
            .pointer => {
                const payload = self.castTag(.pointer).?.data;
                const sent: ?Value = if (payload.sentinel) |some|
                    try some.copy(allocator)
                else
                    null;
                return Tag.pointer.create(allocator, .{
                    .pointee_type = try payload.pointee_type.copy(allocator),
                    .sentinel = sent,
                    .@"align" = payload.@"align",
                    .@"addrspace" = payload.@"addrspace",
                    .bit_offset = payload.bit_offset,
                    .host_size = payload.host_size,
                    .@"allowzero" = payload.@"allowzero",
                    .mutable = payload.mutable,
                    .@"volatile" = payload.@"volatile",
                    .size = payload.size,
                });
            },
            .error_union => {
                const payload = self.castTag(.error_union).?.data;
                return Tag.error_union.create(allocator, .{
                    .error_set = try payload.error_set.copy(allocator),
                    .payload = try payload.payload.copy(allocator),
                });
            },
            .error_set_merged => {
                const names = self.castTag(.error_set_merged).?.data.keys();
                var duped_names = Module.ErrorSet.NameMap{};
                try duped_names.ensureTotalCapacity(allocator, names.len);
                for (names) |name| {
                    duped_names.putAssumeCapacityNoClobber(name, {});
                }
                return Tag.error_set_merged.create(allocator, duped_names);
            },
            .error_set => return self.copyPayloadShallow(allocator, Payload.ErrorSet),
            .error_set_inferred => return self.copyPayloadShallow(allocator, Payload.ErrorSetInferred),
            .error_set_single => return self.copyPayloadShallow(allocator, Payload.Name),
            .empty_struct => return self.copyPayloadShallow(allocator, Payload.ContainerScope),
            .@"struct" => return self.copyPayloadShallow(allocator, Payload.Struct),
            .@"union", .union_tagged => return self.copyPayloadShallow(allocator, Payload.Union),
            .enum_simple => return self.copyPayloadShallow(allocator, Payload.EnumSimple),
            .enum_numbered => return self.copyPayloadShallow(allocator, Payload.EnumNumbered),
            .enum_full, .enum_nonexhaustive => return self.copyPayloadShallow(allocator, Payload.EnumFull),
            .@"opaque" => return self.copyPayloadShallow(allocator, Payload.Opaque),
        }
    }

    fn copyPayloadShallow(self: Type, allocator: Allocator, comptime T: type) error{OutOfMemory}!Type {
        const payload = self.cast(T).?;
        const new_payload = try allocator.create(T);
        new_payload.* = payload.*;
        return Type{ .ptr_otherwise = &new_payload.base };
    }

    pub fn format(ty: Type, comptime unused_fmt_string: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = ty;
        _ = unused_fmt_string;
        _ = options;
        _ = writer;
        @compileError("do not format types directly; use either ty.fmtDebug() or ty.fmt()");
    }

    pub fn fmt(ty: Type, module: *Module) std.fmt.Formatter(format2) {
        return .{ .data = .{
            .ty = ty,
            .module = module,
        } };
    }

    const FormatContext = struct {
        ty: Type,
        module: *Module,
    };

    fn format2(
        ctx: FormatContext,
        comptime unused_format_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        comptime assert(unused_format_string.len == 0);
        _ = options;
        return print(ctx.ty, writer, ctx.module);
    }

    pub fn fmtDebug(ty: Type) std.fmt.Formatter(dump) {
        return .{ .data = ty };
    }

    /// This is a debug function. In order to print types in a meaningful way
    /// we also need access to the target.
    pub fn dump(
        start_type: Type,
        comptime unused_format_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        _ = options;
        comptime assert(unused_format_string.len == 0);
        if (@import("builtin").zig_backend != .stage1) {
            // This is disabled to work around a stage2 bug where this function recursively
            // causes more generic function instantiations resulting in an infinite loop
            // in the compiler.
            try writer.writeAll("[TODO fix internal compiler bug regarding dump]");
            return;
        }
        var ty = start_type;
        while (true) {
            const t = ty.tag();
            switch (t) {
                .u1,
                .u8,
                .i8,
                .u16,
                .i16,
                .u29,
                .u32,
                .i32,
                .u64,
                .i64,
                .u128,
                .i128,
                .usize,
                .isize,
                .c_short,
                .c_ushort,
                .c_int,
                .c_uint,
                .c_long,
                .c_ulong,
                .c_longlong,
                .c_ulonglong,
                .c_longdouble,
                .anyopaque,
                .f16,
                .f32,
                .f64,
                .f80,
                .f128,
                .bool,
                .void,
                .type,
                .anyerror,
                .@"anyframe",
                .comptime_int,
                .comptime_float,
                .noreturn,
                .var_args_param,
                .bound_fn,
                => return writer.writeAll(@tagName(t)),

                .enum_literal => return writer.writeAll("@Type(.EnumLiteral)"),
                .@"null" => return writer.writeAll("@Type(.Null)"),
                .@"undefined" => return writer.writeAll("@Type(.Undefined)"),

                .empty_struct, .empty_struct_literal => return writer.writeAll("struct {}"),

                .@"struct" => {
                    const struct_obj = ty.castTag(.@"struct").?.data;
                    return writer.print("({s} decl={d})", .{
                        @tagName(t), struct_obj.owner_decl,
                    });
                },
                .@"union", .union_tagged => {
                    const union_obj = ty.cast(Payload.Union).?.data;
                    return writer.print("({s} decl={d})", .{
                        @tagName(t), union_obj.owner_decl,
                    });
                },
                .enum_full, .enum_nonexhaustive => {
                    const enum_full = ty.cast(Payload.EnumFull).?.data;
                    return writer.print("({s} decl={d})", .{
                        @tagName(t), enum_full.owner_decl,
                    });
                },
                .enum_simple => {
                    const enum_simple = ty.castTag(.enum_simple).?.data;
                    return writer.print("({s} decl={d})", .{
                        @tagName(t), enum_simple.owner_decl,
                    });
                },
                .enum_numbered => {
                    const enum_numbered = ty.castTag(.enum_numbered).?.data;
                    return writer.print("({s} decl={d})", .{
                        @tagName(t), enum_numbered.owner_decl,
                    });
                },
                .@"opaque" => {
                    const opaque_obj = ty.castTag(.@"opaque").?.data;
                    return writer.print("({s} decl={d})", .{
                        @tagName(t), opaque_obj.owner_decl,
                    });
                },

                .anyerror_void_error_union => return writer.writeAll("anyerror!void"),
                .const_slice_u8 => return writer.writeAll("[]const u8"),
                .const_slice_u8_sentinel_0 => return writer.writeAll("[:0]const u8"),
                .fn_noreturn_no_args => return writer.writeAll("fn() noreturn"),
                .fn_void_no_args => return writer.writeAll("fn() void"),
                .fn_naked_noreturn_no_args => return writer.writeAll("fn() callconv(.Naked) noreturn"),
                .fn_ccc_void_no_args => return writer.writeAll("fn() callconv(.C) void"),
                .single_const_pointer_to_comptime_int => return writer.writeAll("*const comptime_int"),
                .manyptr_u8 => return writer.writeAll("[*]u8"),
                .manyptr_const_u8 => return writer.writeAll("[*]const u8"),
                .manyptr_const_u8_sentinel_0 => return writer.writeAll("[*:0]const u8"),
                .atomic_order => return writer.writeAll("std.builtin.AtomicOrder"),
                .atomic_rmw_op => return writer.writeAll("std.builtin.AtomicRmwOp"),
                .calling_convention => return writer.writeAll("std.builtin.CallingConvention"),
                .address_space => return writer.writeAll("std.builtin.AddressSpace"),
                .float_mode => return writer.writeAll("std.builtin.FloatMode"),
                .reduce_op => return writer.writeAll("std.builtin.ReduceOp"),
                .call_options => return writer.writeAll("std.builtin.CallOptions"),
                .prefetch_options => return writer.writeAll("std.builtin.PrefetchOptions"),
                .export_options => return writer.writeAll("std.builtin.ExportOptions"),
                .extern_options => return writer.writeAll("std.builtin.ExternOptions"),
                .type_info => return writer.writeAll("std.builtin.Type"),
                .function => {
                    const payload = ty.castTag(.function).?.data;
                    try writer.writeAll("fn(");
                    for (payload.param_types) |param_type, i| {
                        if (i != 0) try writer.writeAll(", ");
                        try param_type.dump("", .{}, writer);
                    }
                    if (payload.is_var_args) {
                        if (payload.param_types.len != 0) {
                            try writer.writeAll(", ");
                        }
                        try writer.writeAll("...");
                    }
                    try writer.writeAll(") ");
                    if (payload.cc != .Unspecified) {
                        try writer.writeAll("callconv(.");
                        try writer.writeAll(@tagName(payload.cc));
                        try writer.writeAll(") ");
                    }
                    if (payload.alignment != 0) {
                        try writer.print("align({d}) ", .{payload.alignment});
                    }
                    ty = payload.return_type;
                    continue;
                },

                .anyframe_T => {
                    const return_type = ty.castTag(.anyframe_T).?.data;
                    try writer.print("anyframe->", .{});
                    ty = return_type;
                    continue;
                },
                .array_u8 => {
                    const len = ty.castTag(.array_u8).?.data;
                    return writer.print("[{d}]u8", .{len});
                },
                .array_u8_sentinel_0 => {
                    const len = ty.castTag(.array_u8_sentinel_0).?.data;
                    return writer.print("[{d}:0]u8", .{len});
                },
                .vector => {
                    const payload = ty.castTag(.vector).?.data;
                    try writer.print("@Vector({d}, ", .{payload.len});
                    try payload.elem_type.dump("", .{}, writer);
                    return writer.writeAll(")");
                },
                .array => {
                    const payload = ty.castTag(.array).?.data;
                    try writer.print("[{d}]", .{payload.len});
                    ty = payload.elem_type;
                    continue;
                },
                .array_sentinel => {
                    const payload = ty.castTag(.array_sentinel).?.data;
                    try writer.print("[{d}:{}]", .{
                        payload.len,
                        payload.sentinel.fmtDebug(),
                    });
                    ty = payload.elem_type;
                    continue;
                },
                .tuple => {
                    const tuple = ty.castTag(.tuple).?.data;
                    try writer.writeAll("tuple{");
                    for (tuple.types) |field_ty, i| {
                        if (i != 0) try writer.writeAll(", ");
                        const val = tuple.values[i];
                        if (val.tag() != .unreachable_value) {
                            try writer.writeAll("comptime ");
                        }
                        try field_ty.dump("", .{}, writer);
                        if (val.tag() != .unreachable_value) {
                            try writer.print(" = {}", .{val.fmtDebug()});
                        }
                    }
                    try writer.writeAll("}");
                    return;
                },
                .anon_struct => {
                    const anon_struct = ty.castTag(.anon_struct).?.data;
                    try writer.writeAll("struct{");
                    for (anon_struct.types) |field_ty, i| {
                        if (i != 0) try writer.writeAll(", ");
                        const val = anon_struct.values[i];
                        if (val.tag() != .unreachable_value) {
                            try writer.writeAll("comptime ");
                        }
                        try writer.writeAll(anon_struct.names[i]);
                        try writer.writeAll(": ");
                        try field_ty.dump("", .{}, writer);
                        if (val.tag() != .unreachable_value) {
                            try writer.print(" = {}", .{val.fmtDebug()});
                        }
                    }
                    try writer.writeAll("}");
                    return;
                },
                .single_const_pointer => {
                    const pointee_type = ty.castTag(.single_const_pointer).?.data;
                    try writer.writeAll("*const ");
                    ty = pointee_type;
                    continue;
                },
                .single_mut_pointer => {
                    const pointee_type = ty.castTag(.single_mut_pointer).?.data;
                    try writer.writeAll("*");
                    ty = pointee_type;
                    continue;
                },
                .many_const_pointer => {
                    const pointee_type = ty.castTag(.many_const_pointer).?.data;
                    try writer.writeAll("[*]const ");
                    ty = pointee_type;
                    continue;
                },
                .many_mut_pointer => {
                    const pointee_type = ty.castTag(.many_mut_pointer).?.data;
                    try writer.writeAll("[*]");
                    ty = pointee_type;
                    continue;
                },
                .c_const_pointer => {
                    const pointee_type = ty.castTag(.c_const_pointer).?.data;
                    try writer.writeAll("[*c]const ");
                    ty = pointee_type;
                    continue;
                },
                .c_mut_pointer => {
                    const pointee_type = ty.castTag(.c_mut_pointer).?.data;
                    try writer.writeAll("[*c]");
                    ty = pointee_type;
                    continue;
                },
                .const_slice => {
                    const pointee_type = ty.castTag(.const_slice).?.data;
                    try writer.writeAll("[]const ");
                    ty = pointee_type;
                    continue;
                },
                .mut_slice => {
                    const pointee_type = ty.castTag(.mut_slice).?.data;
                    try writer.writeAll("[]");
                    ty = pointee_type;
                    continue;
                },
                .int_signed => {
                    const bits = ty.castTag(.int_signed).?.data;
                    return writer.print("i{d}", .{bits});
                },
                .int_unsigned => {
                    const bits = ty.castTag(.int_unsigned).?.data;
                    return writer.print("u{d}", .{bits});
                },
                .optional => {
                    const child_type = ty.castTag(.optional).?.data;
                    try writer.writeByte('?');
                    ty = child_type;
                    continue;
                },
                .optional_single_const_pointer => {
                    const pointee_type = ty.castTag(.optional_single_const_pointer).?.data;
                    try writer.writeAll("?*const ");
                    ty = pointee_type;
                    continue;
                },
                .optional_single_mut_pointer => {
                    const pointee_type = ty.castTag(.optional_single_mut_pointer).?.data;
                    try writer.writeAll("?*");
                    ty = pointee_type;
                    continue;
                },

                .pointer => {
                    const payload = ty.castTag(.pointer).?.data;
                    if (payload.sentinel) |some| switch (payload.size) {
                        .One, .C => unreachable,
                        .Many => try writer.print("[*:{}]", .{some.fmtDebug()}),
                        .Slice => try writer.print("[:{}]", .{some.fmtDebug()}),
                    } else switch (payload.size) {
                        .One => try writer.writeAll("*"),
                        .Many => try writer.writeAll("[*]"),
                        .C => try writer.writeAll("[*c]"),
                        .Slice => try writer.writeAll("[]"),
                    }
                    if (payload.@"align" != 0 or payload.host_size != 0) {
                        try writer.print("align({d}", .{payload.@"align"});

                        if (payload.bit_offset != 0 or payload.host_size != 0) {
                            try writer.print(":{d}:{d}", .{ payload.bit_offset, payload.host_size });
                        }
                        try writer.writeAll(") ");
                    }
                    if (payload.@"addrspace" != .generic) {
                        try writer.print("addrspace(.{s}) ", .{@tagName(payload.@"addrspace")});
                    }
                    if (!payload.mutable) try writer.writeAll("const ");
                    if (payload.@"volatile") try writer.writeAll("volatile ");
                    if (payload.@"allowzero" and payload.size != .C) try writer.writeAll("allowzero ");

                    ty = payload.pointee_type;
                    continue;
                },
                .error_union => {
                    const payload = ty.castTag(.error_union).?.data;
                    try payload.error_set.dump("", .{}, writer);
                    try writer.writeAll("!");
                    ty = payload.payload;
                    continue;
                },
                .error_set => {
                    const names = ty.castTag(.error_set).?.data.names.keys();
                    try writer.writeAll("error{");
                    for (names) |name, i| {
                        if (i != 0) try writer.writeByte(',');
                        try writer.writeAll(name);
                    }
                    try writer.writeAll("}");
                    return;
                },
                .error_set_inferred => {
                    const func = ty.castTag(.error_set_inferred).?.data.func;
                    return writer.print("({s} func={d})", .{
                        @tagName(t), func.owner_decl,
                    });
                },
                .error_set_merged => {
                    const names = ty.castTag(.error_set_merged).?.data.keys();
                    try writer.writeAll("error{");
                    for (names) |name, i| {
                        if (i != 0) try writer.writeByte(',');
                        try writer.writeAll(name);
                    }
                    try writer.writeAll("}");
                    return;
                },
                .error_set_single => {
                    const name = ty.castTag(.error_set_single).?.data;
                    return writer.print("error{{{s}}}", .{name});
                },
                .inferred_alloc_const => return writer.writeAll("(inferred_alloc_const)"),
                .inferred_alloc_mut => return writer.writeAll("(inferred_alloc_mut)"),
                .generic_poison => return writer.writeAll("(generic poison)"),
            }
            unreachable;
        }
    }

    pub const nameAllocArena = nameAlloc;

    pub fn nameAlloc(ty: Type, ally: Allocator, module: *Module) Allocator.Error![:0]const u8 {
        var buffer = std.ArrayList(u8).init(ally);
        defer buffer.deinit();
        try ty.print(buffer.writer(), module);
        return buffer.toOwnedSliceSentinel(0);
    }

    /// Prints a name suitable for `@typeName`.
    pub fn print(ty: Type, writer: anytype, mod: *Module) @TypeOf(writer).Error!void {
        const t = ty.tag();
        switch (t) {
            .inferred_alloc_const => unreachable,
            .inferred_alloc_mut => unreachable,
            .generic_poison => unreachable,
            .var_args_param => unreachable,
            .bound_fn => unreachable,

            // TODO get rid of these Type.Tag values.
            .atomic_order => unreachable,
            .atomic_rmw_op => unreachable,
            .calling_convention => unreachable,
            .address_space => unreachable,
            .float_mode => unreachable,
            .reduce_op => unreachable,
            .call_options => unreachable,
            .prefetch_options => unreachable,
            .export_options => unreachable,
            .extern_options => unreachable,
            .type_info => unreachable,

            .u1,
            .u8,
            .i8,
            .u16,
            .i16,
            .u29,
            .u32,
            .i32,
            .u64,
            .i64,
            .u128,
            .i128,
            .usize,
            .isize,
            .c_short,
            .c_ushort,
            .c_int,
            .c_uint,
            .c_long,
            .c_ulong,
            .c_longlong,
            .c_ulonglong,
            .c_longdouble,
            .anyopaque,
            .f16,
            .f32,
            .f64,
            .f80,
            .f128,
            .bool,
            .void,
            .type,
            .anyerror,
            .@"anyframe",
            .comptime_int,
            .comptime_float,
            .noreturn,
            => try writer.writeAll(@tagName(t)),

            .enum_literal => try writer.writeAll("@TypeOf(.enum_literal)"),
            .@"null" => try writer.writeAll("@TypeOf(null)"),
            .@"undefined" => try writer.writeAll("@TypeOf(undefined)"),
            .empty_struct_literal => try writer.writeAll("@TypeOf(.{})"),

            .empty_struct => {
                const namespace = ty.castTag(.empty_struct).?.data;
                try namespace.renderFullyQualifiedName(mod, "", writer);
            },

            .@"struct" => {
                const struct_obj = ty.castTag(.@"struct").?.data;
                const decl = mod.declPtr(struct_obj.owner_decl);
                try decl.renderFullyQualifiedName(mod, writer);
            },
            .@"union", .union_tagged => {
                const union_obj = ty.cast(Payload.Union).?.data;
                const decl = mod.declPtr(union_obj.owner_decl);
                try decl.renderFullyQualifiedName(mod, writer);
            },
            .enum_full, .enum_nonexhaustive => {
                const enum_full = ty.cast(Payload.EnumFull).?.data;
                const decl = mod.declPtr(enum_full.owner_decl);
                try decl.renderFullyQualifiedName(mod, writer);
            },
            .enum_simple => {
                const enum_simple = ty.castTag(.enum_simple).?.data;
                const decl = mod.declPtr(enum_simple.owner_decl);
                try decl.renderFullyQualifiedName(mod, writer);
            },
            .enum_numbered => {
                const enum_numbered = ty.castTag(.enum_numbered).?.data;
                const decl = mod.declPtr(enum_numbered.owner_decl);
                try decl.renderFullyQualifiedName(mod, writer);
            },
            .@"opaque" => {
                const opaque_obj = ty.cast(Payload.Opaque).?.data;
                const decl = mod.declPtr(opaque_obj.owner_decl);
                try decl.renderFullyQualifiedName(mod, writer);
            },

            .anyerror_void_error_union => try writer.writeAll("anyerror!void"),
            .const_slice_u8 => try writer.writeAll("[]const u8"),
            .const_slice_u8_sentinel_0 => try writer.writeAll("[:0]const u8"),
            .fn_noreturn_no_args => try writer.writeAll("fn() noreturn"),
            .fn_void_no_args => try writer.writeAll("fn() void"),
            .fn_naked_noreturn_no_args => try writer.writeAll("fn() callconv(.Naked) noreturn"),
            .fn_ccc_void_no_args => try writer.writeAll("fn() callconv(.C) void"),
            .single_const_pointer_to_comptime_int => try writer.writeAll("*const comptime_int"),
            .manyptr_u8 => try writer.writeAll("[*]u8"),
            .manyptr_const_u8 => try writer.writeAll("[*]const u8"),
            .manyptr_const_u8_sentinel_0 => try writer.writeAll("[*:0]const u8"),

            .error_set_inferred => {
                const func = ty.castTag(.error_set_inferred).?.data.func;

                try writer.writeAll("@typeInfo(@typeInfo(@TypeOf(");
                const owner_decl = mod.declPtr(func.owner_decl);
                try owner_decl.renderFullyQualifiedName(mod, writer);
                try writer.writeAll(")).Fn.return_type.?).ErrorUnion.error_set");
            },

            .function => {
                const fn_info = ty.fnInfo();
                try writer.writeAll("fn(");
                for (fn_info.param_types) |param_ty, i| {
                    if (i != 0) try writer.writeAll(", ");
                    if (param_ty.tag() == .generic_poison) {
                        try writer.writeAll("anytype");
                    } else {
                        try print(param_ty, writer, mod);
                    }
                }
                if (fn_info.is_var_args) {
                    if (fn_info.param_types.len != 0) {
                        try writer.writeAll(", ");
                    }
                    try writer.writeAll("...");
                }
                try writer.writeAll(") ");
                if (fn_info.cc != .Unspecified) {
                    try writer.writeAll("callconv(.");
                    try writer.writeAll(@tagName(fn_info.cc));
                    try writer.writeAll(") ");
                }
                if (fn_info.alignment != 0) {
                    try writer.print("align({d}) ", .{fn_info.alignment});
                }
                if (fn_info.return_type.tag() == .generic_poison) {
                    try writer.writeAll("anytype");
                } else {
                    try print(fn_info.return_type, writer, mod);
                }
            },

            .error_union => {
                const error_union = ty.castTag(.error_union).?.data;
                try print(error_union.error_set, writer, mod);
                try writer.writeAll("!");
                try print(error_union.payload, writer, mod);
            },

            .array_u8 => {
                const len = ty.castTag(.array_u8).?.data;
                try writer.print("[{d}]u8", .{len});
            },
            .array_u8_sentinel_0 => {
                const len = ty.castTag(.array_u8_sentinel_0).?.data;
                try writer.print("[{d}:0]u8", .{len});
            },
            .vector => {
                const payload = ty.castTag(.vector).?.data;
                try writer.print("@Vector({d}, ", .{payload.len});
                try print(payload.elem_type, writer, mod);
                try writer.writeAll(")");
            },
            .array => {
                const payload = ty.castTag(.array).?.data;
                try writer.print("[{d}]", .{payload.len});
                try print(payload.elem_type, writer, mod);
            },
            .array_sentinel => {
                const payload = ty.castTag(.array_sentinel).?.data;
                try writer.print("[{d}:{}]", .{
                    payload.len,
                    payload.sentinel.fmtValue(payload.elem_type, mod),
                });
                try print(payload.elem_type, writer, mod);
            },
            .tuple => {
                const tuple = ty.castTag(.tuple).?.data;

                try writer.writeAll("tuple{");
                for (tuple.types) |field_ty, i| {
                    if (i != 0) try writer.writeAll(", ");
                    const val = tuple.values[i];
                    if (val.tag() != .unreachable_value) {
                        try writer.writeAll("comptime ");
                    }
                    try print(field_ty, writer, mod);
                    if (val.tag() != .unreachable_value) {
                        try writer.print(" = {}", .{val.fmtValue(field_ty, mod)});
                    }
                }
                try writer.writeAll("}");
            },
            .anon_struct => {
                const anon_struct = ty.castTag(.anon_struct).?.data;

                try writer.writeAll("struct{");
                for (anon_struct.types) |field_ty, i| {
                    if (i != 0) try writer.writeAll(", ");
                    const val = anon_struct.values[i];
                    if (val.tag() != .unreachable_value) {
                        try writer.writeAll("comptime ");
                    }
                    try writer.writeAll(anon_struct.names[i]);
                    try writer.writeAll(": ");

                    try print(field_ty, writer, mod);

                    if (val.tag() != .unreachable_value) {
                        try writer.print(" = {}", .{val.fmtValue(field_ty, mod)});
                    }
                }
                try writer.writeAll("}");
            },

            .pointer,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            => {
                const info = ty.ptrInfo().data;

                if (info.sentinel) |s| switch (info.size) {
                    .One, .C => unreachable,
                    .Many => try writer.print("[*:{}]", .{s.fmtValue(info.pointee_type, mod)}),
                    .Slice => try writer.print("[:{}]", .{s.fmtValue(info.pointee_type, mod)}),
                } else switch (info.size) {
                    .One => try writer.writeAll("*"),
                    .Many => try writer.writeAll("[*]"),
                    .C => try writer.writeAll("[*c]"),
                    .Slice => try writer.writeAll("[]"),
                }
                if (info.@"align" != 0 or info.host_size != 0) {
                    try writer.print("align({d}", .{info.@"align"});

                    if (info.bit_offset != 0 or info.host_size != 0) {
                        try writer.print(":{d}:{d}", .{ info.bit_offset, info.host_size });
                    }
                    try writer.writeAll(") ");
                }
                if (info.@"addrspace" != .generic) {
                    try writer.print("addrspace(.{s}) ", .{@tagName(info.@"addrspace")});
                }
                if (!info.mutable) try writer.writeAll("const ");
                if (info.@"volatile") try writer.writeAll("volatile ");
                if (info.@"allowzero" and info.size != .C) try writer.writeAll("allowzero ");

                try print(info.pointee_type, writer, mod);
            },

            .int_signed => {
                const bits = ty.castTag(.int_signed).?.data;
                return writer.print("i{d}", .{bits});
            },
            .int_unsigned => {
                const bits = ty.castTag(.int_unsigned).?.data;
                return writer.print("u{d}", .{bits});
            },
            .optional => {
                const child_type = ty.castTag(.optional).?.data;
                try writer.writeByte('?');
                try print(child_type, writer, mod);
            },
            .optional_single_mut_pointer => {
                const pointee_type = ty.castTag(.optional_single_mut_pointer).?.data;
                try writer.writeAll("?*");
                try print(pointee_type, writer, mod);
            },
            .optional_single_const_pointer => {
                const pointee_type = ty.castTag(.optional_single_const_pointer).?.data;
                try writer.writeAll("?*const ");
                try print(pointee_type, writer, mod);
            },
            .anyframe_T => {
                const return_type = ty.castTag(.anyframe_T).?.data;
                try writer.print("anyframe->", .{});
                try print(return_type, writer, mod);
            },
            .error_set => {
                const names = ty.castTag(.error_set).?.data.names.keys();
                try writer.writeAll("error{");
                for (names) |name, i| {
                    if (i != 0) try writer.writeByte(',');
                    try writer.writeAll(name);
                }
                try writer.writeAll("}");
            },
            .error_set_single => {
                const name = ty.castTag(.error_set_single).?.data;
                return writer.print("error{{{s}}}", .{name});
            },
            .error_set_merged => {
                const names = ty.castTag(.error_set_merged).?.data.keys();
                try writer.writeAll("error{");
                for (names) |name, i| {
                    if (i != 0) try writer.writeByte(',');
                    try writer.writeAll(name);
                }
                try writer.writeAll("}");
            },
        }
    }

    pub fn toValue(self: Type, allocator: Allocator) Allocator.Error!Value {
        switch (self.tag()) {
            .u1 => return Value.initTag(.u1_type),
            .u8 => return Value.initTag(.u8_type),
            .i8 => return Value.initTag(.i8_type),
            .u16 => return Value.initTag(.u16_type),
            .u29 => return Value.initTag(.u29_type),
            .i16 => return Value.initTag(.i16_type),
            .u32 => return Value.initTag(.u32_type),
            .i32 => return Value.initTag(.i32_type),
            .u64 => return Value.initTag(.u64_type),
            .i64 => return Value.initTag(.i64_type),
            .usize => return Value.initTag(.usize_type),
            .isize => return Value.initTag(.isize_type),
            .c_short => return Value.initTag(.c_short_type),
            .c_ushort => return Value.initTag(.c_ushort_type),
            .c_int => return Value.initTag(.c_int_type),
            .c_uint => return Value.initTag(.c_uint_type),
            .c_long => return Value.initTag(.c_long_type),
            .c_ulong => return Value.initTag(.c_ulong_type),
            .c_longlong => return Value.initTag(.c_longlong_type),
            .c_ulonglong => return Value.initTag(.c_ulonglong_type),
            .c_longdouble => return Value.initTag(.c_longdouble_type),
            .anyopaque => return Value.initTag(.anyopaque_type),
            .f16 => return Value.initTag(.f16_type),
            .f32 => return Value.initTag(.f32_type),
            .f64 => return Value.initTag(.f64_type),
            .f80 => return Value.initTag(.f80_type),
            .f128 => return Value.initTag(.f128_type),
            .bool => return Value.initTag(.bool_type),
            .void => return Value.initTag(.void_type),
            .type => return Value.initTag(.type_type),
            .anyerror => return Value.initTag(.anyerror_type),
            .@"anyframe" => return Value.initTag(.anyframe_type),
            .comptime_int => return Value.initTag(.comptime_int_type),
            .comptime_float => return Value.initTag(.comptime_float_type),
            .noreturn => return Value.initTag(.noreturn_type),
            .@"null" => return Value.initTag(.null_type),
            .@"undefined" => return Value.initTag(.undefined_type),
            .fn_noreturn_no_args => return Value.initTag(.fn_noreturn_no_args_type),
            .fn_void_no_args => return Value.initTag(.fn_void_no_args_type),
            .fn_naked_noreturn_no_args => return Value.initTag(.fn_naked_noreturn_no_args_type),
            .fn_ccc_void_no_args => return Value.initTag(.fn_ccc_void_no_args_type),
            .single_const_pointer_to_comptime_int => return Value.initTag(.single_const_pointer_to_comptime_int_type),
            .const_slice_u8 => return Value.initTag(.const_slice_u8_type),
            .const_slice_u8_sentinel_0 => return Value.initTag(.const_slice_u8_sentinel_0_type),
            .enum_literal => return Value.initTag(.enum_literal_type),
            .manyptr_u8 => return Value.initTag(.manyptr_u8_type),
            .manyptr_const_u8 => return Value.initTag(.manyptr_const_u8_type),
            .manyptr_const_u8_sentinel_0 => return Value.initTag(.manyptr_const_u8_sentinel_0_type),
            .atomic_order => return Value.initTag(.atomic_order_type),
            .atomic_rmw_op => return Value.initTag(.atomic_rmw_op_type),
            .calling_convention => return Value.initTag(.calling_convention_type),
            .address_space => return Value.initTag(.address_space_type),
            .float_mode => return Value.initTag(.float_mode_type),
            .reduce_op => return Value.initTag(.reduce_op_type),
            .call_options => return Value.initTag(.call_options_type),
            .prefetch_options => return Value.initTag(.prefetch_options_type),
            .export_options => return Value.initTag(.export_options_type),
            .extern_options => return Value.initTag(.extern_options_type),
            .type_info => return Value.initTag(.type_info_type),
            .inferred_alloc_const => unreachable,
            .inferred_alloc_mut => unreachable,
            else => return Value.Tag.ty.create(allocator, self),
        }
    }

    /// true if and only if the type takes up space in memory at runtime.
    /// There are two reasons a type will return false:
    /// * the type is a comptime-only type. For example, the type `type` itself.
    ///   - note, however, that a struct can have mixed fields and only the non-comptime-only
    ///     fields will count towards the ABI size. For example, `struct {T: type, x: i32}`
    ///     hasRuntimeBits()=true and abiSize()=4
    /// * the type has only one possible value, making its ABI size 0.
    /// When `ignore_comptime_only` is true, then types that are comptime only
    /// may return false positives.
    pub fn hasRuntimeBitsAdvanced(
        ty: Type,
        ignore_comptime_only: bool,
        sema_kit: ?Module.WipAnalysis,
    ) Module.CompileError!bool {
        switch (ty.tag()) {
            .u1,
            .u8,
            .i8,
            .u16,
            .i16,
            .u29,
            .u32,
            .i32,
            .u64,
            .i64,
            .u128,
            .i128,
            .usize,
            .isize,
            .c_short,
            .c_ushort,
            .c_int,
            .c_uint,
            .c_long,
            .c_ulong,
            .c_longlong,
            .c_ulonglong,
            .c_longdouble,
            .f16,
            .f32,
            .f64,
            .f80,
            .f128,
            .bool,
            .anyerror,
            .const_slice_u8,
            .const_slice_u8_sentinel_0,
            .array_u8_sentinel_0,
            .anyerror_void_error_union,
            .error_set_inferred,
            .manyptr_u8,
            .manyptr_const_u8,
            .manyptr_const_u8_sentinel_0,
            .atomic_order,
            .atomic_rmw_op,
            .calling_convention,
            .address_space,
            .float_mode,
            .reduce_op,
            .call_options,
            .prefetch_options,
            .export_options,
            .extern_options,
            .@"anyframe",
            .anyopaque,
            .@"opaque",
            .type_info,
            .error_set_single,
            .error_union,
            .error_set,
            .error_set_merged,
            => return true,

            // These are false because they are comptime-only types.
            .single_const_pointer_to_comptime_int,
            .void,
            .type,
            .comptime_int,
            .comptime_float,
            .noreturn,
            .@"null",
            .@"undefined",
            .enum_literal,
            .empty_struct,
            .empty_struct_literal,
            .bound_fn,
            // These are function *bodies*, not pointers.
            // Special exceptions have to be made when emitting functions due to
            // this returning false.
            .function,
            .fn_noreturn_no_args,
            .fn_void_no_args,
            .fn_naked_noreturn_no_args,
            .fn_ccc_void_no_args,
            => return false,

            // These types have more than one possible value, so the result is the same as
            // asking whether they are comptime-only types.
            .anyframe_T,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            .pointer,
            => {
                if (ignore_comptime_only) {
                    return true;
                } else if (sema_kit) |sk| {
                    return !(try sk.sema.typeRequiresComptime(sk.block, sk.src, ty));
                } else {
                    return !comptimeOnly(ty);
                }
            },

            .optional => {
                var buf: Payload.ElemType = undefined;
                const child_ty = ty.optionalChild(&buf);
                if (child_ty.isNoReturn()) {
                    // Then the optional is comptime-known to be null.
                    return false;
                }
                if (ignore_comptime_only) {
                    return true;
                } else if (sema_kit) |sk| {
                    return !(try sk.sema.typeRequiresComptime(sk.block, sk.src, child_ty));
                } else {
                    return !comptimeOnly(child_ty);
                }
            },

            .@"struct" => {
                const struct_obj = ty.castTag(.@"struct").?.data;
                if (struct_obj.status == .field_types_wip) {
                    // In this case, we guess that hasRuntimeBits() for this type is true,
                    // and then later if our guess was incorrect, we emit a compile error.
                    return true;
                }
                if (sema_kit) |sk| {
                    _ = try sk.sema.resolveTypeFields(sk.block, sk.src, ty);
                }
                assert(struct_obj.haveFieldTypes());
                for (struct_obj.fields.values()) |value| {
                    if (value.is_comptime) continue;
                    if (try value.ty.hasRuntimeBitsAdvanced(ignore_comptime_only, sema_kit))
                        return true;
                } else {
                    return false;
                }
            },

            .enum_full => {
                const enum_full = ty.castTag(.enum_full).?.data;
                return enum_full.fields.count() >= 2;
            },
            .enum_simple => {
                const enum_simple = ty.castTag(.enum_simple).?.data;
                return enum_simple.fields.count() >= 2;
            },
            .enum_numbered, .enum_nonexhaustive => {
                var buffer: Payload.Bits = undefined;
                const int_tag_ty = ty.intTagType(&buffer);
                return int_tag_ty.hasRuntimeBitsAdvanced(ignore_comptime_only, sema_kit);
            },

            .@"union" => {
                const union_obj = ty.castTag(.@"union").?.data;
                if (sema_kit) |sk| {
                    _ = try sk.sema.resolveTypeFields(sk.block, sk.src, ty);
                }
                assert(union_obj.haveFieldTypes());
                for (union_obj.fields.values()) |value| {
                    if (try value.ty.hasRuntimeBitsAdvanced(ignore_comptime_only, sema_kit))
                        return true;
                } else {
                    return false;
                }
            },
            .union_tagged => {
                const union_obj = ty.castTag(.union_tagged).?.data;
                if (try union_obj.tag_ty.hasRuntimeBitsAdvanced(ignore_comptime_only, sema_kit)) {
                    return true;
                }
                if (sema_kit) |sk| {
                    _ = try sk.sema.resolveTypeFields(sk.block, sk.src, ty);
                }
                assert(union_obj.haveFieldTypes());
                for (union_obj.fields.values()) |value| {
                    if (try value.ty.hasRuntimeBitsAdvanced(ignore_comptime_only, sema_kit))
                        return true;
                } else {
                    return false;
                }
            },

            .array, .vector => return ty.arrayLen() != 0 and
                try ty.elemType().hasRuntimeBitsAdvanced(ignore_comptime_only, sema_kit),
            .array_u8 => return ty.arrayLen() != 0,
            .array_sentinel => return ty.childType().hasRuntimeBitsAdvanced(ignore_comptime_only, sema_kit),

            .int_signed, .int_unsigned => return ty.cast(Payload.Bits).?.data != 0,

            .tuple, .anon_struct => {
                const tuple = ty.tupleFields();
                for (tuple.types) |field_ty, i| {
                    const val = tuple.values[i];
                    if (val.tag() != .unreachable_value) continue; // comptime field
                    if (try field_ty.hasRuntimeBitsAdvanced(ignore_comptime_only, sema_kit)) return true;
                }
                return false;
            },

            .inferred_alloc_const => unreachable,
            .inferred_alloc_mut => unreachable,
            .var_args_param => unreachable,
            .generic_poison => unreachable,
        }
    }

    /// true if and only if the type has a well-defined memory layout
    /// readFrom/writeToMemory are supported only for types with a well-
    /// defined memory layout
    pub fn hasWellDefinedLayout(ty: Type) bool {
        return switch (ty.tag()) {
            .u1,
            .u8,
            .i8,
            .u16,
            .i16,
            .u29,
            .u32,
            .i32,
            .u64,
            .i64,
            .u128,
            .i128,
            .usize,
            .isize,
            .c_short,
            .c_ushort,
            .c_int,
            .c_uint,
            .c_long,
            .c_ulong,
            .c_longlong,
            .c_ulonglong,
            .c_longdouble,
            .f16,
            .f32,
            .f64,
            .f80,
            .f128,
            .bool,
            .void,
            .manyptr_u8,
            .manyptr_const_u8,
            .manyptr_const_u8_sentinel_0,
            .array_u8,
            .array_u8_sentinel_0,
            .int_signed,
            .int_unsigned,
            .pointer,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .single_const_pointer_to_comptime_int,
            .enum_numbered,
            .vector,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            => true,

            .anyopaque,
            .anyerror,
            .noreturn,
            .@"null",
            .@"anyframe",
            .@"undefined",
            .atomic_order,
            .atomic_rmw_op,
            .calling_convention,
            .address_space,
            .float_mode,
            .reduce_op,
            .call_options,
            .prefetch_options,
            .export_options,
            .extern_options,
            .error_set,
            .error_set_single,
            .error_set_inferred,
            .error_set_merged,
            .@"opaque",
            .generic_poison,
            .type,
            .comptime_int,
            .comptime_float,
            .enum_literal,
            .type_info,
            // These are function bodies, not function pointers.
            .fn_noreturn_no_args,
            .fn_void_no_args,
            .fn_naked_noreturn_no_args,
            .fn_ccc_void_no_args,
            .function,
            .const_slice_u8,
            .const_slice_u8_sentinel_0,
            .const_slice,
            .mut_slice,
            .enum_simple,
            .error_union,
            .anyerror_void_error_union,
            .anyframe_T,
            .tuple,
            .anon_struct,
            .empty_struct_literal,
            .empty_struct,
            => false,

            .enum_full,
            .enum_nonexhaustive,
            => !ty.cast(Payload.EnumFull).?.data.tag_ty_inferred,

            .var_args_param => unreachable,
            .inferred_alloc_mut => unreachable,
            .inferred_alloc_const => unreachable,
            .bound_fn => unreachable,

            .array,
            .array_sentinel,
            => ty.childType().hasWellDefinedLayout(),

            .optional => ty.isPtrLikeOptional(),
            .@"struct" => ty.castTag(.@"struct").?.data.layout != .Auto,
            .@"union" => ty.castTag(.@"union").?.data.layout != .Auto,
            .union_tagged => false,
        };
    }

    pub fn hasRuntimeBits(ty: Type) bool {
        return hasRuntimeBitsAdvanced(ty, false, null) catch unreachable;
    }

    pub fn hasRuntimeBitsIgnoreComptime(ty: Type) bool {
        return hasRuntimeBitsAdvanced(ty, true, null) catch unreachable;
    }

    pub fn isFnOrHasRuntimeBits(ty: Type) bool {
        switch (ty.zigTypeTag()) {
            .Fn => {
                const fn_info = ty.fnInfo();
                if (fn_info.is_generic) return false;
                if (fn_info.is_var_args) return true;
                switch (fn_info.cc) {
                    // If there was a comptime calling convention,
                    // it should also return false here.
                    .Inline => return false,
                    else => {},
                }
                if (fn_info.return_type.comptimeOnly()) return false;
                return true;
            },
            else => return ty.hasRuntimeBits(),
        }
    }

    /// Same as `isFnOrHasRuntimeBits` but comptime-only types may return a false positive.
    pub fn isFnOrHasRuntimeBitsIgnoreComptime(ty: Type) bool {
        return switch (ty.zigTypeTag()) {
            .Fn => true,
            else => return ty.hasRuntimeBitsIgnoreComptime(),
        };
    }

    /// TODO add enums with no fields here
    pub fn isNoReturn(ty: Type) bool {
        switch (ty.tag()) {
            .noreturn => return true,
            .error_set => {
                const err_set_obj = ty.castTag(.error_set).?.data;
                const names = err_set_obj.names.keys();
                return names.len == 0;
            },
            .error_set_merged => {
                const name_map = ty.castTag(.error_set_merged).?.data;
                const names = name_map.keys();
                return names.len == 0;
            },
            else => return false,
        }
    }

    /// Returns 0 if the pointer is naturally aligned and the element type is 0-bit.
    pub fn ptrAlignment(self: Type, target: Target) u32 {
        switch (self.tag()) {
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            .optional_single_const_pointer,
            .optional_single_mut_pointer,
            => {
                const child_type = self.cast(Payload.ElemType).?.data;
                return child_type.abiAlignment(target);
            },

            .manyptr_u8,
            .manyptr_const_u8,
            .manyptr_const_u8_sentinel_0,
            .const_slice_u8,
            .const_slice_u8_sentinel_0,
            => return 1,

            .pointer => {
                const ptr_info = self.castTag(.pointer).?.data;
                if (ptr_info.@"align" != 0) {
                    return ptr_info.@"align";
                } else {
                    return ptr_info.pointee_type.abiAlignment(target);
                }
            },
            .optional => return self.castTag(.optional).?.data.ptrAlignment(target),

            else => unreachable,
        }
    }

    pub fn ptrAddressSpace(self: Type) std.builtin.AddressSpace {
        return switch (self.tag()) {
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            .const_slice_u8_sentinel_0,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            .inferred_alloc_const,
            .inferred_alloc_mut,
            .manyptr_u8,
            .manyptr_const_u8,
            .manyptr_const_u8_sentinel_0,
            => .generic,

            .pointer => self.castTag(.pointer).?.data.@"addrspace",

            else => unreachable,
        };
    }

    /// Returns 0 for 0-bit types.
    pub fn abiAlignment(ty: Type, target: Target) u32 {
        return (ty.abiAlignmentAdvanced(target, .eager) catch unreachable).scalar;
    }

    /// May capture a reference to `ty`.
    pub fn lazyAbiAlignment(ty: Type, target: Target, arena: Allocator) !Value {
        switch (try ty.abiAlignmentAdvanced(target, .{ .lazy = arena })) {
            .val => |val| return val,
            .scalar => |x| return Value.Tag.int_u64.create(arena, x),
        }
    }

    const AbiAlignmentAdvanced = union(enum) {
        scalar: u32,
        val: Value,
    };

    const AbiAlignmentAdvancedStrat = union(enum) {
        eager,
        lazy: Allocator,
        sema_kit: Module.WipAnalysis,
    };

    /// If you pass `eager` you will get back `scalar` and assert the type is resolved.
    /// In this case there will be no error, guaranteed.
    /// If you pass `lazy` you may get back `scalar` or `val`.
    /// If `val` is returned, a reference to `ty` has been captured.
    /// If you pass `sema_kit` you will get back `scalar` and resolve the type if
    /// necessary, possibly returning a CompileError.
    pub fn abiAlignmentAdvanced(
        ty: Type,
        target: Target,
        strat: AbiAlignmentAdvancedStrat,
    ) Module.CompileError!AbiAlignmentAdvanced {
        const sema_kit = switch (strat) {
            .sema_kit => |sk| sk,
            else => null,
        };
        switch (ty.tag()) {
            .u1,
            .u8,
            .i8,
            .bool,
            .array_u8_sentinel_0,
            .array_u8,
            .atomic_order,
            .atomic_rmw_op,
            .calling_convention,
            .address_space,
            .float_mode,
            .reduce_op,
            .call_options,
            .prefetch_options,
            .export_options,
            .extern_options,
            .@"opaque",
            .anyopaque,
            => return AbiAlignmentAdvanced{ .scalar = 1 },

            .fn_noreturn_no_args, // represents machine code; not a pointer
            .fn_void_no_args, // represents machine code; not a pointer
            .fn_naked_noreturn_no_args, // represents machine code; not a pointer
            .fn_ccc_void_no_args, // represents machine code; not a pointer
            => return AbiAlignmentAdvanced{ .scalar = target_util.defaultFunctionAlignment(target) },

            // represents machine code; not a pointer
            .function => {
                const alignment = ty.castTag(.function).?.data.alignment;
                if (alignment != 0) return AbiAlignmentAdvanced{ .scalar = alignment };
                return AbiAlignmentAdvanced{ .scalar = target_util.defaultFunctionAlignment(target) };
            },

            .isize,
            .usize,
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            .const_slice_u8_sentinel_0,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            .optional_single_const_pointer,
            .optional_single_mut_pointer,
            .pointer,
            .manyptr_u8,
            .manyptr_const_u8,
            .manyptr_const_u8_sentinel_0,
            .@"anyframe",
            .anyframe_T,
            => return AbiAlignmentAdvanced{ .scalar = @divExact(target.cpu.arch.ptrBitWidth(), 8) },

            .c_short => return AbiAlignmentAdvanced{ .scalar = @divExact(CType.short.sizeInBits(target), 8) },
            .c_ushort => return AbiAlignmentAdvanced{ .scalar = @divExact(CType.ushort.sizeInBits(target), 8) },
            .c_int => return AbiAlignmentAdvanced{ .scalar = @divExact(CType.int.sizeInBits(target), 8) },
            .c_uint => return AbiAlignmentAdvanced{ .scalar = @divExact(CType.uint.sizeInBits(target), 8) },
            .c_long => return AbiAlignmentAdvanced{ .scalar = @divExact(CType.long.sizeInBits(target), 8) },
            .c_ulong => return AbiAlignmentAdvanced{ .scalar = @divExact(CType.ulong.sizeInBits(target), 8) },
            .c_longlong => return AbiAlignmentAdvanced{ .scalar = @divExact(CType.longlong.sizeInBits(target), 8) },
            .c_ulonglong => return AbiAlignmentAdvanced{ .scalar = @divExact(CType.ulonglong.sizeInBits(target), 8) },

            .f16 => return AbiAlignmentAdvanced{ .scalar = 2 },
            .f32 => return AbiAlignmentAdvanced{ .scalar = 4 },
            .f64 => return AbiAlignmentAdvanced{ .scalar = 8 },
            .f128 => return AbiAlignmentAdvanced{ .scalar = 16 },

            .f80 => switch (target.cpu.arch) {
                .i386 => return AbiAlignmentAdvanced{ .scalar = 4 },
                .x86_64 => return AbiAlignmentAdvanced{ .scalar = 16 },
                else => {
                    var payload: Payload.Bits = .{
                        .base = .{ .tag = .int_unsigned },
                        .data = 80,
                    };
                    const u80_ty = initPayload(&payload.base);
                    return AbiAlignmentAdvanced{ .scalar = abiAlignment(u80_ty, target) };
                },
            },
            .c_longdouble => switch (CType.longdouble.sizeInBits(target)) {
                16 => return AbiAlignmentAdvanced{ .scalar = abiAlignment(Type.f16, target) },
                32 => return AbiAlignmentAdvanced{ .scalar = abiAlignment(Type.f32, target) },
                64 => return AbiAlignmentAdvanced{ .scalar = abiAlignment(Type.f64, target) },
                80 => return AbiAlignmentAdvanced{ .scalar = abiAlignment(Type.f80, target) },
                128 => return AbiAlignmentAdvanced{ .scalar = abiAlignment(Type.f128, target) },
                else => unreachable,
            },

            // TODO revisit this when we have the concept of the error tag type
            .anyerror_void_error_union,
            .anyerror,
            .error_set_inferred,
            .error_set_single,
            .error_set,
            .error_set_merged,
            => return AbiAlignmentAdvanced{ .scalar = 2 },

            .array, .array_sentinel => return ty.elemType().abiAlignmentAdvanced(target, strat),

            .vector => {
                const len = ty.arrayLen();
                const bits = try bitSizeAdvanced(ty.elemType(), target, sema_kit);
                const bytes = ((bits * len) + 7) / 8;
                const alignment = std.math.ceilPowerOfTwoAssert(u64, bytes);
                return AbiAlignmentAdvanced{ .scalar = @intCast(u32, alignment) };
            },

            .i16, .u16 => return AbiAlignmentAdvanced{ .scalar = intAbiAlignment(16, target) },
            .u29 => return AbiAlignmentAdvanced{ .scalar = intAbiAlignment(29, target) },
            .i32, .u32 => return AbiAlignmentAdvanced{ .scalar = intAbiAlignment(32, target) },
            .i64, .u64 => return AbiAlignmentAdvanced{ .scalar = intAbiAlignment(64, target) },
            .u128, .i128 => return AbiAlignmentAdvanced{ .scalar = intAbiAlignment(128, target) },

            .int_signed, .int_unsigned => {
                const bits: u16 = ty.cast(Payload.Bits).?.data;
                if (bits == 0) return AbiAlignmentAdvanced{ .scalar = 0 };
                return AbiAlignmentAdvanced{ .scalar = intAbiAlignment(bits, target) };
            },

            .optional => {
                var buf: Payload.ElemType = undefined;
                const child_type = ty.optionalChild(&buf);

                switch (child_type.zigTypeTag()) {
                    .Pointer => return AbiAlignmentAdvanced{ .scalar = @divExact(target.cpu.arch.ptrBitWidth(), 8) },
                    .ErrorSet => return abiAlignmentAdvanced(Type.anyerror, target, strat),
                    .NoReturn => return AbiAlignmentAdvanced{ .scalar = 0 },
                    else => {},
                }

                switch (strat) {
                    .eager, .sema_kit => {
                        if (!(try child_type.hasRuntimeBitsAdvanced(false, sema_kit))) {
                            return AbiAlignmentAdvanced{ .scalar = 1 };
                        }
                        return child_type.abiAlignmentAdvanced(target, strat);
                    },
                    .lazy => |arena| switch (try child_type.abiAlignmentAdvanced(target, strat)) {
                        .scalar => |x| return AbiAlignmentAdvanced{ .scalar = @maximum(x, 1) },
                        .val => return AbiAlignmentAdvanced{ .val = try Value.Tag.lazy_align.create(arena, ty) },
                    },
                }
            },

            .error_union => {
                // This code needs to be kept in sync with the equivalent switch prong
                // in abiSizeAdvanced.
                const data = ty.castTag(.error_union).?.data;
                const code_align = abiAlignment(Type.anyerror, target);
                switch (strat) {
                    .eager, .sema_kit => {
                        if (!(try data.payload.hasRuntimeBitsAdvanced(false, sema_kit))) {
                            return AbiAlignmentAdvanced{ .scalar = code_align };
                        }
                        return AbiAlignmentAdvanced{ .scalar = @maximum(
                            code_align,
                            (try data.payload.abiAlignmentAdvanced(target, strat)).scalar,
                        ) };
                    },
                    .lazy => |arena| {
                        switch (try data.payload.abiAlignmentAdvanced(target, strat)) {
                            .scalar => |payload_align| {
                                return AbiAlignmentAdvanced{
                                    .scalar = @maximum(code_align, payload_align),
                                };
                            },
                            .val => {},
                        }
                        return AbiAlignmentAdvanced{ .val = try Value.Tag.lazy_align.create(arena, ty) };
                    },
                }
            },

            .@"struct" => {
                const struct_obj = ty.castTag(.@"struct").?.data;
                if (sema_kit) |sk| {
                    if (struct_obj.status == .field_types_wip) {
                        // We'll guess "pointer-aligned" and if we guess wrong, emit
                        // a compile error later.
                        return AbiAlignmentAdvanced{ .scalar = @divExact(target.cpu.arch.ptrBitWidth(), 8) };
                    }
                    _ = try sk.sema.resolveTypeFields(sk.block, sk.src, ty);
                }
                if (!struct_obj.haveFieldTypes()) switch (strat) {
                    .eager => unreachable, // struct layout not resolved
                    .sema_kit => unreachable, // handled above
                    .lazy => |arena| return AbiAlignmentAdvanced{ .val = try Value.Tag.lazy_align.create(arena, ty) },
                };
                if (struct_obj.layout == .Packed) {
                    var buf: Type.Payload.Bits = undefined;
                    const int_ty = struct_obj.packedIntegerType(target, &buf);
                    return AbiAlignmentAdvanced{ .scalar = int_ty.abiAlignment(target) };
                }

                const fields = ty.structFields();
                var big_align: u32 = 0;
                for (fields.values()) |field| {
                    if (!(try field.ty.hasRuntimeBitsAdvanced(false, sema_kit))) continue;

                    const field_align = if (field.abi_align != 0)
                        field.abi_align
                    else switch (try field.ty.abiAlignmentAdvanced(target, strat)) {
                        .scalar => |a| a,
                        .val => switch (strat) {
                            .eager => unreachable, // struct layout not resolved
                            .sema_kit => unreachable, // handled above
                            .lazy => |arena| return AbiAlignmentAdvanced{ .val = try Value.Tag.lazy_align.create(arena, ty) },
                        },
                    };
                    big_align = @maximum(big_align, field_align);
                }
                return AbiAlignmentAdvanced{ .scalar = big_align };
            },

            .tuple, .anon_struct => {
                const tuple = ty.tupleFields();
                var big_align: u32 = 0;
                for (tuple.types) |field_ty, i| {
                    const val = tuple.values[i];
                    if (val.tag() != .unreachable_value) continue; // comptime field

                    switch (try field_ty.abiAlignmentAdvanced(target, strat)) {
                        .scalar => |field_align| big_align = @maximum(big_align, field_align),
                        .val => switch (strat) {
                            .eager => unreachable, // field type alignment not resolved
                            .sema_kit => unreachable, // passed to abiAlignmentAdvanced above
                            .lazy => |arena| return AbiAlignmentAdvanced{ .val = try Value.Tag.lazy_align.create(arena, ty) },
                        },
                    }
                }
                return AbiAlignmentAdvanced{ .scalar = big_align };
            },

            .enum_full, .enum_nonexhaustive, .enum_simple, .enum_numbered => {
                var buffer: Payload.Bits = undefined;
                const int_tag_ty = ty.intTagType(&buffer);
                return AbiAlignmentAdvanced{ .scalar = int_tag_ty.abiAlignment(target) };
            },
            .@"union" => {
                const union_obj = ty.castTag(.@"union").?.data;
                // TODO pass `true` for have_tag when unions have a safety tag
                return abiAlignmentAdvancedUnion(ty, target, strat, union_obj, false);
            },
            .union_tagged => {
                const union_obj = ty.castTag(.union_tagged).?.data;
                return abiAlignmentAdvancedUnion(ty, target, strat, union_obj, true);
            },

            .empty_struct,
            .void,
            .empty_struct_literal,
            .type,
            .comptime_int,
            .comptime_float,
            .@"null",
            .@"undefined",
            .enum_literal,
            .type_info,
            => return AbiAlignmentAdvanced{ .scalar = 0 },

            .noreturn,
            .inferred_alloc_const,
            .inferred_alloc_mut,
            .var_args_param,
            .bound_fn,
            => unreachable,

            .generic_poison => unreachable,
        }
    }

    pub fn abiAlignmentAdvancedUnion(
        ty: Type,
        target: Target,
        strat: AbiAlignmentAdvancedStrat,
        union_obj: *Module.Union,
        have_tag: bool,
    ) Module.CompileError!AbiAlignmentAdvanced {
        const sema_kit = switch (strat) {
            .sema_kit => |sk| sk,
            else => null,
        };
        if (sema_kit) |sk| {
            if (union_obj.status == .field_types_wip) {
                // We'll guess "pointer-aligned" and if we guess wrong, emit
                // a compile error later.
                return AbiAlignmentAdvanced{ .scalar = @divExact(target.cpu.arch.ptrBitWidth(), 8) };
            }
            _ = try sk.sema.resolveTypeFields(sk.block, sk.src, ty);
        }
        if (!union_obj.haveFieldTypes()) switch (strat) {
            .eager => unreachable, // union layout not resolved
            .sema_kit => unreachable, // handled above
            .lazy => |arena| return AbiAlignmentAdvanced{ .val = try Value.Tag.lazy_align.create(arena, ty) },
        };

        var max_align: u32 = 0;
        if (have_tag) max_align = union_obj.tag_ty.abiAlignment(target);
        for (union_obj.fields.values()) |field| {
            if (!(try field.ty.hasRuntimeBitsAdvanced(false, sema_kit))) continue;

            const field_align = if (field.abi_align != 0)
                field.abi_align
            else switch (try field.ty.abiAlignmentAdvanced(target, strat)) {
                .scalar => |a| a,
                .val => switch (strat) {
                    .eager => unreachable, // struct layout not resolved
                    .sema_kit => unreachable, // handled above
                    .lazy => |arena| return AbiAlignmentAdvanced{ .val = try Value.Tag.lazy_align.create(arena, ty) },
                },
            };
            max_align = @maximum(max_align, field_align);
        }
        return AbiAlignmentAdvanced{ .scalar = max_align };
    }

    /// May capture a reference to `ty`.
    pub fn lazyAbiSize(ty: Type, target: Target, arena: Allocator) !Value {
        switch (try ty.abiSizeAdvanced(target, .{ .lazy = arena })) {
            .val => |val| return val,
            .scalar => |x| return Value.Tag.int_u64.create(arena, x),
        }
    }

    /// Asserts the type has the ABI size already resolved.
    /// Types that return false for hasRuntimeBits() return 0.
    pub fn abiSize(ty: Type, target: Target) u64 {
        return (abiSizeAdvanced(ty, target, .eager) catch unreachable).scalar;
    }

    const AbiSizeAdvanced = union(enum) {
        scalar: u64,
        val: Value,
    };

    /// If you pass `eager` you will get back `scalar` and assert the type is resolved.
    /// In this case there will be no error, guaranteed.
    /// If you pass `lazy` you may get back `scalar` or `val`.
    /// If `val` is returned, a reference to `ty` has been captured.
    /// If you pass `sema_kit` you will get back `scalar` and resolve the type if
    /// necessary, possibly returning a CompileError.
    pub fn abiSizeAdvanced(
        ty: Type,
        target: Target,
        strat: AbiAlignmentAdvancedStrat,
    ) Module.CompileError!AbiSizeAdvanced {
        switch (ty.tag()) {
            .fn_noreturn_no_args => unreachable, // represents machine code; not a pointer
            .fn_void_no_args => unreachable, // represents machine code; not a pointer
            .fn_naked_noreturn_no_args => unreachable, // represents machine code; not a pointer
            .fn_ccc_void_no_args => unreachable, // represents machine code; not a pointer
            .function => unreachable, // represents machine code; not a pointer
            .@"opaque" => unreachable, // no size available
            .bound_fn => unreachable, // TODO remove from the language
            .noreturn => unreachable,
            .inferred_alloc_const => unreachable,
            .inferred_alloc_mut => unreachable,
            .var_args_param => unreachable,
            .generic_poison => unreachable,
            .call_options => unreachable, // missing call to resolveTypeFields
            .prefetch_options => unreachable, // missing call to resolveTypeFields
            .export_options => unreachable, // missing call to resolveTypeFields
            .extern_options => unreachable, // missing call to resolveTypeFields
            .type_info => unreachable, // missing call to resolveTypeFields

            .anyopaque,
            .type,
            .comptime_int,
            .comptime_float,
            .@"null",
            .@"undefined",
            .enum_literal,
            .single_const_pointer_to_comptime_int,
            .empty_struct_literal,
            .empty_struct,
            .void,
            => return AbiSizeAdvanced{ .scalar = 0 },

            .@"struct", .tuple, .anon_struct => switch (ty.containerLayout()) {
                .Packed => {
                    const struct_obj = ty.castTag(.@"struct").?.data;
                    switch (strat) {
                        .sema_kit => |sk| _ = try sk.sema.resolveTypeFields(sk.block, sk.src, ty),
                        .lazy => |arena| {
                            if (!struct_obj.haveFieldTypes()) {
                                return AbiSizeAdvanced{ .val = try Value.Tag.lazy_size.create(arena, ty) };
                            }
                        },
                        .eager => {},
                    }
                    var buf: Type.Payload.Bits = undefined;
                    const int_ty = struct_obj.packedIntegerType(target, &buf);
                    return AbiSizeAdvanced{ .scalar = int_ty.abiSize(target) };
                },
                else => {
                    switch (strat) {
                        .sema_kit => |sk| try sk.sema.resolveTypeLayout(sk.block, sk.src, ty),
                        .lazy => |arena| {
                            if (ty.castTag(.@"struct")) |payload| {
                                const struct_obj = payload.data;
                                if (!struct_obj.haveLayout()) {
                                    return AbiSizeAdvanced{ .val = try Value.Tag.lazy_size.create(arena, ty) };
                                }
                            }
                        },
                        .eager => {},
                    }
                    const field_count = ty.structFieldCount();
                    if (field_count == 0) {
                        return AbiSizeAdvanced{ .scalar = 0 };
                    }
                    return AbiSizeAdvanced{ .scalar = ty.structFieldOffset(field_count, target) };
                },
            },

            .enum_simple, .enum_full, .enum_nonexhaustive, .enum_numbered => {
                var buffer: Payload.Bits = undefined;
                const int_tag_ty = ty.intTagType(&buffer);
                return AbiSizeAdvanced{ .scalar = int_tag_ty.abiSize(target) };
            },
            .@"union" => {
                const union_obj = ty.castTag(.@"union").?.data;
                // TODO pass `true` for have_tag when unions have a safety tag
                return abiSizeAdvancedUnion(ty, target, strat, union_obj, false);
            },
            .union_tagged => {
                const union_obj = ty.castTag(.union_tagged).?.data;
                return abiSizeAdvancedUnion(ty, target, strat, union_obj, true);
            },

            .u1,
            .u8,
            .i8,
            .bool,
            .atomic_order,
            .atomic_rmw_op,
            .calling_convention,
            .address_space,
            .float_mode,
            .reduce_op,
            => return AbiSizeAdvanced{ .scalar = 1 },

            .array_u8 => return AbiSizeAdvanced{ .scalar = ty.castTag(.array_u8).?.data },
            .array_u8_sentinel_0 => return AbiSizeAdvanced{ .scalar = ty.castTag(.array_u8_sentinel_0).?.data + 1 },
            .array, .vector => {
                const payload = ty.cast(Payload.Array).?.data;
                switch (try payload.elem_type.abiSizeAdvanced(target, strat)) {
                    .scalar => |elem_size| return AbiSizeAdvanced{ .scalar = payload.len * elem_size },
                    .val => switch (strat) {
                        .sema_kit => unreachable,
                        .eager => unreachable,
                        .lazy => |arena| return AbiSizeAdvanced{ .val = try Value.Tag.lazy_size.create(arena, ty) },
                    },
                }
            },
            .array_sentinel => {
                const payload = ty.castTag(.array_sentinel).?.data;
                switch (try payload.elem_type.abiSizeAdvanced(target, strat)) {
                    .scalar => |elem_size| return AbiSizeAdvanced{ .scalar = (payload.len + 1) * elem_size },
                    .val => switch (strat) {
                        .sema_kit => unreachable,
                        .eager => unreachable,
                        .lazy => |arena| return AbiSizeAdvanced{ .val = try Value.Tag.lazy_size.create(arena, ty) },
                    },
                }
            },

            .isize,
            .usize,
            .@"anyframe",
            .anyframe_T,
            .optional_single_const_pointer,
            .optional_single_mut_pointer,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .manyptr_u8,
            .manyptr_const_u8,
            .manyptr_const_u8_sentinel_0,
            => return AbiSizeAdvanced{ .scalar = @divExact(target.cpu.arch.ptrBitWidth(), 8) },

            .const_slice,
            .mut_slice,
            .const_slice_u8,
            .const_slice_u8_sentinel_0,
            => return AbiSizeAdvanced{ .scalar = @divExact(target.cpu.arch.ptrBitWidth(), 8) * 2 },

            .pointer => switch (ty.castTag(.pointer).?.data.size) {
                .Slice => return AbiSizeAdvanced{ .scalar = @divExact(target.cpu.arch.ptrBitWidth(), 8) * 2 },
                else => return AbiSizeAdvanced{ .scalar = @divExact(target.cpu.arch.ptrBitWidth(), 8) },
            },

            .c_short => return AbiSizeAdvanced{ .scalar = @divExact(CType.short.sizeInBits(target), 8) },
            .c_ushort => return AbiSizeAdvanced{ .scalar = @divExact(CType.ushort.sizeInBits(target), 8) },
            .c_int => return AbiSizeAdvanced{ .scalar = @divExact(CType.int.sizeInBits(target), 8) },
            .c_uint => return AbiSizeAdvanced{ .scalar = @divExact(CType.uint.sizeInBits(target), 8) },
            .c_long => return AbiSizeAdvanced{ .scalar = @divExact(CType.long.sizeInBits(target), 8) },
            .c_ulong => return AbiSizeAdvanced{ .scalar = @divExact(CType.ulong.sizeInBits(target), 8) },
            .c_longlong => return AbiSizeAdvanced{ .scalar = @divExact(CType.longlong.sizeInBits(target), 8) },
            .c_ulonglong => return AbiSizeAdvanced{ .scalar = @divExact(CType.ulonglong.sizeInBits(target), 8) },

            .f16 => return AbiSizeAdvanced{ .scalar = 2 },
            .f32 => return AbiSizeAdvanced{ .scalar = 4 },
            .f64 => return AbiSizeAdvanced{ .scalar = 8 },
            .f128 => return AbiSizeAdvanced{ .scalar = 16 },

            .f80 => switch (target.cpu.arch) {
                .i386 => return AbiSizeAdvanced{ .scalar = 12 },
                .x86_64 => return AbiSizeAdvanced{ .scalar = 16 },
                else => {
                    var payload: Payload.Bits = .{
                        .base = .{ .tag = .int_unsigned },
                        .data = 80,
                    };
                    const u80_ty = initPayload(&payload.base);
                    return AbiSizeAdvanced{ .scalar = abiSize(u80_ty, target) };
                },
            },
            .c_longdouble => switch (CType.longdouble.sizeInBits(target)) {
                16 => return AbiSizeAdvanced{ .scalar = abiSize(Type.f16, target) },
                32 => return AbiSizeAdvanced{ .scalar = abiSize(Type.f32, target) },
                64 => return AbiSizeAdvanced{ .scalar = abiSize(Type.f64, target) },
                80 => return AbiSizeAdvanced{ .scalar = abiSize(Type.f80, target) },
                128 => return AbiSizeAdvanced{ .scalar = abiSize(Type.f128, target) },
                else => unreachable,
            },

            // TODO revisit this when we have the concept of the error tag type
            .anyerror_void_error_union,
            .anyerror,
            .error_set_inferred,
            .error_set,
            .error_set_merged,
            .error_set_single,
            => return AbiSizeAdvanced{ .scalar = 2 },

            .i16, .u16 => return AbiSizeAdvanced{ .scalar = intAbiSize(16, target) },
            .u29 => return AbiSizeAdvanced{ .scalar = intAbiSize(29, target) },
            .i32, .u32 => return AbiSizeAdvanced{ .scalar = intAbiSize(32, target) },
            .i64, .u64 => return AbiSizeAdvanced{ .scalar = intAbiSize(64, target) },
            .u128, .i128 => return AbiSizeAdvanced{ .scalar = intAbiSize(128, target) },
            .int_signed, .int_unsigned => {
                const bits: u16 = ty.cast(Payload.Bits).?.data;
                if (bits == 0) return AbiSizeAdvanced{ .scalar = 0 };
                return AbiSizeAdvanced{ .scalar = intAbiSize(bits, target) };
            },

            .optional => {
                var buf: Payload.ElemType = undefined;
                const child_type = ty.optionalChild(&buf);

                if (child_type.isNoReturn()) {
                    return AbiSizeAdvanced{ .scalar = 0 };
                }

                if (!child_type.hasRuntimeBits()) return AbiSizeAdvanced{ .scalar = 1 };

                switch (child_type.zigTypeTag()) {
                    .Pointer => {
                        const ptr_info = child_type.ptrInfo().data;
                        const has_null = switch (ptr_info.size) {
                            .Slice, .C => true,
                            else => ptr_info.@"allowzero",
                        };
                        if (!has_null) {
                            const ptr_size_bytes = @divExact(target.cpu.arch.ptrBitWidth(), 8);
                            return AbiSizeAdvanced{ .scalar = ptr_size_bytes };
                        }
                    },
                    .ErrorSet => return abiSizeAdvanced(Type.anyerror, target, strat),
                    else => {},
                }

                // Optional types are represented as a struct with the child type as the first
                // field and a boolean as the second. Since the child type's abi alignment is
                // guaranteed to be >= that of bool's (1 byte) the added size is exactly equal
                // to the child type's ABI alignment.
                return AbiSizeAdvanced{
                    .scalar = child_type.abiAlignment(target) + child_type.abiSize(target),
                };
            },

            .error_union => {
                // This code needs to be kept in sync with the equivalent switch prong
                // in abiAlignmentAdvanced.
                const data = ty.castTag(.error_union).?.data;
                const code_size = abiSize(Type.anyerror, target);
                if (!data.payload.hasRuntimeBits()) {
                    // Same as anyerror.
                    return AbiSizeAdvanced{ .scalar = code_size };
                }
                const code_align = abiAlignment(Type.anyerror, target);
                const payload_align = abiAlignment(data.payload, target);
                const payload_size = abiSize(data.payload, target);

                var size: u64 = 0;
                if (code_align > payload_align) {
                    size += code_size;
                    size = std.mem.alignForwardGeneric(u64, size, payload_align);
                    size += payload_size;
                    size = std.mem.alignForwardGeneric(u64, size, code_align);
                } else {
                    size += payload_size;
                    size = std.mem.alignForwardGeneric(u64, size, code_align);
                    size += code_size;
                    size = std.mem.alignForwardGeneric(u64, size, payload_align);
                }
                return AbiSizeAdvanced{ .scalar = size };
            },
        }
    }

    pub fn abiSizeAdvancedUnion(
        ty: Type,
        target: Target,
        strat: AbiAlignmentAdvancedStrat,
        union_obj: *Module.Union,
        have_tag: bool,
    ) Module.CompileError!AbiSizeAdvanced {
        switch (strat) {
            .sema_kit => |sk| try sk.sema.resolveTypeLayout(sk.block, sk.src, ty),
            .lazy => |arena| {
                if (!union_obj.haveLayout()) {
                    return AbiSizeAdvanced{ .val = try Value.Tag.lazy_size.create(arena, ty) };
                }
            },
            .eager => {},
        }
        return AbiSizeAdvanced{ .scalar = union_obj.abiSize(target, have_tag) };
    }

    fn intAbiSize(bits: u16, target: Target) u64 {
        const alignment = intAbiAlignment(bits, target);
        return std.mem.alignForwardGeneric(u64, (bits + 7) / 8, alignment);
    }

    fn intAbiAlignment(bits: u16, target: Target) u32 {
        return @minimum(
            std.math.ceilPowerOfTwoPromote(u16, (bits + 7) / 8),
            target.maxIntAlignment(),
        );
    }

    pub fn bitSize(ty: Type, target: Target) u64 {
        return bitSizeAdvanced(ty, target, null) catch unreachable;
    }

    /// If you pass `sema_kit`, any recursive type resolutions will happen if
    /// necessary, possibly returning a CompileError. Passing `null` instead asserts
    /// the type is fully resolved, and there will be no error, guaranteed.
    pub fn bitSizeAdvanced(
        ty: Type,
        target: Target,
        sema_kit: ?Module.WipAnalysis,
    ) Module.CompileError!u64 {
        switch (ty.tag()) {
            .fn_noreturn_no_args => unreachable, // represents machine code; not a pointer
            .fn_void_no_args => unreachable, // represents machine code; not a pointer
            .fn_naked_noreturn_no_args => unreachable, // represents machine code; not a pointer
            .fn_ccc_void_no_args => unreachable, // represents machine code; not a pointer
            .function => unreachable, // represents machine code; not a pointer
            .anyopaque => unreachable,
            .type => unreachable,
            .comptime_int => unreachable,
            .comptime_float => unreachable,
            .noreturn => unreachable,
            .@"null" => unreachable,
            .@"undefined" => unreachable,
            .enum_literal => unreachable,
            .single_const_pointer_to_comptime_int => unreachable,
            .empty_struct => unreachable,
            .empty_struct_literal => unreachable,
            .inferred_alloc_const => unreachable,
            .inferred_alloc_mut => unreachable,
            .@"opaque" => unreachable,
            .var_args_param => unreachable,
            .generic_poison => unreachable,
            .bound_fn => unreachable,

            .void => return 0,
            .bool, .u1 => return 1,
            .u8, .i8 => return 8,
            .i16, .u16, .f16 => return 16,
            .u29 => return 29,
            .i32, .u32, .f32 => return 32,
            .i64, .u64, .f64 => return 64,
            .f80 => return 80,
            .u128, .i128, .f128 => return 128,

            .@"struct" => {
                if (sema_kit) |sk| _ = try sk.sema.resolveTypeFields(sk.block, sk.src, ty);
                var total: u64 = 0;
                for (ty.structFields().values()) |field| {
                    total += try bitSizeAdvanced(field.ty, target, sema_kit);
                }
                return total;
            },

            .tuple, .anon_struct => {
                if (sema_kit) |sk| _ = try sk.sema.resolveTypeFields(sk.block, sk.src, ty);
                var total: u64 = 0;
                for (ty.tupleFields().types) |field_ty| {
                    total += try bitSizeAdvanced(field_ty, target, sema_kit);
                }
                return total;
            },

            .enum_simple, .enum_full, .enum_nonexhaustive, .enum_numbered => {
                var buffer: Payload.Bits = undefined;
                const int_tag_ty = ty.intTagType(&buffer);
                return try bitSizeAdvanced(int_tag_ty, target, sema_kit);
            },

            .@"union", .union_tagged => {
                if (sema_kit) |sk| _ = try sk.sema.resolveTypeFields(sk.block, sk.src, ty);
                const union_obj = ty.cast(Payload.Union).?.data;
                assert(union_obj.haveFieldTypes());

                var size: u64 = 0;
                for (union_obj.fields.values()) |field| {
                    size = @maximum(size, try bitSizeAdvanced(field.ty, target, sema_kit));
                }
                return size;
            },

            .vector => {
                const payload = ty.castTag(.vector).?.data;
                const elem_bit_size = try bitSizeAdvanced(payload.elem_type, target, sema_kit);
                return elem_bit_size * payload.len;
            },
            .array_u8 => return 8 * ty.castTag(.array_u8).?.data,
            .array_u8_sentinel_0 => return 8 * (ty.castTag(.array_u8_sentinel_0).?.data + 1),
            .array => {
                const payload = ty.castTag(.array).?.data;
                const elem_size = std.math.max(payload.elem_type.abiAlignment(target), payload.elem_type.abiSize(target));
                if (elem_size == 0 or payload.len == 0)
                    return @as(u64, 0);
                const elem_bit_size = try bitSizeAdvanced(payload.elem_type, target, sema_kit);
                return (payload.len - 1) * 8 * elem_size + elem_bit_size;
            },
            .array_sentinel => {
                const payload = ty.castTag(.array_sentinel).?.data;
                const elem_size = std.math.max(
                    payload.elem_type.abiAlignment(target),
                    payload.elem_type.abiSize(target),
                );
                const elem_bit_size = try bitSizeAdvanced(payload.elem_type, target, sema_kit);
                return payload.len * 8 * elem_size + elem_bit_size;
            },

            .isize,
            .usize,
            .@"anyframe",
            .anyframe_T,
            => return target.cpu.arch.ptrBitWidth(),

            .const_slice,
            .mut_slice,
            => return target.cpu.arch.ptrBitWidth() * 2,

            .const_slice_u8,
            .const_slice_u8_sentinel_0,
            => return target.cpu.arch.ptrBitWidth() * 2,

            .optional_single_const_pointer,
            .optional_single_mut_pointer,
            => {
                return target.cpu.arch.ptrBitWidth();
            },

            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            => {
                return target.cpu.arch.ptrBitWidth();
            },

            .pointer => switch (ty.castTag(.pointer).?.data.size) {
                .Slice => return target.cpu.arch.ptrBitWidth() * 2,
                else => return target.cpu.arch.ptrBitWidth(),
            },

            .manyptr_u8,
            .manyptr_const_u8,
            .manyptr_const_u8_sentinel_0,
            => return target.cpu.arch.ptrBitWidth(),

            .c_short => return CType.short.sizeInBits(target),
            .c_ushort => return CType.ushort.sizeInBits(target),
            .c_int => return CType.int.sizeInBits(target),
            .c_uint => return CType.uint.sizeInBits(target),
            .c_long => return CType.long.sizeInBits(target),
            .c_ulong => return CType.ulong.sizeInBits(target),
            .c_longlong => return CType.longlong.sizeInBits(target),
            .c_ulonglong => return CType.ulonglong.sizeInBits(target),
            .c_longdouble => return CType.longdouble.sizeInBits(target),

            .error_set,
            .error_set_single,
            .anyerror_void_error_union,
            .anyerror,
            .error_set_inferred,
            .error_set_merged,
            => return 16, // TODO revisit this when we have the concept of the error tag type

            .int_signed, .int_unsigned => return ty.cast(Payload.Bits).?.data,

            .optional => {
                var buf: Payload.ElemType = undefined;
                const child_type = ty.optionalChild(&buf);
                if (!child_type.hasRuntimeBits()) return 8;

                if (child_type.zigTypeTag() == .Pointer and !child_type.isCPtr() and !child_type.isSlice())
                    return target.cpu.arch.ptrBitWidth();

                // Optional types are represented as a struct with the child type as the first
                // field and a boolean as the second. Since the child type's abi alignment is
                // guaranteed to be >= that of bool's (1 byte) the added size is exactly equal
                // to the child type's ABI alignment.
                const child_bit_size = try bitSizeAdvanced(child_type, target, sema_kit);
                return child_bit_size + 1;
            },

            .error_union => {
                const payload = ty.castTag(.error_union).?.data;
                if (!payload.payload.hasRuntimeBits()) {
                    return payload.error_set.bitSizeAdvanced(target, sema_kit);
                }
                @panic("TODO bitSize error union");
            },

            .atomic_order,
            .atomic_rmw_op,
            .calling_convention,
            .address_space,
            .float_mode,
            .reduce_op,
            .call_options,
            .prefetch_options,
            .export_options,
            .extern_options,
            .type_info,
            => @panic("TODO at some point we gotta resolve builtin types"),
        }
    }

    pub fn isSinglePointer(self: Type) bool {
        return switch (self.tag()) {
            .single_const_pointer,
            .single_mut_pointer,
            .single_const_pointer_to_comptime_int,
            .inferred_alloc_const,
            .inferred_alloc_mut,
            => true,

            .pointer => self.castTag(.pointer).?.data.size == .One,

            else => false,
        };
    }

    /// Asserts the `Type` is a pointer.
    pub fn ptrSize(self: Type) std.builtin.Type.Pointer.Size {
        return switch (self.tag()) {
            .const_slice,
            .mut_slice,
            .const_slice_u8,
            .const_slice_u8_sentinel_0,
            => .Slice,

            .many_const_pointer,
            .many_mut_pointer,
            .manyptr_u8,
            .manyptr_const_u8,
            .manyptr_const_u8_sentinel_0,
            => .Many,

            .c_const_pointer,
            .c_mut_pointer,
            => .C,

            .single_const_pointer,
            .single_mut_pointer,
            .single_const_pointer_to_comptime_int,
            .inferred_alloc_const,
            .inferred_alloc_mut,
            => .One,

            .pointer => self.castTag(.pointer).?.data.size,

            else => unreachable,
        };
    }

    pub fn isSlice(self: Type) bool {
        return switch (self.tag()) {
            .const_slice,
            .mut_slice,
            .const_slice_u8,
            .const_slice_u8_sentinel_0,
            => true,

            .pointer => self.castTag(.pointer).?.data.size == .Slice,

            else => false,
        };
    }

    pub const SlicePtrFieldTypeBuffer = union {
        elem_type: Payload.ElemType,
        pointer: Payload.Pointer,
    };

    pub fn slicePtrFieldType(self: Type, buffer: *SlicePtrFieldTypeBuffer) Type {
        switch (self.tag()) {
            .const_slice_u8 => return Type.initTag(.manyptr_const_u8),
            .const_slice_u8_sentinel_0 => return Type.initTag(.manyptr_const_u8_sentinel_0),

            .const_slice => {
                const elem_type = self.castTag(.const_slice).?.data;
                buffer.* = .{
                    .elem_type = .{
                        .base = .{ .tag = .many_const_pointer },
                        .data = elem_type,
                    },
                };
                return Type.initPayload(&buffer.elem_type.base);
            },
            .mut_slice => {
                const elem_type = self.castTag(.mut_slice).?.data;
                buffer.* = .{
                    .elem_type = .{
                        .base = .{ .tag = .many_mut_pointer },
                        .data = elem_type,
                    },
                };
                return Type.initPayload(&buffer.elem_type.base);
            },

            .pointer => {
                const payload = self.castTag(.pointer).?.data;
                assert(payload.size == .Slice);

                if (payload.sentinel != null or
                    payload.@"align" != 0 or
                    payload.@"addrspace" != .generic or
                    payload.bit_offset != 0 or
                    payload.host_size != 0 or
                    payload.@"allowzero" or
                    payload.@"volatile")
                {
                    buffer.* = .{
                        .pointer = .{
                            .data = .{
                                .pointee_type = payload.pointee_type,
                                .sentinel = payload.sentinel,
                                .@"align" = payload.@"align",
                                .@"addrspace" = payload.@"addrspace",
                                .bit_offset = payload.bit_offset,
                                .host_size = payload.host_size,
                                .@"allowzero" = payload.@"allowzero",
                                .mutable = payload.mutable,
                                .@"volatile" = payload.@"volatile",
                                .size = .Many,
                            },
                        },
                    };
                    return Type.initPayload(&buffer.pointer.base);
                } else if (payload.mutable) {
                    buffer.* = .{
                        .elem_type = .{
                            .base = .{ .tag = .many_mut_pointer },
                            .data = payload.pointee_type,
                        },
                    };
                    return Type.initPayload(&buffer.elem_type.base);
                } else {
                    buffer.* = .{
                        .elem_type = .{
                            .base = .{ .tag = .many_const_pointer },
                            .data = payload.pointee_type,
                        },
                    };
                    return Type.initPayload(&buffer.elem_type.base);
                }
            },

            else => unreachable,
        }
    }

    pub fn isConstPtr(self: Type) bool {
        return switch (self.tag()) {
            .single_const_pointer,
            .many_const_pointer,
            .c_const_pointer,
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            .const_slice_u8_sentinel_0,
            .const_slice,
            .manyptr_const_u8,
            .manyptr_const_u8_sentinel_0,
            => true,

            .pointer => !self.castTag(.pointer).?.data.mutable,

            else => false,
        };
    }

    pub fn isVolatilePtr(self: Type) bool {
        return switch (self.tag()) {
            .pointer => {
                const payload = self.castTag(.pointer).?.data;
                return payload.@"volatile";
            },
            else => false,
        };
    }

    pub fn isAllowzeroPtr(self: Type) bool {
        return switch (self.tag()) {
            .pointer => {
                const payload = self.castTag(.pointer).?.data;
                return payload.@"allowzero";
            },
            else => return self.zigTypeTag() == .Optional,
        };
    }

    pub fn isCPtr(self: Type) bool {
        return switch (self.tag()) {
            .c_const_pointer,
            .c_mut_pointer,
            => return true,

            .pointer => self.castTag(.pointer).?.data.size == .C,

            else => return false,
        };
    }

    pub fn isPtrAtRuntime(self: Type) bool {
        switch (self.tag()) {
            .c_const_pointer,
            .c_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .manyptr_const_u8,
            .manyptr_const_u8_sentinel_0,
            .manyptr_u8,
            .optional_single_const_pointer,
            .optional_single_mut_pointer,
            .single_const_pointer,
            .single_const_pointer_to_comptime_int,
            .single_mut_pointer,
            => return true,

            .pointer => switch (self.castTag(.pointer).?.data.size) {
                .Slice => return false,
                .One, .Many, .C => return true,
            },

            .optional => {
                var buf: Payload.ElemType = undefined;
                const child_type = self.optionalChild(&buf);
                // optionals of zero sized pointers behave like bools
                if (!child_type.hasRuntimeBits()) return false;
                if (child_type.zigTypeTag() != .Pointer) return false;

                const info = child_type.ptrInfo().data;
                switch (info.size) {
                    .Slice, .C => return false,
                    .Many, .One => return !info.@"allowzero",
                }
            },

            else => return false,
        }
    }

    /// For pointer-like optionals, returns true, otherwise returns the allowzero property
    /// of pointers.
    pub fn ptrAllowsZero(ty: Type) bool {
        if (ty.isPtrLikeOptional()) {
            return true;
        }
        return ty.ptrInfo().data.@"allowzero";
    }

    /// See also `isPtrLikeOptional`.
    pub fn optionalReprIsPayload(ty: Type) bool {
        switch (ty.tag()) {
            .optional_single_const_pointer,
            .optional_single_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            => return true,

            .optional => {
                const child_ty = ty.castTag(.optional).?.data;
                switch (child_ty.zigTypeTag()) {
                    .Pointer => {
                        const info = child_ty.ptrInfo().data;
                        switch (info.size) {
                            .Slice, .C => return false,
                            .Many, .One => return !info.@"allowzero",
                        }
                    },
                    .ErrorSet => return true,
                    else => return false,
                }
            },

            .pointer => return ty.castTag(.pointer).?.data.size == .C,

            else => return false,
        }
    }

    /// Returns true if the type is optional and would be lowered to a single pointer
    /// address value, using 0 for null. Note that this returns true for C pointers.
    pub fn isPtrLikeOptional(self: Type) bool {
        switch (self.tag()) {
            .optional_single_const_pointer,
            .optional_single_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            => return true,

            .optional => {
                const child_ty = self.castTag(.optional).?.data;
                if (child_ty.zigTypeTag() != .Pointer) return false;
                const info = child_ty.ptrInfo().data;
                switch (info.size) {
                    .Slice, .C => return false,
                    .Many, .One => return !info.@"allowzero",
                }
            },

            .pointer => return self.castTag(.pointer).?.data.size == .C,

            else => return false,
        }
    }

    /// Returns if type can be used for a runtime variable
    pub fn isValidVarType(self: Type, is_extern: bool) bool {
        var ty = self;
        while (true) switch (ty.zigTypeTag()) {
            .Bool,
            .Int,
            .Float,
            .ErrorSet,
            .Enum,
            .Frame,
            .AnyFrame,
            => return true,

            .Opaque => return is_extern,
            .BoundFn,
            .ComptimeFloat,
            .ComptimeInt,
            .EnumLiteral,
            .NoReturn,
            .Type,
            .Void,
            .Undefined,
            .Null,
            => return false,

            .Optional => {
                var buf: Payload.ElemType = undefined;
                return ty.optionalChild(&buf).isValidVarType(is_extern);
            },
            .Pointer, .Array, .Vector => ty = ty.elemType(),
            .ErrorUnion => ty = ty.errorUnionPayload(),

            .Fn => @panic("TODO fn isValidVarType"),
            .Struct => {
                // TODO this is not always correct; introduce lazy value mechanism
                // and here we need to force a resolve of "type requires comptime".
                return true;
            },
            .Union => @panic("TODO union isValidVarType"),
        };
    }

    /// For *[N]T,  returns [N]T.
    /// For *T,     returns T.
    /// For [*]T,   returns T.
    pub fn childType(ty: Type) Type {
        return switch (ty.tag()) {
            .vector => ty.castTag(.vector).?.data.elem_type,
            .array => ty.castTag(.array).?.data.elem_type,
            .array_sentinel => ty.castTag(.array_sentinel).?.data.elem_type,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            => ty.castPointer().?.data,

            .array_u8,
            .array_u8_sentinel_0,
            .const_slice_u8,
            .const_slice_u8_sentinel_0,
            .manyptr_u8,
            .manyptr_const_u8,
            .manyptr_const_u8_sentinel_0,
            => Type.u8,

            .single_const_pointer_to_comptime_int => Type.initTag(.comptime_int),
            .pointer => ty.castTag(.pointer).?.data.pointee_type,

            .var_args_param => ty,

            else => unreachable,
        };
    }

    /// Asserts the type is a pointer or array type.
    /// TODO this is deprecated in favor of `childType`.
    pub const elemType = childType;

    /// For *[N]T,       returns T.
    /// For ?*T,         returns T.
    /// For ?*[N]T,      returns T.
    /// For ?[*]T,       returns T.
    /// For *T,          returns T.
    /// For [*]T,        returns T.
    /// For [N]T,        returns T.
    /// For []T,         returns T.
    /// For anyframe->T, returns T.
    pub fn elemType2(ty: Type) Type {
        return switch (ty.tag()) {
            .vector => ty.castTag(.vector).?.data.elem_type,
            .array => ty.castTag(.array).?.data.elem_type,
            .array_sentinel => ty.castTag(.array_sentinel).?.data.elem_type,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            => ty.castPointer().?.data,

            .single_const_pointer,
            .single_mut_pointer,
            => ty.castPointer().?.data.shallowElemType(),

            .array_u8,
            .array_u8_sentinel_0,
            .const_slice_u8,
            .const_slice_u8_sentinel_0,
            .manyptr_u8,
            .manyptr_const_u8,
            .manyptr_const_u8_sentinel_0,
            => Type.u8,

            .single_const_pointer_to_comptime_int => Type.initTag(.comptime_int),
            .pointer => {
                const info = ty.castTag(.pointer).?.data;
                const child_ty = info.pointee_type;
                if (info.size == .One) {
                    return child_ty.shallowElemType();
                } else {
                    return child_ty;
                }
            },
            .optional => ty.castTag(.optional).?.data.childType(),
            .optional_single_mut_pointer => ty.castPointer().?.data,
            .optional_single_const_pointer => ty.castPointer().?.data,

            .anyframe_T => ty.castTag(.anyframe_T).?.data,
            .@"anyframe" => Type.@"void",

            else => unreachable,
        };
    }

    fn shallowElemType(child_ty: Type) Type {
        return switch (child_ty.zigTypeTag()) {
            .Array, .Vector => child_ty.childType(),
            else => child_ty,
        };
    }

    /// For vectors, returns the element type. Otherwise returns self.
    pub fn scalarType(ty: Type) Type {
        return switch (ty.zigTypeTag()) {
            .Vector => ty.childType(),
            else => ty,
        };
    }

    /// Asserts that the type is an optional.
    /// Resulting `Type` will have inner memory referencing `buf`.
    /// Note that for C pointers this returns the type unmodified.
    pub fn optionalChild(ty: Type, buf: *Payload.ElemType) Type {
        return switch (ty.tag()) {
            .optional => ty.castTag(.optional).?.data,
            .optional_single_mut_pointer => {
                buf.* = .{
                    .base = .{ .tag = .single_mut_pointer },
                    .data = ty.castPointer().?.data,
                };
                return Type.initPayload(&buf.base);
            },
            .optional_single_const_pointer => {
                buf.* = .{
                    .base = .{ .tag = .single_const_pointer },
                    .data = ty.castPointer().?.data,
                };
                return Type.initPayload(&buf.base);
            },

            .pointer, // here we assume it is a C pointer
            .c_const_pointer,
            .c_mut_pointer,
            => return ty,

            else => unreachable,
        };
    }

    /// Asserts that the type is an optional.
    /// Same as `optionalChild` but allocates the buffer if needed.
    pub fn optionalChildAlloc(ty: Type, allocator: Allocator) !Type {
        switch (ty.tag()) {
            .optional => return ty.castTag(.optional).?.data,
            .optional_single_mut_pointer => {
                return Tag.single_mut_pointer.create(allocator, ty.castPointer().?.data);
            },
            .optional_single_const_pointer => {
                return Tag.single_const_pointer.create(allocator, ty.castPointer().?.data);
            },
            .pointer, // here we assume it is a C pointer
            .c_const_pointer,
            .c_mut_pointer,
            => return ty,

            else => unreachable,
        }
    }

    /// Returns the tag type of a union, if the type is a union and it has a tag type.
    /// Otherwise, returns `null`.
    pub fn unionTagType(ty: Type) ?Type {
        return switch (ty.tag()) {
            .union_tagged => {
                const union_obj = ty.castTag(.union_tagged).?.data;
                assert(union_obj.haveFieldTypes());
                return union_obj.tag_ty;
            },

            .atomic_order,
            .atomic_rmw_op,
            .calling_convention,
            .address_space,
            .float_mode,
            .reduce_op,
            .call_options,
            .prefetch_options,
            .export_options,
            .extern_options,
            .type_info,
            => unreachable, // needed to call resolveTypeFields first

            else => null,
        };
    }

    /// Asserts the type is a union; returns the tag type, even if the tag will
    /// not be stored at runtime.
    pub fn unionTagTypeHypothetical(ty: Type) Type {
        const union_obj = ty.cast(Payload.Union).?.data;
        assert(union_obj.haveFieldTypes());
        return union_obj.tag_ty;
    }

    pub fn unionFields(ty: Type) Module.Union.Fields {
        const union_obj = ty.cast(Payload.Union).?.data;
        assert(union_obj.haveFieldTypes());
        return union_obj.fields;
    }

    pub fn unionFieldType(ty: Type, enum_tag: Value, mod: *Module) Type {
        const union_obj = ty.cast(Payload.Union).?.data;
        const index = union_obj.tag_ty.enumTagFieldIndex(enum_tag, mod).?;
        assert(union_obj.haveFieldTypes());
        return union_obj.fields.values()[index].ty;
    }

    pub fn unionHasAllZeroBitFieldTypes(ty: Type) bool {
        return ty.cast(Payload.Union).?.data.hasAllZeroBitFieldTypes();
    }

    pub fn unionGetLayout(ty: Type, target: Target) Module.Union.Layout {
        switch (ty.tag()) {
            .@"union" => {
                const union_obj = ty.castTag(.@"union").?.data;
                return union_obj.getLayout(target, false);
            },
            .union_tagged => {
                const union_obj = ty.castTag(.union_tagged).?.data;
                return union_obj.getLayout(target, true);
            },
            else => unreachable,
        }
    }

    pub fn containerLayout(ty: Type) std.builtin.Type.ContainerLayout {
        return switch (ty.tag()) {
            .tuple, .empty_struct_literal, .anon_struct => .Auto,
            .@"struct" => ty.castTag(.@"struct").?.data.layout,
            .@"union" => ty.castTag(.@"union").?.data.layout,
            .union_tagged => ty.castTag(.union_tagged).?.data.layout,
            else => unreachable,
        };
    }

    /// Asserts that the type is an error union.
    pub fn errorUnionPayload(self: Type) Type {
        return switch (self.tag()) {
            .anyerror_void_error_union => Type.initTag(.void),
            .error_union => self.castTag(.error_union).?.data.payload,
            else => unreachable,
        };
    }

    pub fn errorUnionSet(self: Type) Type {
        return switch (self.tag()) {
            .anyerror_void_error_union => Type.initTag(.anyerror),
            .error_union => self.castTag(.error_union).?.data.error_set,
            else => unreachable,
        };
    }

    /// Returns false for unresolved inferred error sets.
    pub fn errorSetIsEmpty(ty: Type) bool {
        switch (ty.tag()) {
            .anyerror => return false,
            .error_set_inferred => {
                const inferred_error_set = ty.castTag(.error_set_inferred).?.data;
                // Can't know for sure.
                if (!inferred_error_set.is_resolved) return false;
                if (inferred_error_set.is_anyerror) return false;
                return inferred_error_set.errors.count() == 0;
            },
            .error_set_single => return false,
            .error_set => {
                const err_set_obj = ty.castTag(.error_set).?.data;
                return err_set_obj.names.count() == 0;
            },
            .error_set_merged => {
                const name_map = ty.castTag(.error_set_merged).?.data;
                return name_map.count() == 0;
            },
            else => unreachable,
        }
    }

    /// Returns true if it is an error set that includes anyerror, false otherwise.
    /// Note that the result may be a false negative if the type did not get error set
    /// resolution prior to this call.
    pub fn isAnyError(ty: Type) bool {
        return switch (ty.tag()) {
            .anyerror => true,
            .error_set_inferred => ty.castTag(.error_set_inferred).?.data.is_anyerror,
            else => false,
        };
    }

    pub fn isError(ty: Type) bool {
        return switch (ty.zigTypeTag()) {
            .ErrorUnion, .ErrorSet => true,
            else => false,
        };
    }

    /// Returns whether ty, which must be an error set, includes an error `name`.
    /// Might return a false negative if `ty` is an inferred error set and not fully
    /// resolved yet.
    pub fn errorSetHasField(ty: Type, name: []const u8) bool {
        if (ty.isAnyError()) {
            return true;
        }

        switch (ty.tag()) {
            .error_set_single => {
                const data = ty.castTag(.error_set_single).?.data;
                return std.mem.eql(u8, data, name);
            },
            .error_set_inferred => {
                const data = ty.castTag(.error_set_inferred).?.data;
                return data.errors.contains(name);
            },
            .error_set_merged => {
                const data = ty.castTag(.error_set_merged).?.data;
                return data.contains(name);
            },
            .error_set => {
                const data = ty.castTag(.error_set).?.data;
                return data.names.contains(name);
            },
            else => unreachable,
        }
    }

    /// Asserts the type is an array or vector or struct.
    pub fn arrayLen(ty: Type) u64 {
        return switch (ty.tag()) {
            .vector => ty.castTag(.vector).?.data.len,
            .array => ty.castTag(.array).?.data.len,
            .array_sentinel => ty.castTag(.array_sentinel).?.data.len,
            .array_u8 => ty.castTag(.array_u8).?.data,
            .array_u8_sentinel_0 => ty.castTag(.array_u8_sentinel_0).?.data,
            .tuple => ty.castTag(.tuple).?.data.types.len,
            .anon_struct => ty.castTag(.anon_struct).?.data.types.len,
            .@"struct" => ty.castTag(.@"struct").?.data.fields.count(),
            .empty_struct, .empty_struct_literal => 0,

            else => unreachable,
        };
    }

    pub fn arrayLenIncludingSentinel(ty: Type) u64 {
        return ty.arrayLen() + @boolToInt(ty.sentinel() != null);
    }

    pub fn vectorLen(ty: Type) u32 {
        return switch (ty.tag()) {
            .vector => @intCast(u32, ty.castTag(.vector).?.data.len),
            .tuple => @intCast(u32, ty.castTag(.tuple).?.data.types.len),
            .anon_struct => @intCast(u32, ty.castTag(.anon_struct).?.data.types.len),
            else => unreachable,
        };
    }

    /// Asserts the type is an array, pointer or vector.
    pub fn sentinel(self: Type) ?Value {
        return switch (self.tag()) {
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .single_const_pointer_to_comptime_int,
            .vector,
            .array,
            .array_u8,
            .manyptr_u8,
            .manyptr_const_u8,
            .const_slice_u8,
            .const_slice,
            .mut_slice,
            .tuple,
            .empty_struct_literal,
            => return null,

            .pointer => return self.castTag(.pointer).?.data.sentinel,
            .array_sentinel => return self.castTag(.array_sentinel).?.data.sentinel,

            .array_u8_sentinel_0,
            .const_slice_u8_sentinel_0,
            .manyptr_const_u8_sentinel_0,
            => return Value.zero,

            else => unreachable,
        };
    }

    /// Returns true if and only if the type is a fixed-width integer.
    pub fn isInt(self: Type) bool {
        return self.isSignedInt() or self.isUnsignedInt();
    }

    /// Returns true if and only if the type is a fixed-width, signed integer.
    pub fn isSignedInt(self: Type) bool {
        return switch (self.tag()) {
            .int_signed,
            .i8,
            .isize,
            .c_short,
            .c_int,
            .c_long,
            .c_longlong,
            .i16,
            .i32,
            .i64,
            .i128,
            => true,

            else => false,
        };
    }

    /// Returns true if and only if the type is a fixed-width, unsigned integer.
    pub fn isUnsignedInt(self: Type) bool {
        return switch (self.tag()) {
            .int_unsigned,
            .usize,
            .c_ushort,
            .c_uint,
            .c_ulong,
            .c_ulonglong,
            .u1,
            .u8,
            .u16,
            .u29,
            .u32,
            .u64,
            .u128,
            => true,

            else => false,
        };
    }

    /// Returns true for integers, enums, error sets, and packed structs.
    /// If this function returns true, then intInfo() can be called on the type.
    pub fn isAbiInt(ty: Type) bool {
        return switch (ty.zigTypeTag()) {
            .Int, .Enum, .ErrorSet => true,
            .Struct => ty.containerLayout() == .Packed,
            else => false,
        };
    }

    /// Asserts the type is an integer, enum, error set, or vector of one of them.
    pub fn intInfo(self: Type, target: Target) struct { signedness: std.builtin.Signedness, bits: u16 } {
        var ty = self;
        while (true) switch (ty.tag()) {
            .int_unsigned => return .{
                .signedness = .unsigned,
                .bits = ty.castTag(.int_unsigned).?.data,
            },
            .int_signed => return .{
                .signedness = .signed,
                .bits = ty.castTag(.int_signed).?.data,
            },
            .u1 => return .{ .signedness = .unsigned, .bits = 1 },
            .u8 => return .{ .signedness = .unsigned, .bits = 8 },
            .i8 => return .{ .signedness = .signed, .bits = 8 },
            .u16 => return .{ .signedness = .unsigned, .bits = 16 },
            .i16 => return .{ .signedness = .signed, .bits = 16 },
            .u29 => return .{ .signedness = .unsigned, .bits = 29 },
            .u32 => return .{ .signedness = .unsigned, .bits = 32 },
            .i32 => return .{ .signedness = .signed, .bits = 32 },
            .u64 => return .{ .signedness = .unsigned, .bits = 64 },
            .i64 => return .{ .signedness = .signed, .bits = 64 },
            .u128 => return .{ .signedness = .unsigned, .bits = 128 },
            .i128 => return .{ .signedness = .signed, .bits = 128 },
            .usize => return .{ .signedness = .unsigned, .bits = target.cpu.arch.ptrBitWidth() },
            .isize => return .{ .signedness = .signed, .bits = target.cpu.arch.ptrBitWidth() },
            .c_short => return .{ .signedness = .signed, .bits = CType.short.sizeInBits(target) },
            .c_ushort => return .{ .signedness = .unsigned, .bits = CType.ushort.sizeInBits(target) },
            .c_int => return .{ .signedness = .signed, .bits = CType.int.sizeInBits(target) },
            .c_uint => return .{ .signedness = .unsigned, .bits = CType.uint.sizeInBits(target) },
            .c_long => return .{ .signedness = .signed, .bits = CType.long.sizeInBits(target) },
            .c_ulong => return .{ .signedness = .unsigned, .bits = CType.ulong.sizeInBits(target) },
            .c_longlong => return .{ .signedness = .signed, .bits = CType.longlong.sizeInBits(target) },
            .c_ulonglong => return .{ .signedness = .unsigned, .bits = CType.ulonglong.sizeInBits(target) },

            .enum_full, .enum_nonexhaustive => ty = ty.cast(Payload.EnumFull).?.data.tag_ty,
            .enum_numbered => ty = ty.castTag(.enum_numbered).?.data.tag_ty,
            .enum_simple => {
                const enum_obj = ty.castTag(.enum_simple).?.data;
                const field_count = enum_obj.fields.count();
                if (field_count == 0) return .{ .signedness = .unsigned, .bits = 0 };
                return .{ .signedness = .unsigned, .bits = smallestUnsignedBits(field_count - 1) };
            },

            .error_set, .error_set_single, .anyerror, .error_set_inferred, .error_set_merged => {
                // TODO revisit this when error sets support custom int types
                return .{ .signedness = .unsigned, .bits = 16 };
            },

            .vector => ty = ty.castTag(.vector).?.data.elem_type,

            else => unreachable,
        };
    }

    pub fn isNamedInt(self: Type) bool {
        return switch (self.tag()) {
            .usize,
            .isize,
            .c_short,
            .c_ushort,
            .c_int,
            .c_uint,
            .c_long,
            .c_ulong,
            .c_longlong,
            .c_ulonglong,
            => true,

            else => false,
        };
    }

    /// Returns `false` for `comptime_float`.
    pub fn isRuntimeFloat(self: Type) bool {
        return switch (self.tag()) {
            .f16,
            .f32,
            .f64,
            .f80,
            .f128,
            .c_longdouble,
            => true,

            else => false,
        };
    }

    /// Returns `true` for `comptime_float`.
    pub fn isAnyFloat(self: Type) bool {
        return switch (self.tag()) {
            .f16,
            .f32,
            .f64,
            .f80,
            .f128,
            .c_longdouble,
            .comptime_float,
            => true,

            else => false,
        };
    }

    /// Asserts the type is a fixed-size float or comptime_float.
    /// Returns 128 for comptime_float types.
    pub fn floatBits(self: Type, target: Target) u16 {
        return switch (self.tag()) {
            .f16 => 16,
            .f32 => 32,
            .f64 => 64,
            .f80 => 80,
            .f128, .comptime_float => 128,
            .c_longdouble => CType.longdouble.sizeInBits(target),

            else => unreachable,
        };
    }

    /// Asserts the type is a function.
    pub fn fnParamLen(self: Type) usize {
        return switch (self.tag()) {
            .fn_noreturn_no_args => 0,
            .fn_void_no_args => 0,
            .fn_naked_noreturn_no_args => 0,
            .fn_ccc_void_no_args => 0,
            .function => self.castTag(.function).?.data.param_types.len,

            else => unreachable,
        };
    }

    /// Asserts the type is a function. The length of the slice must be at least the length
    /// given by `fnParamLen`.
    pub fn fnParamTypes(self: Type, types: []Type) void {
        switch (self.tag()) {
            .fn_noreturn_no_args => return,
            .fn_void_no_args => return,
            .fn_naked_noreturn_no_args => return,
            .fn_ccc_void_no_args => return,
            .function => {
                const payload = self.castTag(.function).?.data;
                std.mem.copy(Type, types, payload.param_types);
            },

            else => unreachable,
        }
    }

    /// Asserts the type is a function.
    pub fn fnParamType(self: Type, index: usize) Type {
        switch (self.tag()) {
            .function => {
                const payload = self.castTag(.function).?.data;
                return payload.param_types[index];
            },

            else => unreachable,
        }
    }

    /// Asserts the type is a function.
    pub fn fnReturnType(self: Type) Type {
        return switch (self.tag()) {
            .fn_noreturn_no_args => Type.initTag(.noreturn),
            .fn_naked_noreturn_no_args => Type.initTag(.noreturn),

            .fn_void_no_args,
            .fn_ccc_void_no_args,
            => Type.initTag(.void),

            .function => self.castTag(.function).?.data.return_type,

            else => unreachable,
        };
    }

    /// Asserts the type is a function.
    pub fn fnCallingConvention(self: Type) std.builtin.CallingConvention {
        return switch (self.tag()) {
            .fn_noreturn_no_args => .Unspecified,
            .fn_void_no_args => .Unspecified,
            .fn_naked_noreturn_no_args => .Naked,
            .fn_ccc_void_no_args => .C,
            .function => self.castTag(.function).?.data.cc,

            else => unreachable,
        };
    }

    /// Asserts the type is a function.
    pub fn fnCallingConventionAllowsZigTypes(self: Type) bool {
        return switch (self.fnCallingConvention()) {
            .Unspecified, .Async, .Inline, .PtxKernel => true,
            else => false,
        };
    }

    /// Asserts the type is a function.
    pub fn fnIsVarArgs(self: Type) bool {
        return switch (self.tag()) {
            .fn_noreturn_no_args => false,
            .fn_void_no_args => false,
            .fn_naked_noreturn_no_args => false,
            .fn_ccc_void_no_args => false,
            .function => self.castTag(.function).?.data.is_var_args,

            else => unreachable,
        };
    }

    pub fn fnInfo(ty: Type) Payload.Function.Data {
        return switch (ty.tag()) {
            .fn_noreturn_no_args => .{
                .param_types = &.{},
                .comptime_params = undefined,
                .return_type = initTag(.noreturn),
                .cc = .Unspecified,
                .alignment = 0,
                .is_var_args = false,
                .is_generic = false,
                .align_is_generic = false,
                .cc_is_generic = false,
                .section_is_generic = false,
                .addrspace_is_generic = false,
                .noalias_bits = 0,
            },
            .fn_void_no_args => .{
                .param_types = &.{},
                .comptime_params = undefined,
                .return_type = initTag(.void),
                .cc = .Unspecified,
                .alignment = 0,
                .is_var_args = false,
                .is_generic = false,
                .align_is_generic = false,
                .cc_is_generic = false,
                .section_is_generic = false,
                .addrspace_is_generic = false,
                .noalias_bits = 0,
            },
            .fn_naked_noreturn_no_args => .{
                .param_types = &.{},
                .comptime_params = undefined,
                .return_type = initTag(.noreturn),
                .cc = .Naked,
                .alignment = 0,
                .is_var_args = false,
                .is_generic = false,
                .align_is_generic = false,
                .cc_is_generic = false,
                .section_is_generic = false,
                .addrspace_is_generic = false,
                .noalias_bits = 0,
            },
            .fn_ccc_void_no_args => .{
                .param_types = &.{},
                .comptime_params = undefined,
                .return_type = initTag(.void),
                .cc = .C,
                .alignment = 0,
                .is_var_args = false,
                .is_generic = false,
                .align_is_generic = false,
                .cc_is_generic = false,
                .section_is_generic = false,
                .addrspace_is_generic = false,
                .noalias_bits = 0,
            },
            .function => ty.castTag(.function).?.data,

            else => unreachable,
        };
    }

    pub fn isNumeric(self: Type) bool {
        return switch (self.tag()) {
            .f16,
            .f32,
            .f64,
            .f80,
            .f128,
            .c_longdouble,
            .comptime_int,
            .comptime_float,
            .u1,
            .u8,
            .i8,
            .u16,
            .i16,
            .u29,
            .u32,
            .i32,
            .u64,
            .i64,
            .u128,
            .i128,
            .usize,
            .isize,
            .c_short,
            .c_ushort,
            .c_int,
            .c_uint,
            .c_long,
            .c_ulong,
            .c_longlong,
            .c_ulonglong,
            .int_unsigned,
            .int_signed,
            => true,

            else => false,
        };
    }

    /// During semantic analysis, instead call `Sema.typeHasOnePossibleValue` which
    /// resolves field types rather than asserting they are already resolved.
    pub fn onePossibleValue(starting_type: Type) ?Value {
        var ty = starting_type;
        while (true) switch (ty.tag()) {
            .f16,
            .f32,
            .f64,
            .f80,
            .f128,
            .c_longdouble,
            .comptime_int,
            .comptime_float,
            .u1,
            .u8,
            .i8,
            .u16,
            .i16,
            .u29,
            .u32,
            .i32,
            .u64,
            .i64,
            .u128,
            .i128,
            .usize,
            .isize,
            .c_short,
            .c_ushort,
            .c_int,
            .c_uint,
            .c_long,
            .c_ulong,
            .c_longlong,
            .c_ulonglong,
            .bool,
            .type,
            .anyerror,
            .error_union,
            .error_set_single,
            .error_set,
            .error_set_merged,
            .fn_noreturn_no_args,
            .fn_void_no_args,
            .fn_naked_noreturn_no_args,
            .fn_ccc_void_no_args,
            .function,
            .single_const_pointer_to_comptime_int,
            .array_sentinel,
            .array_u8_sentinel_0,
            .const_slice_u8,
            .const_slice_u8_sentinel_0,
            .const_slice,
            .mut_slice,
            .anyopaque,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            .enum_literal,
            .anyerror_void_error_union,
            .error_set_inferred,
            .@"opaque",
            .var_args_param,
            .manyptr_u8,
            .manyptr_const_u8,
            .manyptr_const_u8_sentinel_0,
            .atomic_order,
            .atomic_rmw_op,
            .calling_convention,
            .address_space,
            .float_mode,
            .reduce_op,
            .call_options,
            .prefetch_options,
            .export_options,
            .extern_options,
            .type_info,
            .@"anyframe",
            .anyframe_T,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .single_const_pointer,
            .single_mut_pointer,
            .pointer,
            .bound_fn,
            => return null,

            .optional => {
                var buf: Payload.ElemType = undefined;
                const child_ty = ty.optionalChild(&buf);
                if (child_ty.isNoReturn()) {
                    return Value.@"null";
                } else {
                    return null;
                }
            },

            .@"struct" => {
                const s = ty.castTag(.@"struct").?.data;
                assert(s.haveFieldTypes());
                for (s.fields.values()) |field| {
                    if (field.ty.onePossibleValue() == null) {
                        return null;
                    }
                }
                return Value.initTag(.empty_struct_value);
            },

            .tuple, .anon_struct => {
                const tuple = ty.tupleFields();
                for (tuple.values) |val| {
                    if (val.tag() == .unreachable_value) {
                        return null; // non-comptime field
                    }
                }
                return Value.initTag(.empty_struct_value);
            },

            .enum_numbered => {
                const enum_numbered = ty.castTag(.enum_numbered).?.data;
                if (enum_numbered.fields.count() == 1) {
                    return enum_numbered.values.keys()[0];
                } else {
                    return null;
                }
            },
            .enum_full => {
                const enum_full = ty.castTag(.enum_full).?.data;
                if (enum_full.fields.count() == 1) {
                    if (enum_full.values.count() == 0) {
                        return Value.zero;
                    } else {
                        return enum_full.values.keys()[0];
                    }
                } else {
                    return null;
                }
            },
            .enum_simple => {
                const enum_simple = ty.castTag(.enum_simple).?.data;
                if (enum_simple.fields.count() == 1) {
                    return Value.zero;
                } else {
                    return null;
                }
            },
            .enum_nonexhaustive => {
                const tag_ty = ty.castTag(.enum_nonexhaustive).?.data.tag_ty;
                if (!tag_ty.hasRuntimeBits()) {
                    return Value.zero;
                } else {
                    return null;
                }
            },
            .@"union", .union_tagged => {
                const union_obj = ty.cast(Payload.Union).?.data;
                const tag_val = union_obj.tag_ty.onePossibleValue() orelse return null;
                const only_field = union_obj.fields.values()[0];
                const val_val = only_field.ty.onePossibleValue() orelse return null;
                _ = tag_val;
                _ = val_val;
                return Value.initTag(.empty_struct_value);
            },

            .empty_struct, .empty_struct_literal => return Value.initTag(.empty_struct_value),
            .void => return Value.initTag(.void_value),
            .noreturn => return Value.initTag(.unreachable_value),
            .@"null" => return Value.initTag(.null_value),
            .@"undefined" => return Value.initTag(.undef),

            .int_unsigned, .int_signed => {
                if (ty.cast(Payload.Bits).?.data == 0) {
                    return Value.zero;
                } else {
                    return null;
                }
            },
            .vector, .array, .array_u8 => {
                if (ty.arrayLen() == 0)
                    return Value.initTag(.empty_array);
                if (ty.elemType().onePossibleValue() != null)
                    return Value.initTag(.the_only_possible_value);
                return null;
            },

            .inferred_alloc_const => unreachable,
            .inferred_alloc_mut => unreachable,
            .generic_poison => unreachable,
        };
    }

    /// During semantic analysis, instead call `Sema.typeRequiresComptime` which
    /// resolves field types rather than asserting they are already resolved.
    /// TODO merge these implementations together with the "advanced" pattern seen
    /// elsewhere in this file.
    pub fn comptimeOnly(ty: Type) bool {
        return switch (ty.tag()) {
            .u1,
            .u8,
            .i8,
            .u16,
            .i16,
            .u29,
            .u32,
            .i32,
            .u64,
            .i64,
            .u128,
            .i128,
            .usize,
            .isize,
            .c_short,
            .c_ushort,
            .c_int,
            .c_uint,
            .c_long,
            .c_ulong,
            .c_longlong,
            .c_ulonglong,
            .c_longdouble,
            .f16,
            .f32,
            .f64,
            .f80,
            .f128,
            .anyopaque,
            .bool,
            .void,
            .anyerror,
            .noreturn,
            .@"anyframe",
            .@"null",
            .@"undefined",
            .atomic_order,
            .atomic_rmw_op,
            .calling_convention,
            .address_space,
            .float_mode,
            .reduce_op,
            .call_options,
            .prefetch_options,
            .export_options,
            .extern_options,
            .manyptr_u8,
            .manyptr_const_u8,
            .manyptr_const_u8_sentinel_0,
            .const_slice_u8,
            .const_slice_u8_sentinel_0,
            .anyerror_void_error_union,
            .empty_struct_literal,
            .empty_struct,
            .error_set,
            .error_set_single,
            .error_set_inferred,
            .error_set_merged,
            .@"opaque",
            .generic_poison,
            .array_u8,
            .array_u8_sentinel_0,
            .int_signed,
            .int_unsigned,
            .enum_simple,
            => false,

            .single_const_pointer_to_comptime_int,
            .type,
            .comptime_int,
            .comptime_float,
            .enum_literal,
            .type_info,
            // These are function bodies, not function pointers.
            .fn_noreturn_no_args,
            .fn_void_no_args,
            .fn_naked_noreturn_no_args,
            .fn_ccc_void_no_args,
            .function,
            => true,

            .var_args_param => unreachable,
            .inferred_alloc_mut => unreachable,
            .inferred_alloc_const => unreachable,
            .bound_fn => unreachable,

            .array,
            .array_sentinel,
            .vector,
            => return ty.childType().comptimeOnly(),

            .pointer,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            => {
                const child_ty = ty.childType();
                if (child_ty.zigTypeTag() == .Fn) {
                    return false;
                } else {
                    return child_ty.comptimeOnly();
                }
            },

            .optional,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            => {
                var buf: Type.Payload.ElemType = undefined;
                return ty.optionalChild(&buf).comptimeOnly();
            },

            .tuple, .anon_struct => {
                const tuple = ty.tupleFields();
                for (tuple.types) |field_ty, i| {
                    const have_comptime_val = tuple.values[i].tag() != .unreachable_value;
                    if (!have_comptime_val and field_ty.comptimeOnly()) return true;
                }
                return false;
            },

            .@"struct" => {
                const struct_obj = ty.castTag(.@"struct").?.data;
                switch (struct_obj.requires_comptime) {
                    .wip, .unknown => unreachable, // This function asserts types already resolved.
                    .no => return false,
                    .yes => return true,
                }
            },

            .@"union", .union_tagged => {
                const union_obj = ty.cast(Type.Payload.Union).?.data;
                switch (union_obj.requires_comptime) {
                    .wip, .unknown => unreachable, // This function asserts types already resolved.
                    .no => return false,
                    .yes => return true,
                }
            },

            .error_union => return ty.errorUnionPayload().comptimeOnly(),
            .anyframe_T => {
                const child_ty = ty.castTag(.anyframe_T).?.data;
                return child_ty.comptimeOnly();
            },
            .enum_numbered => {
                const tag_ty = ty.castTag(.enum_numbered).?.data.tag_ty;
                return tag_ty.comptimeOnly();
            },
            .enum_full, .enum_nonexhaustive => {
                const tag_ty = ty.cast(Type.Payload.EnumFull).?.data.tag_ty;
                return tag_ty.comptimeOnly();
            },
        };
    }

    pub fn isArrayOrVector(ty: Type) bool {
        return switch (ty.zigTypeTag()) {
            .Array, .Vector => true,
            else => false,
        };
    }

    pub fn isIndexable(ty: Type) bool {
        return switch (ty.zigTypeTag()) {
            .Array, .Vector => true,
            .Pointer => switch (ty.ptrSize()) {
                .Slice, .Many, .C => true,
                .One => ty.elemType().zigTypeTag() == .Array,
            },
            .Struct => ty.isTuple(),
            else => false,
        };
    }

    /// Returns null if the type has no namespace.
    pub fn getNamespace(self: Type) ?*Module.Namespace {
        return switch (self.tag()) {
            .@"struct" => &self.castTag(.@"struct").?.data.namespace,
            .enum_full => &self.castTag(.enum_full).?.data.namespace,
            .enum_nonexhaustive => &self.castTag(.enum_nonexhaustive).?.data.namespace,
            .empty_struct => self.castTag(.empty_struct).?.data,
            .@"opaque" => &self.castTag(.@"opaque").?.data.namespace,
            .@"union" => &self.castTag(.@"union").?.data.namespace,
            .union_tagged => &self.castTag(.union_tagged).?.data.namespace,

            else => null,
        };
    }

    /// Asserts that self.zigTypeTag() == .Int.
    pub fn minInt(self: Type, arena: Allocator, target: Target) !Value {
        assert(self.zigTypeTag() == .Int);
        const info = self.intInfo(target);

        if (info.signedness == .unsigned) {
            return Value.zero;
        }

        if (info.bits <= 6) {
            const n: i64 = -(@as(i64, 1) << @truncate(u6, info.bits - 1));
            return Value.Tag.int_i64.create(arena, n);
        }

        var res = try std.math.big.int.Managed.init(arena);
        try res.setTwosCompIntLimit(.min, info.signedness, info.bits);

        const res_const = res.toConst();
        if (res_const.positive) {
            return Value.Tag.int_big_positive.create(arena, res_const.limbs);
        } else {
            return Value.Tag.int_big_negative.create(arena, res_const.limbs);
        }
    }

    /// Asserts that self.zigTypeTag() == .Int.
    pub fn maxInt(self: Type, arena: Allocator, target: Target) !Value {
        assert(self.zigTypeTag() == .Int);
        const info = self.intInfo(target);

        if (info.bits <= 6) switch (info.signedness) {
            .signed => {
                const n: i64 = (@as(i64, 1) << @truncate(u6, info.bits - 1)) - 1;
                return Value.Tag.int_i64.create(arena, n);
            },
            .unsigned => {
                const n: u64 = (@as(u64, 1) << @truncate(u6, info.bits)) - 1;
                return Value.Tag.int_u64.create(arena, n);
            },
        };

        var res = try std.math.big.int.Managed.init(arena);
        try res.setTwosCompIntLimit(.max, info.signedness, info.bits);

        const res_const = res.toConst();
        if (res_const.positive) {
            return Value.Tag.int_big_positive.create(arena, res_const.limbs);
        } else {
            return Value.Tag.int_big_negative.create(arena, res_const.limbs);
        }
    }

    /// Asserts the type is an enum or a union.
    /// TODO support unions
    pub fn intTagType(ty: Type, buffer: *Payload.Bits) Type {
        switch (ty.tag()) {
            .enum_full, .enum_nonexhaustive => return ty.cast(Payload.EnumFull).?.data.tag_ty,
            .enum_numbered => return ty.castTag(.enum_numbered).?.data.tag_ty,
            .enum_simple => {
                const enum_simple = ty.castTag(.enum_simple).?.data;
                const bits = std.math.log2_int_ceil(usize, enum_simple.fields.count());
                buffer.* = .{
                    .base = .{ .tag = .int_unsigned },
                    .data = bits,
                };
                return Type.initPayload(&buffer.base);
            },
            .union_tagged => return ty.castTag(.union_tagged).?.data.tag_ty.intTagType(buffer),
            else => unreachable,
        }
    }

    pub fn isNonexhaustiveEnum(ty: Type) bool {
        return switch (ty.tag()) {
            .enum_nonexhaustive => true,
            else => false,
        };
    }

    // Asserts that `ty` is an error set and not `anyerror`.
    pub fn errorSetNames(ty: Type) []const []const u8 {
        return switch (ty.tag()) {
            .error_set_single => blk: {
                // Work around coercion problems
                const tmp: *const [1][]const u8 = &ty.castTag(.error_set_single).?.data;
                break :blk tmp;
            },
            .error_set_merged => ty.castTag(.error_set_merged).?.data.keys(),
            .error_set => ty.castTag(.error_set).?.data.names.keys(),
            .error_set_inferred => {
                const inferred_error_set = ty.castTag(.error_set_inferred).?.data;
                assert(inferred_error_set.is_resolved);
                assert(!inferred_error_set.is_anyerror);
                return inferred_error_set.errors.keys();
            },
            else => unreachable,
        };
    }

    /// Merge lhs with rhs.
    /// Asserts that lhs and rhs are both error sets and are resolved.
    pub fn errorSetMerge(lhs: Type, arena: Allocator, rhs: Type) !Type {
        const lhs_names = lhs.errorSetNames();
        const rhs_names = rhs.errorSetNames();
        var names: Module.ErrorSet.NameMap = .{};
        try names.ensureUnusedCapacity(arena, lhs_names.len);
        for (lhs_names) |name| {
            names.putAssumeCapacityNoClobber(name, {});
        }
        for (rhs_names) |name| {
            try names.put(arena, name, {});
        }

        // names must be sorted
        Module.ErrorSet.sortNames(&names);

        return try Tag.error_set_merged.create(arena, names);
    }

    pub fn enumFields(ty: Type) Module.EnumFull.NameMap {
        return switch (ty.tag()) {
            .enum_full, .enum_nonexhaustive => ty.cast(Payload.EnumFull).?.data.fields,
            .enum_simple => ty.castTag(.enum_simple).?.data.fields,
            .enum_numbered => ty.castTag(.enum_numbered).?.data.fields,
            .atomic_order,
            .atomic_rmw_op,
            .calling_convention,
            .address_space,
            .float_mode,
            .reduce_op,
            .call_options,
            .prefetch_options,
            .export_options,
            .extern_options,
            => @panic("TODO resolve std.builtin types"),
            else => unreachable,
        };
    }

    pub fn enumFieldCount(ty: Type) usize {
        return ty.enumFields().count();
    }

    pub fn enumFieldName(ty: Type, field_index: usize) []const u8 {
        return ty.enumFields().keys()[field_index];
    }

    pub fn enumFieldIndex(ty: Type, field_name: []const u8) ?usize {
        return ty.enumFields().getIndex(field_name);
    }

    /// Asserts `ty` is an enum. `enum_tag` can either be `enum_field_index` or
    /// an integer which represents the enum value. Returns the field index in
    /// declaration order, or `null` if `enum_tag` does not match any field.
    pub fn enumTagFieldIndex(ty: Type, enum_tag: Value, mod: *Module) ?usize {
        if (enum_tag.castTag(.enum_field_index)) |payload| {
            return @as(usize, payload.data);
        }
        const S = struct {
            fn fieldWithRange(int_ty: Type, int_val: Value, end: usize, m: *Module) ?usize {
                if (int_val.compareWithZero(.lt)) return null;
                var end_payload: Value.Payload.U64 = .{
                    .base = .{ .tag = .int_u64 },
                    .data = end,
                };
                const end_val = Value.initPayload(&end_payload.base);
                if (int_val.compare(.gte, end_val, int_ty, m)) return null;
                return @intCast(usize, int_val.toUnsignedInt(m.getTarget()));
            }
        };
        switch (ty.tag()) {
            .enum_full, .enum_nonexhaustive => {
                const enum_full = ty.cast(Payload.EnumFull).?.data;
                const tag_ty = enum_full.tag_ty;
                if (enum_full.values.count() == 0) {
                    return S.fieldWithRange(tag_ty, enum_tag, enum_full.fields.count(), mod);
                } else {
                    return enum_full.values.getIndexContext(enum_tag, .{
                        .ty = tag_ty,
                        .mod = mod,
                    });
                }
            },
            .enum_numbered => {
                const enum_obj = ty.castTag(.enum_numbered).?.data;
                const tag_ty = enum_obj.tag_ty;
                if (enum_obj.values.count() == 0) {
                    return S.fieldWithRange(tag_ty, enum_tag, enum_obj.fields.count(), mod);
                } else {
                    return enum_obj.values.getIndexContext(enum_tag, .{
                        .ty = tag_ty,
                        .mod = mod,
                    });
                }
            },
            .enum_simple => {
                const enum_simple = ty.castTag(.enum_simple).?.data;
                const fields_len = enum_simple.fields.count();
                const bits = std.math.log2_int_ceil(usize, fields_len);
                var buffer: Payload.Bits = .{
                    .base = .{ .tag = .int_unsigned },
                    .data = bits,
                };
                const tag_ty = Type.initPayload(&buffer.base);
                return S.fieldWithRange(tag_ty, enum_tag, fields_len, mod);
            },
            .atomic_order,
            .atomic_rmw_op,
            .calling_convention,
            .address_space,
            .float_mode,
            .reduce_op,
            .call_options,
            .prefetch_options,
            .export_options,
            .extern_options,
            => @panic("TODO resolve std.builtin types"),
            else => unreachable,
        }
    }

    pub fn structFields(ty: Type) Module.Struct.Fields {
        switch (ty.tag()) {
            .empty_struct, .empty_struct_literal => return .{},
            .@"struct" => {
                const struct_obj = ty.castTag(.@"struct").?.data;
                assert(struct_obj.haveFieldTypes());
                return struct_obj.fields;
            },
            else => unreachable,
        }
    }

    pub fn structFieldName(ty: Type, field_index: usize) []const u8 {
        switch (ty.tag()) {
            .@"struct" => {
                const struct_obj = ty.castTag(.@"struct").?.data;
                assert(struct_obj.haveFieldTypes());
                return struct_obj.fields.keys()[field_index];
            },
            .anon_struct => return ty.castTag(.anon_struct).?.data.names[field_index],
            else => unreachable,
        }
    }

    pub fn structFieldCount(ty: Type) usize {
        switch (ty.tag()) {
            .@"struct" => {
                const struct_obj = ty.castTag(.@"struct").?.data;
                assert(struct_obj.haveFieldTypes());
                return struct_obj.fields.count();
            },
            .empty_struct, .empty_struct_literal => return 0,
            .tuple => return ty.castTag(.tuple).?.data.types.len,
            .anon_struct => return ty.castTag(.anon_struct).?.data.types.len,
            else => unreachable,
        }
    }

    /// Supports structs and unions.
    pub fn structFieldType(ty: Type, index: usize) Type {
        switch (ty.tag()) {
            .@"struct" => {
                const struct_obj = ty.castTag(.@"struct").?.data;
                return struct_obj.fields.values()[index].ty;
            },
            .@"union", .union_tagged => {
                const union_obj = ty.cast(Payload.Union).?.data;
                return union_obj.fields.values()[index].ty;
            },
            .tuple => return ty.castTag(.tuple).?.data.types[index],
            .anon_struct => return ty.castTag(.anon_struct).?.data.types[index],
            else => unreachable,
        }
    }

    pub fn structFieldAlign(ty: Type, index: usize, target: Target) u32 {
        switch (ty.tag()) {
            .@"struct" => {
                const struct_obj = ty.castTag(.@"struct").?.data;
                assert(struct_obj.layout != .Packed);
                return struct_obj.fields.values()[index].normalAlignment(target);
            },
            .@"union", .union_tagged => {
                const union_obj = ty.cast(Payload.Union).?.data;
                return union_obj.fields.values()[index].normalAlignment(target);
            },
            .tuple => return ty.castTag(.tuple).?.data.types[index].abiAlignment(target),
            .anon_struct => return ty.castTag(.anon_struct).?.data.types[index].abiAlignment(target),
            else => unreachable,
        }
    }

    pub fn structFieldDefaultValue(ty: Type, index: usize) Value {
        switch (ty.tag()) {
            .@"struct" => {
                const struct_obj = ty.castTag(.@"struct").?.data;
                return struct_obj.fields.values()[index].default_val;
            },
            .tuple => {
                const tuple = ty.castTag(.tuple).?.data;
                return tuple.values[index];
            },
            .anon_struct => {
                const struct_obj = ty.castTag(.anon_struct).?.data;
                return struct_obj.values[index];
            },
            else => unreachable,
        }
    }

    pub fn structFieldValueComptime(ty: Type, index: usize) ?Value {
        switch (ty.tag()) {
            .@"struct" => {
                const struct_obj = ty.castTag(.@"struct").?.data;
                assert(struct_obj.layout != .Packed);
                const field = struct_obj.fields.values()[index];
                if (field.is_comptime) {
                    return field.default_val;
                } else {
                    return field.ty.onePossibleValue();
                }
            },
            .tuple => {
                const tuple = ty.castTag(.tuple).?.data;
                const val = tuple.values[index];
                if (val.tag() == .unreachable_value) {
                    return tuple.types[index].onePossibleValue();
                } else {
                    return val;
                }
            },
            .anon_struct => {
                const anon_struct = ty.castTag(.anon_struct).?.data;
                const val = anon_struct.values[index];
                if (val.tag() == .unreachable_value) {
                    return anon_struct.types[index].onePossibleValue();
                } else {
                    return val;
                }
            },
            else => unreachable,
        }
    }

    pub fn packedStructFieldByteOffset(ty: Type, field_index: usize, target: Target) u32 {
        const struct_obj = ty.castTag(.@"struct").?.data;
        assert(struct_obj.layout == .Packed);
        comptime assert(Type.packed_struct_layout_version == 2);

        var bit_offset: u16 = undefined;
        var elem_size_bits: u16 = undefined;
        var running_bits: u16 = 0;
        for (struct_obj.fields.values()) |f, i| {
            if (!f.ty.hasRuntimeBits()) continue;

            const field_bits = @intCast(u16, f.ty.bitSize(target));
            if (i == field_index) {
                bit_offset = running_bits;
                elem_size_bits = field_bits;
            }
            running_bits += field_bits;
        }
        const byte_offset = bit_offset / 8;
        return byte_offset;
    }

    pub const FieldOffset = struct {
        field: usize,
        offset: u64,
    };

    pub const StructOffsetIterator = struct {
        field: usize = 0,
        offset: u64 = 0,
        big_align: u32 = 0,
        struct_obj: *Module.Struct,
        target: Target,

        pub fn next(it: *StructOffsetIterator) ?FieldOffset {
            if (it.struct_obj.fields.count() <= it.field)
                return null;

            const field = it.struct_obj.fields.values()[it.field];
            defer it.field += 1;
            if (!field.ty.hasRuntimeBits() or field.is_comptime)
                return FieldOffset{ .field = it.field, .offset = it.offset };

            const field_align = field.normalAlignment(it.target);
            it.big_align = @maximum(it.big_align, field_align);
            it.offset = std.mem.alignForwardGeneric(u64, it.offset, field_align);
            defer it.offset += field.ty.abiSize(it.target);
            return FieldOffset{ .field = it.field, .offset = it.offset };
        }
    };

    /// Get an iterator that iterates over all the struct field, returning the field and
    /// offset of that field. Asserts that the type is a non-packed struct.
    pub fn iterateStructOffsets(ty: Type, target: Target) StructOffsetIterator {
        const struct_obj = ty.castTag(.@"struct").?.data;
        assert(struct_obj.haveLayout());
        assert(struct_obj.layout != .Packed);
        return .{ .struct_obj = struct_obj, .target = target };
    }

    /// Supports structs and unions.
    pub fn structFieldOffset(ty: Type, index: usize, target: Target) u64 {
        switch (ty.tag()) {
            .@"struct" => {
                const struct_obj = ty.castTag(.@"struct").?.data;
                assert(struct_obj.haveLayout());
                assert(struct_obj.layout != .Packed);
                var it = ty.iterateStructOffsets(target);
                while (it.next()) |field_offset| {
                    if (index == field_offset.field)
                        return field_offset.offset;
                }

                return std.mem.alignForwardGeneric(u64, it.offset, @maximum(it.big_align, 1));
            },

            .tuple, .anon_struct => {
                const tuple = ty.tupleFields();

                var offset: u64 = 0;
                var big_align: u32 = 0;

                for (tuple.types) |field_ty, i| {
                    const field_val = tuple.values[i];
                    if (field_val.tag() != .unreachable_value) {
                        // comptime field
                        if (i == index) return offset;
                        continue;
                    }

                    const field_align = field_ty.abiAlignment(target);
                    big_align = @maximum(big_align, field_align);
                    offset = std.mem.alignForwardGeneric(u64, offset, field_align);
                    if (i == index) return offset;
                    offset += field_ty.abiSize(target);
                }
                offset = std.mem.alignForwardGeneric(u64, offset, @maximum(big_align, 1));
                return offset;
            },

            .@"union" => return 0,
            .union_tagged => {
                const union_obj = ty.castTag(.union_tagged).?.data;
                const layout = union_obj.getLayout(target, true);
                if (layout.tag_align >= layout.payload_align) {
                    // {Tag, Payload}
                    return std.mem.alignForwardGeneric(u64, layout.tag_size, layout.payload_align);
                } else {
                    // {Payload, Tag}
                    return 0;
                }
            },
            else => unreachable,
        }
    }

    pub fn declSrcLoc(ty: Type, mod: *Module) Module.SrcLoc {
        return declSrcLocOrNull(ty, mod).?;
    }

    pub fn declSrcLocOrNull(ty: Type, mod: *Module) ?Module.SrcLoc {
        switch (ty.tag()) {
            .enum_full, .enum_nonexhaustive => {
                const enum_full = ty.cast(Payload.EnumFull).?.data;
                return enum_full.srcLoc(mod);
            },
            .enum_numbered => {
                const enum_numbered = ty.castTag(.enum_numbered).?.data;
                return enum_numbered.srcLoc(mod);
            },
            .enum_simple => {
                const enum_simple = ty.castTag(.enum_simple).?.data;
                return enum_simple.srcLoc(mod);
            },
            .@"struct" => {
                const struct_obj = ty.castTag(.@"struct").?.data;
                return struct_obj.srcLoc(mod);
            },
            .error_set => {
                const error_set = ty.castTag(.error_set).?.data;
                return error_set.srcLoc(mod);
            },
            .@"union", .union_tagged => {
                const union_obj = ty.cast(Payload.Union).?.data;
                return union_obj.srcLoc(mod);
            },
            .atomic_order,
            .atomic_rmw_op,
            .calling_convention,
            .address_space,
            .float_mode,
            .reduce_op,
            .call_options,
            .prefetch_options,
            .export_options,
            .extern_options,
            .type_info,
            => unreachable, // needed to call resolveTypeFields first

            else => return null,
        }
    }

    pub fn getOwnerDecl(ty: Type) Module.Decl.Index {
        switch (ty.tag()) {
            .enum_full, .enum_nonexhaustive => {
                const enum_full = ty.cast(Payload.EnumFull).?.data;
                return enum_full.owner_decl;
            },
            .enum_numbered => return ty.castTag(.enum_numbered).?.data.owner_decl,
            .enum_simple => {
                const enum_simple = ty.castTag(.enum_simple).?.data;
                return enum_simple.owner_decl;
            },
            .@"struct" => {
                const struct_obj = ty.castTag(.@"struct").?.data;
                return struct_obj.owner_decl;
            },
            .error_set => {
                const error_set = ty.castTag(.error_set).?.data;
                return error_set.owner_decl;
            },
            .@"union", .union_tagged => {
                const union_obj = ty.cast(Payload.Union).?.data;
                return union_obj.owner_decl;
            },
            .@"opaque" => {
                const opaque_obj = ty.cast(Payload.Opaque).?.data;
                return opaque_obj.owner_decl;
            },
            .atomic_order,
            .atomic_rmw_op,
            .calling_convention,
            .address_space,
            .float_mode,
            .reduce_op,
            .call_options,
            .prefetch_options,
            .export_options,
            .extern_options,
            .type_info,
            => unreachable, // These need to be resolved earlier.

            else => unreachable,
        }
    }

    pub fn getNodeOffset(ty: Type) i32 {
        switch (ty.tag()) {
            .enum_full, .enum_nonexhaustive => {
                const enum_full = ty.cast(Payload.EnumFull).?.data;
                return enum_full.node_offset;
            },
            .enum_numbered => return ty.castTag(.enum_numbered).?.data.node_offset,
            .enum_simple => {
                const enum_simple = ty.castTag(.enum_simple).?.data;
                return enum_simple.node_offset;
            },
            .@"struct" => {
                const struct_obj = ty.castTag(.@"struct").?.data;
                return struct_obj.node_offset;
            },
            .error_set => {
                const error_set = ty.castTag(.error_set).?.data;
                return error_set.node_offset;
            },
            .@"union", .union_tagged => {
                const union_obj = ty.cast(Payload.Union).?.data;
                return union_obj.node_offset;
            },
            .@"opaque" => {
                const opaque_obj = ty.cast(Payload.Opaque).?.data;
                return opaque_obj.node_offset;
            },
            .atomic_order,
            .atomic_rmw_op,
            .calling_convention,
            .address_space,
            .float_mode,
            .reduce_op,
            .call_options,
            .prefetch_options,
            .export_options,
            .extern_options,
            .type_info,
            => unreachable, // These need to be resolved earlier.

            else => unreachable,
        }
    }

    /// This enum does not directly correspond to `std.builtin.TypeId` because
    /// it has extra enum tags in it, as a way of using less memory. For example,
    /// even though Zig recognizes `*align(10) i32` and `*i32` both as Pointer types
    /// but with different alignment values, in this data structure they are represented
    /// with different enum tags, because the the former requires more payload data than the latter.
    /// See `zigTypeTag` for the function that corresponds to `std.builtin.TypeId`.
    pub const Tag = enum(usize) {
        // The first section of this enum are tags that require no payload.
        u1,
        u8,
        i8,
        u16,
        i16,
        u29,
        u32,
        i32,
        u64,
        i64,
        u128,
        i128,
        usize,
        isize,
        c_short,
        c_ushort,
        c_int,
        c_uint,
        c_long,
        c_ulong,
        c_longlong,
        c_ulonglong,
        c_longdouble,
        f16,
        f32,
        f64,
        f80,
        f128,
        anyopaque,
        bool,
        void,
        type,
        anyerror,
        comptime_int,
        comptime_float,
        noreturn,
        @"anyframe",
        @"null",
        @"undefined",
        enum_literal,
        atomic_order,
        atomic_rmw_op,
        calling_convention,
        address_space,
        float_mode,
        reduce_op,
        call_options,
        prefetch_options,
        export_options,
        extern_options,
        type_info,
        manyptr_u8,
        manyptr_const_u8,
        manyptr_const_u8_sentinel_0,
        fn_noreturn_no_args,
        fn_void_no_args,
        fn_naked_noreturn_no_args,
        fn_ccc_void_no_args,
        single_const_pointer_to_comptime_int,
        const_slice_u8,
        const_slice_u8_sentinel_0,
        anyerror_void_error_union,
        generic_poison,
        /// This is a special type for variadic parameters of a function call.
        /// Casts to it will validate that the type can be passed to a c calling convention function.
        var_args_param,
        /// Same as `empty_struct` except it has an empty namespace.
        empty_struct_literal,
        /// This is a special value that tracks a set of types that have been stored
        /// to an inferred allocation. It does not support most of the normal type queries.
        /// However it does respond to `isConstPtr`, `ptrSize`, `zigTypeTag`, etc.
        inferred_alloc_mut,
        /// Same as `inferred_alloc_mut` but the local is `var` not `const`.
        inferred_alloc_const, // See last_no_payload_tag below.
        bound_fn,
        // After this, the tag requires a payload.

        array_u8,
        array_u8_sentinel_0,
        array,
        array_sentinel,
        vector,
        /// Possible Value tags for this: @"struct"
        tuple,
        /// Possible Value tags for this: @"struct"
        anon_struct,
        pointer,
        single_const_pointer,
        single_mut_pointer,
        many_const_pointer,
        many_mut_pointer,
        c_const_pointer,
        c_mut_pointer,
        const_slice,
        mut_slice,
        int_signed,
        int_unsigned,
        function,
        optional,
        optional_single_mut_pointer,
        optional_single_const_pointer,
        error_union,
        anyframe_T,
        error_set,
        error_set_single,
        /// The type is the inferred error set of a specific function.
        error_set_inferred,
        error_set_merged,
        empty_struct,
        @"opaque",
        @"struct",
        @"union",
        union_tagged,
        enum_simple,
        enum_numbered,
        enum_full,
        enum_nonexhaustive,

        pub const last_no_payload_tag = Tag.bound_fn;
        pub const no_payload_count = @enumToInt(last_no_payload_tag) + 1;

        pub fn Type(comptime t: Tag) type {
            // Keep in sync with tools/zig-gdb.py
            return switch (t) {
                .u1,
                .u8,
                .i8,
                .u16,
                .i16,
                .u29,
                .u32,
                .i32,
                .u64,
                .i64,
                .u128,
                .i128,
                .usize,
                .isize,
                .c_short,
                .c_ushort,
                .c_int,
                .c_uint,
                .c_long,
                .c_ulong,
                .c_longlong,
                .c_ulonglong,
                .c_longdouble,
                .f16,
                .f32,
                .f64,
                .f80,
                .f128,
                .anyopaque,
                .bool,
                .void,
                .type,
                .anyerror,
                .comptime_int,
                .comptime_float,
                .noreturn,
                .enum_literal,
                .@"null",
                .@"undefined",
                .fn_noreturn_no_args,
                .fn_void_no_args,
                .fn_naked_noreturn_no_args,
                .fn_ccc_void_no_args,
                .single_const_pointer_to_comptime_int,
                .anyerror_void_error_union,
                .const_slice_u8,
                .const_slice_u8_sentinel_0,
                .generic_poison,
                .inferred_alloc_const,
                .inferred_alloc_mut,
                .var_args_param,
                .empty_struct_literal,
                .manyptr_u8,
                .manyptr_const_u8,
                .manyptr_const_u8_sentinel_0,
                .atomic_order,
                .atomic_rmw_op,
                .calling_convention,
                .address_space,
                .float_mode,
                .reduce_op,
                .call_options,
                .prefetch_options,
                .export_options,
                .extern_options,
                .type_info,
                .@"anyframe",
                .bound_fn,
                => @compileError("Type Tag " ++ @tagName(t) ++ " has no payload"),

                .array_u8,
                .array_u8_sentinel_0,
                => Payload.Len,

                .single_const_pointer,
                .single_mut_pointer,
                .many_const_pointer,
                .many_mut_pointer,
                .c_const_pointer,
                .c_mut_pointer,
                .const_slice,
                .mut_slice,
                .optional,
                .optional_single_mut_pointer,
                .optional_single_const_pointer,
                .anyframe_T,
                => Payload.ElemType,

                .int_signed,
                .int_unsigned,
                => Payload.Bits,

                .error_set => Payload.ErrorSet,
                .error_set_inferred => Payload.ErrorSetInferred,
                .error_set_merged => Payload.ErrorSetMerged,

                .array, .vector => Payload.Array,
                .array_sentinel => Payload.ArraySentinel,
                .pointer => Payload.Pointer,
                .function => Payload.Function,
                .error_union => Payload.ErrorUnion,
                .error_set_single => Payload.Name,
                .@"opaque" => Payload.Opaque,
                .@"struct" => Payload.Struct,
                .@"union", .union_tagged => Payload.Union,
                .enum_full, .enum_nonexhaustive => Payload.EnumFull,
                .enum_simple => Payload.EnumSimple,
                .enum_numbered => Payload.EnumNumbered,
                .empty_struct => Payload.ContainerScope,
                .tuple => Payload.Tuple,
                .anon_struct => Payload.AnonStruct,
            };
        }

        pub fn init(comptime t: Tag) file_struct.Type {
            comptime std.debug.assert(@enumToInt(t) < Tag.no_payload_count);
            return .{ .tag_if_small_enough = t };
        }

        pub fn create(comptime t: Tag, ally: Allocator, data: Data(t)) error{OutOfMemory}!file_struct.Type {
            const p = try ally.create(t.Type());
            p.* = .{
                .base = .{ .tag = t },
                .data = data,
            };
            return file_struct.Type{ .ptr_otherwise = &p.base };
        }

        pub fn Data(comptime t: Tag) type {
            return std.meta.fieldInfo(t.Type(), .data).field_type;
        }
    };

    pub fn isTuple(ty: Type) bool {
        return switch (ty.tag()) {
            .tuple, .empty_struct_literal => true,
            else => false,
        };
    }

    pub fn isAnonStruct(ty: Type) bool {
        return switch (ty.tag()) {
            .anon_struct, .empty_struct_literal => true,
            else => false,
        };
    }

    pub fn isTupleOrAnonStruct(ty: Type) bool {
        return switch (ty.tag()) {
            .tuple, .empty_struct_literal, .anon_struct => true,
            else => false,
        };
    }

    pub fn tupleFields(ty: Type) Payload.Tuple.Data {
        return switch (ty.tag()) {
            .tuple => ty.castTag(.tuple).?.data,
            .anon_struct => .{
                .types = ty.castTag(.anon_struct).?.data.types,
                .values = ty.castTag(.anon_struct).?.data.values,
            },
            .empty_struct_literal => .{ .types = &.{}, .values = &.{} },
            else => unreachable,
        };
    }

    /// The sub-types are named after what fields they contain.
    pub const Payload = struct {
        tag: Tag,

        pub const Len = struct {
            base: Payload,
            data: u64,
        };

        pub const Array = struct {
            base: Payload,
            data: struct {
                len: u64,
                elem_type: Type,
            },
        };

        pub const ArraySentinel = struct {
            pub const base_tag = Tag.array_sentinel;

            base: Payload = Payload{ .tag = base_tag },
            data: struct {
                len: u64,
                sentinel: Value,
                elem_type: Type,
            },
        };

        pub const ElemType = struct {
            base: Payload,
            data: Type,
        };

        pub const Bits = struct {
            base: Payload,
            data: u16,
        };

        pub const Function = struct {
            pub const base_tag = Tag.function;

            base: Payload = Payload{ .tag = base_tag },
            data: Data,

            // TODO look into optimizing this memory to take fewer bytes
            pub const Data = struct {
                param_types: []Type,
                comptime_params: [*]bool,
                return_type: Type,
                /// If zero use default target function code alignment.
                alignment: u32,
                noalias_bits: u32,
                cc: std.builtin.CallingConvention,
                is_var_args: bool,
                is_generic: bool,
                align_is_generic: bool,
                cc_is_generic: bool,
                section_is_generic: bool,
                addrspace_is_generic: bool,

                pub fn paramIsComptime(self: @This(), i: usize) bool {
                    assert(i < self.param_types.len);
                    return self.comptime_params[i];
                }
            };
        };

        pub const ErrorSet = struct {
            pub const base_tag = Tag.error_set;

            base: Payload = Payload{ .tag = base_tag },
            data: *Module.ErrorSet,
        };

        pub const ErrorSetMerged = struct {
            pub const base_tag = Tag.error_set_merged;

            base: Payload = Payload{ .tag = base_tag },
            data: Module.ErrorSet.NameMap,
        };

        pub const ErrorSetInferred = struct {
            pub const base_tag = Tag.error_set_inferred;

            base: Payload = Payload{ .tag = base_tag },
            data: *Module.Fn.InferredErrorSet,
        };

        pub const Pointer = struct {
            pub const base_tag = Tag.pointer;

            base: Payload = Payload{ .tag = base_tag },
            data: Data,

            pub const Data = struct {
                pointee_type: Type,
                sentinel: ?Value = null,
                /// If zero use pointee_type.abiAlignment()
                /// When creating pointer types, if alignment is equal to pointee type
                /// abi alignment, this value should be set to 0 instead.
                @"align": u32 = 0,
                /// See src/target.zig defaultAddressSpace function for how to obtain
                /// an appropriate value for this field.
                @"addrspace": std.builtin.AddressSpace,
                bit_offset: u16 = 0,
                /// If this is non-zero it means the pointer points to a sub-byte
                /// range of data, which is backed by a "host integer" with this
                /// number of bytes.
                /// When host_size=pointee_abi_size and bit_offset=0, this must be
                /// represented with host_size=0 instead.
                host_size: u16 = 0,
                @"allowzero": bool = false,
                mutable: bool = true, // TODO rename this to const, not mutable
                @"volatile": bool = false,
                size: std.builtin.Type.Pointer.Size = .One,
            };
        };

        pub const ErrorUnion = struct {
            pub const base_tag = Tag.error_union;

            base: Payload = Payload{ .tag = base_tag },
            data: struct {
                error_set: Type,
                payload: Type,
            },
        };

        pub const Decl = struct {
            base: Payload,
            data: *Module.Decl,
        };

        pub const Name = struct {
            base: Payload,
            /// memory is owned by `Module`
            data: []const u8,
        };

        /// Mostly used for namespace like structs with zero fields.
        /// Most commonly used for files.
        pub const ContainerScope = struct {
            base: Payload,
            data: *Module.Namespace,
        };

        pub const Opaque = struct {
            base: Payload = .{ .tag = .@"opaque" },
            data: *Module.Opaque,
        };

        pub const Struct = struct {
            base: Payload = .{ .tag = .@"struct" },
            data: *Module.Struct,
        };

        pub const Tuple = struct {
            base: Payload = .{ .tag = .tuple },
            data: Data,

            pub const Data = struct {
                types: []Type,
                /// unreachable_value elements are used to indicate runtime-known.
                values: []Value,
            };
        };

        pub const AnonStruct = struct {
            base: Payload = .{ .tag = .anon_struct },
            data: Data,

            pub const Data = struct {
                names: []const []const u8,
                types: []Type,
                /// unreachable_value elements are used to indicate runtime-known.
                values: []Value,
            };
        };

        pub const Union = struct {
            base: Payload,
            data: *Module.Union,
        };

        pub const EnumFull = struct {
            base: Payload,
            data: *Module.EnumFull,
        };

        pub const EnumSimple = struct {
            base: Payload = .{ .tag = .enum_simple },
            data: *Module.EnumSimple,
        };

        pub const EnumNumbered = struct {
            base: Payload = .{ .tag = .enum_numbered },
            data: *Module.EnumNumbered,
        };
    };

    pub const @"u1" = initTag(.u1);
    pub const @"u8" = initTag(.u8);
    pub const @"u16" = initTag(.u16);
    pub const @"u29" = initTag(.u29);
    pub const @"u32" = initTag(.u32);
    pub const @"u64" = initTag(.u64);

    pub const @"i32" = initTag(.i32);
    pub const @"i64" = initTag(.i64);

    pub const @"f16" = initTag(.f16);
    pub const @"f32" = initTag(.f32);
    pub const @"f64" = initTag(.f64);
    pub const @"f80" = initTag(.f80);
    pub const @"f128" = initTag(.f128);

    pub const @"bool" = initTag(.bool);
    pub const @"usize" = initTag(.usize);
    pub const @"isize" = initTag(.isize);
    pub const @"comptime_int" = initTag(.comptime_int);
    pub const @"void" = initTag(.void);
    pub const @"type" = initTag(.type);
    pub const @"anyerror" = initTag(.anyerror);
    pub const @"anyopaque" = initTag(.anyopaque);
    pub const @"null" = initTag(.@"null");

    pub fn ptr(arena: Allocator, mod: *Module, data: Payload.Pointer.Data) !Type {
        const target = mod.getTarget();

        var d = data;

        if (d.size == .C) {
            d.@"allowzero" = true;
        }

        // Canonicalize non-zero alignment. If it matches the ABI alignment of the pointee
        // type, we change it to 0 here. If this causes an assertion trip because the
        // pointee type needs to be resolved more, that needs to be done before calling
        // this ptr() function.
        if (d.@"align" != 0 and d.@"align" == d.pointee_type.abiAlignment(target)) {
            d.@"align" = 0;
        }

        // Canonicalize host_size. If it matches the bit size of the pointee type,
        // we change it to 0 here. If this causes an assertion trip, the pointee type
        // needs to be resolved before calling this ptr() function.
        if (d.host_size != 0) {
            assert(d.bit_offset < d.host_size * 8);
            if (d.host_size * 8 == d.pointee_type.bitSize(target)) {
                assert(d.bit_offset == 0);
                d.host_size = 0;
            }
        }

        if (d.@"align" == 0 and d.@"addrspace" == .generic and
            d.bit_offset == 0 and d.host_size == 0 and !d.@"allowzero" and !d.@"volatile")
        {
            if (d.sentinel) |sent| {
                if (!d.mutable and d.pointee_type.eql(Type.u8, mod)) {
                    switch (d.size) {
                        .Slice => {
                            if (sent.compareWithZero(.eq)) {
                                return Type.initTag(.const_slice_u8_sentinel_0);
                            }
                        },
                        .Many => {
                            if (sent.compareWithZero(.eq)) {
                                return Type.initTag(.manyptr_const_u8_sentinel_0);
                            }
                        },
                        else => {},
                    }
                }
            } else if (!d.mutable and d.pointee_type.eql(Type.u8, mod)) {
                switch (d.size) {
                    .Slice => return Type.initTag(.const_slice_u8),
                    .Many => return Type.initTag(.manyptr_const_u8),
                    else => {},
                }
            } else {
                // TODO stage1 type inference bug
                const T = Type.Tag;

                const type_payload = try arena.create(Type.Payload.ElemType);
                type_payload.* = .{
                    .base = .{
                        .tag = switch (d.size) {
                            .One => if (d.mutable) T.single_mut_pointer else T.single_const_pointer,
                            .Many => if (d.mutable) T.many_mut_pointer else T.many_const_pointer,
                            .C => if (d.mutable) T.c_mut_pointer else T.c_const_pointer,
                            .Slice => if (d.mutable) T.mut_slice else T.const_slice,
                        },
                    },
                    .data = d.pointee_type,
                };
                return Type.initPayload(&type_payload.base);
            }
        }

        return Type.Tag.pointer.create(arena, d);
    }

    pub fn array(
        arena: Allocator,
        len: u64,
        sent: ?Value,
        elem_type: Type,
        mod: *Module,
    ) Allocator.Error!Type {
        if (elem_type.eql(Type.u8, mod)) {
            if (sent) |some| {
                if (some.eql(Value.zero, elem_type, mod)) {
                    return Tag.array_u8_sentinel_0.create(arena, len);
                }
            } else {
                return Tag.array_u8.create(arena, len);
            }
        }

        if (sent) |some| {
            return Tag.array_sentinel.create(arena, .{
                .len = len,
                .sentinel = some,
                .elem_type = elem_type,
            });
        }

        return Tag.array.create(arena, .{
            .len = len,
            .elem_type = elem_type,
        });
    }

    pub fn vector(arena: Allocator, len: u64, elem_type: Type) Allocator.Error!Type {
        return Tag.vector.create(arena, .{
            .len = len,
            .elem_type = elem_type,
        });
    }

    pub fn optional(arena: Allocator, child_type: Type) Allocator.Error!Type {
        switch (child_type.tag()) {
            .single_const_pointer => return Type.Tag.optional_single_const_pointer.create(
                arena,
                child_type.elemType(),
            ),
            .single_mut_pointer => return Type.Tag.optional_single_mut_pointer.create(
                arena,
                child_type.elemType(),
            ),
            else => return Type.Tag.optional.create(arena, child_type),
        }
    }

    pub fn errorUnion(
        arena: Allocator,
        error_set: Type,
        payload: Type,
        mod: *Module,
    ) Allocator.Error!Type {
        assert(error_set.zigTypeTag() == .ErrorSet);
        if (error_set.eql(Type.@"anyerror", mod) and
            payload.eql(Type.void, mod))
        {
            return Type.initTag(.anyerror_void_error_union);
        }

        return Type.Tag.error_union.create(arena, .{
            .error_set = error_set,
            .payload = payload,
        });
    }

    pub fn smallestUnsignedBits(max: u64) u16 {
        if (max == 0) return 0;
        const base = std.math.log2(max);
        const upper = (@as(u64, 1) << @intCast(u6, base)) - 1;
        return @intCast(u16, base + @boolToInt(upper < max));
    }

    pub fn smallestUnsignedInt(arena: Allocator, max: u64) !Type {
        const bits = smallestUnsignedBits(max);
        return switch (bits) {
            1 => initTag(.u1),
            8 => initTag(.u8),
            16 => initTag(.u16),
            32 => initTag(.u32),
            64 => initTag(.u64),
            else => return Tag.int_unsigned.create(arena, bits),
        };
    }

    /// This is only used for comptime asserts. Bump this number when you make a change
    /// to packed struct layout to find out all the places in the codebase you need to edit!
    pub const packed_struct_layout_version = 2;
};

pub const CType = enum {
    short,
    ushort,
    int,
    uint,
    long,
    ulong,
    longlong,
    ulonglong,
    longdouble,

    pub fn sizeInBits(self: CType, target: Target) u16 {
        switch (target.os.tag) {
            .freestanding, .other => switch (target.cpu.arch) {
                .msp430 => switch (self) {
                    .short, .ushort, .int, .uint => return 16,
                    .long, .ulong => return 32,
                    .longlong, .ulonglong, .longdouble => return 64,
                },
                else => switch (self) {
                    .short, .ushort => return 16,
                    .int, .uint => return 32,
                    .long, .ulong => return target.cpu.arch.ptrBitWidth(),
                    .longlong, .ulonglong => return 64,
                    .longdouble => switch (target.cpu.arch) {
                        .i386, .x86_64 => return 80,

                        .riscv64,
                        .aarch64,
                        .aarch64_be,
                        .aarch64_32,
                        .s390x,
                        .mips64,
                        .mips64el,
                        .sparc,
                        .sparc64,
                        .sparcel,
                        .powerpc,
                        .powerpcle,
                        .powerpc64,
                        .powerpc64le,
                        => return 128,

                        else => return 64,
                    },
                },
            },

            .linux,
            .freebsd,
            .netbsd,
            .dragonfly,
            .openbsd,
            .wasi,
            .emscripten,
            .plan9,
            .solaris,
            => switch (self) {
                .short, .ushort => return 16,
                .int, .uint => return 32,
                .long, .ulong => return target.cpu.arch.ptrBitWidth(),
                .longlong, .ulonglong => return 64,
                .longdouble => switch (target.cpu.arch) {
                    .i386, .x86_64 => return 80,

                    .riscv64,
                    .aarch64,
                    .aarch64_be,
                    .aarch64_32,
                    .s390x,
                    .mips64,
                    .mips64el,
                    .sparc,
                    .sparc64,
                    .sparcel,
                    .powerpc,
                    .powerpcle,
                    .powerpc64,
                    .powerpc64le,
                    => return 128,

                    else => return 64,
                },
            },

            .windows, .uefi => switch (self) {
                .short, .ushort => return 16,
                .int, .uint, .long, .ulong => return 32,
                .longlong, .ulonglong, .longdouble => return 64,
            },

            .macos, .ios, .tvos, .watchos => switch (self) {
                .short, .ushort => return 16,
                .int, .uint => return 32,
                .long, .ulong, .longlong, .ulonglong => return 64,
                .longdouble => switch (target.cpu.arch) {
                    .i386, .x86_64 => return 80,
                    else => return 64,
                },
            },

            .ananas,
            .cloudabi,
            .fuchsia,
            .kfreebsd,
            .lv2,
            .zos,
            .haiku,
            .minix,
            .rtems,
            .nacl,
            .aix,
            .cuda,
            .nvcl,
            .amdhsa,
            .ps4,
            .elfiamcu,
            .mesa3d,
            .contiki,
            .amdpal,
            .hermit,
            .hurd,
            .opencl,
            .glsl450,
            .vulkan,
            => @panic("TODO specify the C integer and float type sizes for this OS"),
        }
    }
};
