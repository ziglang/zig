const std = @import("std");
const Value = @import("value.zig").Value;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Target = std.Target;
const Module = @import("Module.zig");
const log = std.log.scoped(.Type);

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

            .Pointer => is_equality_cmp or ty.isCPtr(),
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
            .single_const_pointer,
            .many_const_pointer,
            .manyptr_const_u8,
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

            else => unreachable,
        }
    }

    pub fn eql(a: Type, b: Type) bool {
        // As a shortcut, if the small tags / addresses match, we're done.
        if (a.tag_if_small_enough == b.tag_if_small_enough)
            return true;
        const zig_tag_a = a.zigTypeTag();
        const zig_tag_b = b.zigTypeTag();
        if (zig_tag_a != zig_tag_b)
            return false;
        switch (zig_tag_a) {
            .EnumLiteral => return true,
            .Type => return true,
            .Void => return true,
            .Bool => return true,
            .NoReturn => return true,
            .ComptimeFloat => return true,
            .ComptimeInt => return true,
            .Undefined => return true,
            .Null => return true,
            .AnyFrame => {
                return a.elemType().eql(b.elemType());
            },
            .Pointer => {
                const info_a = a.ptrInfo().data;
                const info_b = b.ptrInfo().data;
                if (!info_a.pointee_type.eql(info_b.pointee_type))
                    return false;
                if (info_a.size != info_b.size)
                    return false;
                if (info_a.mutable != info_b.mutable)
                    return false;
                if (info_a.@"volatile" != info_b.@"volatile")
                    return false;
                if (info_a.@"allowzero" != info_b.@"allowzero")
                    return false;
                if (info_a.bit_offset != info_b.bit_offset)
                    return false;
                if (info_a.host_size != info_b.host_size)
                    return false;
                if (info_a.@"addrspace" != info_b.@"addrspace")
                    return false;

                const sentinel_a = info_a.sentinel;
                const sentinel_b = info_b.sentinel;
                if (sentinel_a) |sa| {
                    if (sentinel_b) |sb| {
                        if (!sa.eql(sb, info_a.pointee_type))
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
            .Int => {
                // Detect that e.g. u64 != usize, even if the bits match on a particular target.
                const a_is_named_int = a.isNamedInt();
                const b_is_named_int = b.isNamedInt();
                if (a_is_named_int != b_is_named_int)
                    return false;
                if (a_is_named_int)
                    return a.tag() == b.tag();
                // Remaining cases are arbitrary sized integers.
                // The target will not be branched upon, because we handled target-dependent cases above.
                const info_a = a.intInfo(@as(Target, undefined));
                const info_b = b.intInfo(@as(Target, undefined));
                return info_a.signedness == info_b.signedness and info_a.bits == info_b.bits;
            },
            .Array, .Vector => {
                if (a.arrayLen() != b.arrayLen())
                    return false;
                const elem_ty = a.elemType();
                if (!elem_ty.eql(b.elemType()))
                    return false;
                const sentinel_a = a.sentinel();
                const sentinel_b = b.sentinel();
                if (sentinel_a) |sa| {
                    if (sentinel_b) |sb| {
                        return sa.eql(sb, elem_ty);
                    } else {
                        return false;
                    }
                } else {
                    return sentinel_b == null;
                }
            },
            .Fn => {
                if (!a.fnReturnType().eql(b.fnReturnType()))
                    return false;
                if (a.fnCallingConvention() != b.fnCallingConvention())
                    return false;
                const a_param_len = a.fnParamLen();
                const b_param_len = b.fnParamLen();
                if (a_param_len != b_param_len)
                    return false;
                var i: usize = 0;
                while (i < a_param_len) : (i += 1) {
                    if (!a.fnParamType(i).eql(b.fnParamType(i)))
                        return false;
                }
                if (a.fnIsVarArgs() != b.fnIsVarArgs())
                    return false;
                return true;
            },
            .Optional => {
                var buf_a: Payload.ElemType = undefined;
                var buf_b: Payload.ElemType = undefined;
                return a.optionalChild(&buf_a).eql(b.optionalChild(&buf_b));
            },
            .Struct => {
                if (a.castTag(.@"struct")) |a_payload| {
                    if (b.castTag(.@"struct")) |b_payload| {
                        return a_payload.data == b_payload.data;
                    }
                }
                return a.tag() == b.tag();
            },
            .Enum => {
                if (a.cast(Payload.EnumFull)) |a_payload| {
                    if (b.cast(Payload.EnumFull)) |b_payload| {
                        return a_payload.data == b_payload.data;
                    }
                }
                if (a.cast(Payload.EnumSimple)) |a_payload| {
                    if (b.cast(Payload.EnumSimple)) |b_payload| {
                        return a_payload.data == b_payload.data;
                    }
                }
                return a.tag() == b.tag();
            },
            .Opaque => {
                const opaque_obj_a = a.castTag(.@"opaque").?.data;
                const opaque_obj_b = b.castTag(.@"opaque").?.data;
                return opaque_obj_a == opaque_obj_b;
            },
            .Union => {
                if (a.cast(Payload.Union)) |a_payload| {
                    if (b.cast(Payload.Union)) |b_payload| {
                        return a_payload.data == b_payload.data;
                    }
                }
                return a.tag() == b.tag();
            },
            .ErrorUnion => {
                const a_set = a.errorUnionSet();
                const b_set = b.errorUnionSet();
                if (!a_set.eql(b_set)) return false;

                const a_payload = a.errorUnionPayload();
                const b_payload = b.errorUnionPayload();
                if (!a_payload.eql(b_payload)) return false;

                return true;
            },
            .ErrorSet => {
                // TODO: revisit the language specification for how to evaluate equality
                // for error set types.

                if (a.tag() == .anyerror and b.tag() == .anyerror) {
                    return true;
                }

                if (a.tag() == .error_set and b.tag() == .error_set) {
                    return a.castTag(.error_set).?.data.owner_decl == b.castTag(.error_set).?.data.owner_decl;
                }

                if (a.tag() == .error_set_inferred and b.tag() == .error_set_inferred) {
                    return a.castTag(.error_set_inferred).?.data.func == b.castTag(.error_set_inferred).?.data.func;
                }

                if (a.tag() == .error_set_single and b.tag() == .error_set_single) {
                    const a_data = a.castTag(.error_set_single).?.data;
                    const b_data = b.castTag(.error_set_single).?.data;
                    return std.mem.eql(u8, a_data, b_data);
                }
                return false;
            },
            .Float => return a.tag() == b.tag(),
            .BoundFn,
            .Frame,
            => std.debug.panic("TODO implement Type equality comparison of {} and {}", .{ a, b }),
        }
    }

    pub fn hash(self: Type) u64 {
        var hasher = std.hash.Wyhash.init(0);
        self.hashWithHasher(&hasher);
        return hasher.final();
    }

    pub fn hashWithHasher(self: Type, hasher: *std.hash.Wyhash) void {
        const zig_type_tag = self.zigTypeTag();
        std.hash.autoHash(hasher, zig_type_tag);
        switch (zig_type_tag) {
            .Type,
            .Void,
            .Bool,
            .NoReturn,
            .ComptimeFloat,
            .ComptimeInt,
            .Undefined,
            .Null,
            => {}, // The zig type tag is all that is needed to distinguish.

            .Pointer => {
                // TODO implement more pointer type hashing
            },
            .Int => {
                // Detect that e.g. u64 != usize, even if the bits match on a particular target.
                if (self.isNamedInt()) {
                    std.hash.autoHash(hasher, self.tag());
                } else {
                    // Remaining cases are arbitrary sized integers.
                    // The target will not be branched upon, because we handled target-dependent cases above.
                    const info = self.intInfo(@as(Target, undefined));
                    std.hash.autoHash(hasher, info.signedness);
                    std.hash.autoHash(hasher, info.bits);
                }
            },
            .Array, .Vector => {
                std.hash.autoHash(hasher, self.arrayLen());
                std.hash.autoHash(hasher, self.elemType().hash());
                // TODO hash array sentinel
            },
            .Fn => {
                std.hash.autoHash(hasher, self.fnReturnType().hash());
                std.hash.autoHash(hasher, self.fnCallingConvention());
                const params_len = self.fnParamLen();
                std.hash.autoHash(hasher, params_len);
                var i: usize = 0;
                while (i < params_len) : (i += 1) {
                    std.hash.autoHash(hasher, self.fnParamType(i).hash());
                }
                std.hash.autoHash(hasher, self.fnIsVarArgs());
            },
            .Optional => {
                var buf: Payload.ElemType = undefined;
                std.hash.autoHash(hasher, self.optionalChild(&buf).hash());
            },
            .Float,
            .Struct,
            .ErrorUnion,
            .ErrorSet,
            .Enum,
            .Union,
            .BoundFn,
            .Opaque,
            .Frame,
            .AnyFrame,
            .EnumLiteral,
            => {
                // TODO implement more type hashing
            },
        }
    }

    pub const HashContext64 = struct {
        pub fn hash(self: @This(), t: Type) u64 {
            _ = self;
            return t.hash();
        }
        pub fn eql(self: @This(), a: Type, b: Type) bool {
            _ = self;
            return a.eql(b);
        }
    };

    pub const HashContext32 = struct {
        pub fn hash(self: @This(), t: Type) u32 {
            _ = self;
            return @truncate(u32, t.hash());
        }
        pub fn eql(self: @This(), a: Type, b: Type) bool {
            _ = self;
            return a.eql(b);
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
            .enum_literal,
            .anyerror_void_error_union,
            .inferred_alloc_const,
            .inferred_alloc_mut,
            .var_args_param,
            .empty_struct_literal,
            .manyptr_u8,
            .manyptr_const_u8,
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
            .function => {
                const payload = self.castTag(.function).?.data;
                const param_types = try allocator.alloc(Type, payload.param_types.len);
                for (payload.param_types) |param_type, i| {
                    param_types[i] = try param_type.copy(allocator);
                }
                const other_comptime_params = payload.comptime_params[0..payload.param_types.len];
                const comptime_params = try allocator.dupe(bool, other_comptime_params);
                return Tag.function.create(allocator, .{
                    .return_type = try payload.return_type.copy(allocator),
                    .param_types = param_types,
                    .cc = payload.cc,
                    .is_var_args = payload.is_var_args,
                    .is_generic = payload.is_generic,
                    .comptime_params = comptime_params.ptr,
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
                const names = self.castTag(.error_set_merged).?.data;
                const duped_names = try allocator.alloc([]const u8, names.len);
                for (duped_names) |*name, i| {
                    name.* = try allocator.dupe(u8, names[i]);
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

    pub fn format(
        start_type: Type,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        _ = options;
        comptime assert(fmt.len == 0);
        var ty = start_type;
        while (true) {
            const t = ty.tag();
            switch (t) {
                .u1,
                .u8,
                .i8,
                .u16,
                .i16,
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
                    return struct_obj.owner_decl.renderFullyQualifiedName(writer);
                },
                .@"union", .union_tagged => {
                    const union_obj = ty.cast(Payload.Union).?.data;
                    return union_obj.owner_decl.renderFullyQualifiedName(writer);
                },
                .enum_full, .enum_nonexhaustive => {
                    const enum_full = ty.cast(Payload.EnumFull).?.data;
                    return enum_full.owner_decl.renderFullyQualifiedName(writer);
                },
                .enum_simple => {
                    const enum_simple = ty.castTag(.enum_simple).?.data;
                    return enum_simple.owner_decl.renderFullyQualifiedName(writer);
                },
                .enum_numbered => {
                    const enum_numbered = ty.castTag(.enum_numbered).?.data;
                    return enum_numbered.owner_decl.renderFullyQualifiedName(writer);
                },
                .@"opaque" => {
                    // TODO use declaration name
                    return writer.writeAll("opaque {}");
                },

                .anyerror_void_error_union => return writer.writeAll("anyerror!void"),
                .const_slice_u8 => return writer.writeAll("[]const u8"),
                .fn_noreturn_no_args => return writer.writeAll("fn() noreturn"),
                .fn_void_no_args => return writer.writeAll("fn() void"),
                .fn_naked_noreturn_no_args => return writer.writeAll("fn() callconv(.Naked) noreturn"),
                .fn_ccc_void_no_args => return writer.writeAll("fn() callconv(.C) void"),
                .single_const_pointer_to_comptime_int => return writer.writeAll("*const comptime_int"),
                .manyptr_u8 => return writer.writeAll("[*]u8"),
                .manyptr_const_u8 => return writer.writeAll("[*]const u8"),
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
                .type_info => return writer.writeAll("std.builtin.TypeInfo"),
                .function => {
                    const payload = ty.castTag(.function).?.data;
                    try writer.writeAll("fn(");
                    for (payload.param_types) |param_type, i| {
                        if (i != 0) try writer.writeAll(", ");
                        try param_type.format("", .{}, writer);
                    }
                    if (payload.is_var_args) {
                        if (payload.param_types.len != 0) {
                            try writer.writeAll(", ");
                        }
                        try writer.writeAll("...");
                    }
                    try writer.writeAll(") callconv(.");
                    try writer.writeAll(@tagName(payload.cc));
                    try writer.writeAll(") ");
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
                    try payload.elem_type.format("", .{}, writer);
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
                    try writer.print("[{d}:{}]", .{ payload.len, payload.sentinel });
                    ty = payload.elem_type;
                    continue;
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
                        .Many => try writer.print("[*:{}]", .{some}),
                        .Slice => try writer.print("[:{}]", .{some}),
                    } else switch (payload.size) {
                        .One => try writer.writeAll("*"),
                        .Many => try writer.writeAll("[*]"),
                        .C => try writer.writeAll("[*c]"),
                        .Slice => try writer.writeAll("[]"),
                    }
                    if (payload.@"align" != 0) {
                        try writer.print("align({d}", .{payload.@"align"});

                        if (payload.bit_offset != 0) {
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
                    try payload.error_set.format("", .{}, writer);
                    try writer.writeAll("!");
                    ty = payload.payload;
                    continue;
                },
                .error_set => {
                    const error_set = ty.castTag(.error_set).?.data;
                    return writer.writeAll(std.mem.sliceTo(error_set.owner_decl.name, 0));
                },
                .error_set_inferred => {
                    const func = ty.castTag(.error_set_inferred).?.data.func;
                    return writer.print("(inferred error set of {s})", .{func.owner_decl.name});
                },
                .error_set_merged => {
                    const names = ty.castTag(.error_set_merged).?.data;
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

    /// Returns a name suitable for `@typeName`.
    pub fn nameAlloc(ty: Type, arena: Allocator) Allocator.Error![:0]const u8 {
        const t = ty.tag();
        switch (t) {
            .inferred_alloc_const => unreachable,
            .inferred_alloc_mut => unreachable,
            .generic_poison => unreachable,

            .u1,
            .u8,
            .i8,
            .u16,
            .i16,
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
            => return @tagName(t),

            .enum_literal => return "@Type(.EnumLiteral)",
            .@"null" => return "@Type(.Null)",
            .@"undefined" => return "@Type(.Undefined)",

            .empty_struct, .empty_struct_literal => return "struct {}",

            .@"struct" => {
                const struct_obj = ty.castTag(.@"struct").?.data;
                return try arena.dupeZ(u8, std.mem.sliceTo(struct_obj.owner_decl.name, 0));
            },
            .@"union", .union_tagged => {
                const union_obj = ty.cast(Payload.Union).?.data;
                return try arena.dupeZ(u8, std.mem.sliceTo(union_obj.owner_decl.name, 0));
            },
            .enum_full, .enum_nonexhaustive => {
                const enum_full = ty.cast(Payload.EnumFull).?.data;
                return try arena.dupeZ(u8, std.mem.sliceTo(enum_full.owner_decl.name, 0));
            },
            .enum_simple => {
                const enum_simple = ty.castTag(.enum_simple).?.data;
                return try arena.dupeZ(u8, std.mem.sliceTo(enum_simple.owner_decl.name, 0));
            },
            .enum_numbered => {
                const enum_numbered = ty.castTag(.enum_numbered).?.data;
                return try arena.dupeZ(u8, std.mem.sliceTo(enum_numbered.owner_decl.name, 0));
            },
            .@"opaque" => {
                // TODO use declaration name
                return "opaque {}";
            },

            .anyerror_void_error_union => return "anyerror!void",
            .const_slice_u8 => return "[]const u8",
            .fn_noreturn_no_args => return "fn() noreturn",
            .fn_void_no_args => return "fn() void",
            .fn_naked_noreturn_no_args => return "fn() callconv(.Naked) noreturn",
            .fn_ccc_void_no_args => return "fn() callconv(.C) void",
            .single_const_pointer_to_comptime_int => return "*const comptime_int",
            .manyptr_u8 => return "[*]u8",
            .manyptr_const_u8 => return "[*]const u8",
            .atomic_order => return "AtomicOrder",
            .atomic_rmw_op => return "AtomicRmwOp",
            .calling_convention => return "CallingConvention",
            .address_space => return "AddressSpace",
            .float_mode => return "FloatMode",
            .reduce_op => return "ReduceOp",
            .call_options => return "CallOptions",
            .prefetch_options => return "PrefetchOptions",
            .export_options => return "ExportOptions",
            .extern_options => return "ExternOptions",
            .type_info => return "TypeInfo",

            else => {
                // TODO this is wasteful and also an incorrect implementation of `@typeName`
                var buf = std.ArrayList(u8).init(arena);
                try buf.writer().print("{}", .{ty});
                return try buf.toOwnedSliceSentinel(0);
            },
        }
    }

    /// Anything that reports hasCodeGenBits() false returns false here as well.
    /// `generic_poison` will return false.
    pub fn requiresComptime(ty: Type) bool {
        return switch (ty.tag()) {
            .u1,
            .u8,
            .i8,
            .u16,
            .i16,
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
            .fn_noreturn_no_args,
            .fn_void_no_args,
            .fn_naked_noreturn_no_args,
            .fn_ccc_void_no_args,
            .const_slice_u8,
            .anyerror_void_error_union,
            .empty_struct_literal,
            .function,
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
            => true,

            .var_args_param => unreachable,
            .inferred_alloc_mut => unreachable,
            .inferred_alloc_const => unreachable,
            .bound_fn => unreachable,

            .array,
            .array_sentinel,
            .vector,
            .pointer,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            => return requiresComptime(childType(ty)),

            .optional,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            => {
                var buf: Payload.ElemType = undefined;
                return requiresComptime(optionalChild(ty, &buf));
            },

            .error_union,
            .anyframe_T,
            .@"struct",
            .@"union",
            .union_tagged,
            .enum_numbered,
            .enum_full,
            .enum_nonexhaustive,
            => false, // TODO some of these should be `true` depending on their child types
        };
    }

    pub fn toValue(self: Type, allocator: Allocator) Allocator.Error!Value {
        switch (self.tag()) {
            .u1 => return Value.initTag(.u1_type),
            .u8 => return Value.initTag(.u8_type),
            .i8 => return Value.initTag(.i8_type),
            .u16 => return Value.initTag(.u16_type),
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
            .enum_literal => return Value.initTag(.enum_literal_type),
            .manyptr_u8 => return Value.initTag(.manyptr_u8_type),
            .manyptr_const_u8 => return Value.initTag(.manyptr_const_u8_type),
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

    /// For structs and unions, if the type does not have their fields resolved
    /// this will return `false`.
    pub fn hasCodeGenBits(self: Type) bool {
        return switch (self.tag()) {
            .u1,
            .u8,
            .i8,
            .u16,
            .i16,
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
            .f128,
            .bool,
            .anyerror,
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            .array_u8_sentinel_0,
            .optional,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            .anyerror_void_error_union,
            .error_set,
            .error_set_single,
            .error_set_inferred,
            .error_set_merged,
            .manyptr_u8,
            .manyptr_const_u8,
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
            .anyframe_T,
            .@"opaque",
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            .pointer,
            => true,

            .function => !self.castTag(.function).?.data.is_generic,

            .fn_noreturn_no_args,
            .fn_void_no_args,
            .fn_naked_noreturn_no_args,
            .fn_ccc_void_no_args,
            => true,

            .@"struct" => {
                const struct_obj = self.castTag(.@"struct").?.data;
                if (struct_obj.known_has_bits) {
                    return true;
                }
                for (struct_obj.fields.values()) |value| {
                    if (value.ty.hasCodeGenBits())
                        return true;
                } else {
                    return false;
                }
            },
            .enum_full => {
                const enum_full = self.castTag(.enum_full).?.data;
                return enum_full.fields.count() >= 2;
            },
            .enum_simple => {
                const enum_simple = self.castTag(.enum_simple).?.data;
                return enum_simple.fields.count() >= 2;
            },
            .enum_numbered, .enum_nonexhaustive => {
                var buffer: Payload.Bits = undefined;
                const int_tag_ty = self.intTagType(&buffer);
                return int_tag_ty.hasCodeGenBits();
            },
            .@"union" => {
                const union_obj = self.castTag(.@"union").?.data;
                for (union_obj.fields.values()) |value| {
                    if (value.ty.hasCodeGenBits())
                        return true;
                } else {
                    return false;
                }
            },
            .union_tagged => {
                const union_obj = self.castTag(.union_tagged).?.data;
                if (union_obj.tag_ty.hasCodeGenBits()) {
                    return true;
                }
                for (union_obj.fields.values()) |value| {
                    if (value.ty.hasCodeGenBits())
                        return true;
                } else {
                    return false;
                }
            },

            .array, .vector => self.elemType().hasCodeGenBits() and self.arrayLen() != 0,
            .array_u8 => self.arrayLen() != 0,

            .array_sentinel => self.childType().hasCodeGenBits(),

            .int_signed, .int_unsigned => self.cast(Payload.Bits).?.data != 0,

            .error_union => {
                const payload = self.castTag(.error_union).?.data;
                return payload.error_set.hasCodeGenBits() or payload.payload.hasCodeGenBits();
            },

            .anyopaque,
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
            .type_info,
            .bound_fn,
            => false,

            .inferred_alloc_const => unreachable,
            .inferred_alloc_mut => unreachable,
            .var_args_param => unreachable,
            .generic_poison => unreachable,
        };
    }

    pub fn isNoReturn(self: Type) bool {
        const definitely_correct_result =
            self.tag_if_small_enough != .bound_fn and
            self.zigTypeTag() == .NoReturn;
        const fast_result = self.tag_if_small_enough == Tag.noreturn;
        assert(fast_result == definitely_correct_result);
        return fast_result;
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
            => return self.cast(Payload.ElemType).?.data.abiAlignment(target),

            .manyptr_u8,
            .manyptr_const_u8,
            .const_slice_u8,
            => return 1,

            .pointer => {
                const ptr_info = self.castTag(.pointer).?.data;
                if (ptr_info.@"align" != 0) {
                    return ptr_info.@"align";
                } else {
                    return ptr_info.pointee_type.abiAlignment(target);
                }
            },

            else => unreachable,
        }
    }

    pub fn ptrAddressSpace(self: Type) std.builtin.AddressSpace {
        return switch (self.tag()) {
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
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
            => .generic,

            .pointer => self.castTag(.pointer).?.data.@"addrspace",

            else => unreachable,
        };
    }

    /// Returns 0 for 0-bit types.
    pub fn abiAlignment(self: Type, target: Target) u32 {
        return switch (self.tag()) {
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
            => return 1,

            .fn_noreturn_no_args, // represents machine code; not a pointer
            .fn_void_no_args, // represents machine code; not a pointer
            .fn_naked_noreturn_no_args, // represents machine code; not a pointer
            .fn_ccc_void_no_args, // represents machine code; not a pointer
            .function, // represents machine code; not a pointer
            => return switch (target.cpu.arch) {
                .arm, .armeb => 4,
                .aarch64, .aarch64_32, .aarch64_be => 4,
                .riscv64 => 2,
                else => 1,
            },

            .i16, .u16 => return 2,
            .i32, .u32 => return 4,
            .i64, .u64 => return 8,
            .u128, .i128 => return 16,

            .isize,
            .usize,
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
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
            .@"anyframe",
            .anyframe_T,
            => return @divExact(target.cpu.arch.ptrBitWidth(), 8),

            .c_short => return @divExact(CType.short.sizeInBits(target), 8),
            .c_ushort => return @divExact(CType.ushort.sizeInBits(target), 8),
            .c_int => return @divExact(CType.int.sizeInBits(target), 8),
            .c_uint => return @divExact(CType.uint.sizeInBits(target), 8),
            .c_long => return @divExact(CType.long.sizeInBits(target), 8),
            .c_ulong => return @divExact(CType.ulong.sizeInBits(target), 8),
            .c_longlong => return @divExact(CType.longlong.sizeInBits(target), 8),
            .c_ulonglong => return @divExact(CType.ulonglong.sizeInBits(target), 8),

            .f16 => return 2,
            .f32 => return 4,
            .f64 => return 8,
            .f128 => return 16,
            .c_longdouble => return 16,

            .error_set,
            .error_set_single,
            .anyerror_void_error_union,
            .anyerror,
            .error_set_inferred,
            .error_set_merged,
            => return 2, // TODO revisit this when we have the concept of the error tag type

            .array, .array_sentinel => return self.elemType().abiAlignment(target),

            // TODO audit this - is there any more complicated logic to determine
            // ABI alignment of vectors?
            .vector => return 16,

            .int_signed, .int_unsigned => {
                const bits: u16 = self.cast(Payload.Bits).?.data;
                if (bits == 0) return 0;
                if (bits <= 8) return 1;
                if (bits <= 16) return 2;
                if (bits <= 32) return 4;
                if (bits <= 64) return 8;
                return 16;
            },

            .optional => {
                var buf: Payload.ElemType = undefined;
                const child_type = self.optionalChild(&buf);
                if (!child_type.hasCodeGenBits()) return 1;

                if (child_type.zigTypeTag() == .Pointer and !child_type.isCPtr())
                    return @divExact(target.cpu.arch.ptrBitWidth(), 8);

                return child_type.abiAlignment(target);
            },

            .error_union => {
                const data = self.castTag(.error_union).?.data;
                if (!data.error_set.hasCodeGenBits()) {
                    return data.payload.abiAlignment(target);
                } else if (!data.payload.hasCodeGenBits()) {
                    return data.error_set.abiAlignment(target);
                }
                return @maximum(
                    data.payload.abiAlignment(target),
                    data.error_set.abiAlignment(target),
                );
            },

            .@"struct" => {
                const fields = self.structFields();
                if (self.castTag(.@"struct")) |payload| {
                    const struct_obj = payload.data;
                    assert(struct_obj.status == .have_layout);
                    const is_packed = struct_obj.layout == .Packed;
                    if (is_packed) @panic("TODO packed structs");
                }
                var big_align: u32 = 0;
                for (fields.values()) |field| {
                    if (!field.ty.hasCodeGenBits()) continue;

                    const field_align = a: {
                        if (field.abi_align.tag() == .abi_align_default) {
                            break :a field.ty.abiAlignment(target);
                        } else {
                            break :a @intCast(u32, field.abi_align.toUnsignedInt());
                        }
                    };
                    big_align = @maximum(big_align, field_align);
                }
                return big_align;
            },
            .enum_full, .enum_nonexhaustive, .enum_simple, .enum_numbered => {
                var buffer: Payload.Bits = undefined;
                const int_tag_ty = self.intTagType(&buffer);
                return int_tag_ty.abiAlignment(target);
            },
            // TODO pass `true` for have_tag when unions have a safety tag
            .@"union" => return self.castTag(.@"union").?.data.abiAlignment(target, false),
            .union_tagged => return self.castTag(.union_tagged).?.data.abiAlignment(target, true),

            .empty_struct,
            .void,
            .anyopaque,
            => return 0,

            .empty_struct_literal,
            .type,
            .comptime_int,
            .comptime_float,
            .noreturn,
            .@"null",
            .@"undefined",
            .enum_literal,
            .inferred_alloc_const,
            .inferred_alloc_mut,
            .@"opaque",
            .var_args_param,
            .type_info,
            .bound_fn,
            => unreachable,

            .generic_poison => unreachable,
        };
    }

    /// Asserts the type has the ABI size already resolved.
    /// Types that return false for hasCodeGenBits() return 0.
    pub fn abiSize(self: Type, target: Target) u64 {
        return switch (self.tag()) {
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
            => 0,

            .@"struct" => {
                const field_count = self.structFieldCount();
                if (field_count == 0) {
                    return 0;
                }
                return self.structFieldOffset(field_count, target);
            },
            .enum_simple, .enum_full, .enum_nonexhaustive, .enum_numbered => {
                var buffer: Payload.Bits = undefined;
                const int_tag_ty = self.intTagType(&buffer);
                return int_tag_ty.abiSize(target);
            },
            // TODO pass `true` for have_tag when unions have a safety tag
            .@"union" => return self.castTag(.@"union").?.data.abiSize(target, false),
            .union_tagged => return self.castTag(.union_tagged).?.data.abiSize(target, true),

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
            => return 1,

            .array_u8 => self.castTag(.array_u8).?.data,
            .array_u8_sentinel_0 => self.castTag(.array_u8_sentinel_0).?.data + 1,
            .array, .vector => {
                const payload = self.cast(Payload.Array).?.data;
                const elem_size = @maximum(payload.elem_type.abiAlignment(target), payload.elem_type.abiSize(target));
                return payload.len * elem_size;
            },
            .array_sentinel => {
                const payload = self.castTag(.array_sentinel).?.data;
                const elem_size = std.math.max(
                    payload.elem_type.abiAlignment(target),
                    payload.elem_type.abiSize(target),
                );
                return (payload.len + 1) * elem_size;
            },
            .i16, .u16 => return 2,
            .i32, .u32 => return 4,
            .i64, .u64 => return 8,
            .u128, .i128 => return 16,

            .isize,
            .usize,
            .@"anyframe",
            .anyframe_T,
            => return @divExact(target.cpu.arch.ptrBitWidth(), 8),

            .const_slice,
            .mut_slice,
            => {
                if (self.elemType().hasCodeGenBits()) return @divExact(target.cpu.arch.ptrBitWidth(), 8) * 2;
                return @divExact(target.cpu.arch.ptrBitWidth(), 8);
            },
            .const_slice_u8 => return @divExact(target.cpu.arch.ptrBitWidth(), 8) * 2,

            .optional_single_const_pointer,
            .optional_single_mut_pointer,
            => {
                if (!self.elemType().hasCodeGenBits()) return 1;
                return @divExact(target.cpu.arch.ptrBitWidth(), 8);
            },

            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .pointer,
            => {
                if (!self.elemType().hasCodeGenBits()) return 0;
                return @divExact(target.cpu.arch.ptrBitWidth(), 8);
            },

            .manyptr_u8,
            .manyptr_const_u8,
            => return @divExact(target.cpu.arch.ptrBitWidth(), 8),

            .c_short => return @divExact(CType.short.sizeInBits(target), 8),
            .c_ushort => return @divExact(CType.ushort.sizeInBits(target), 8),
            .c_int => return @divExact(CType.int.sizeInBits(target), 8),
            .c_uint => return @divExact(CType.uint.sizeInBits(target), 8),
            .c_long => return @divExact(CType.long.sizeInBits(target), 8),
            .c_ulong => return @divExact(CType.ulong.sizeInBits(target), 8),
            .c_longlong => return @divExact(CType.longlong.sizeInBits(target), 8),
            .c_ulonglong => return @divExact(CType.ulonglong.sizeInBits(target), 8),

            .f16 => return 2,
            .f32 => return 4,
            .f64 => return 8,
            .f128 => return 16,
            .c_longdouble => return 16,

            .error_set,
            .error_set_single,
            .anyerror_void_error_union,
            .anyerror,
            .error_set_inferred,
            .error_set_merged,
            => return 2, // TODO revisit this when we have the concept of the error tag type

            .int_signed, .int_unsigned => {
                const bits: u16 = self.cast(Payload.Bits).?.data;
                if (bits == 0) return 0;
                return std.math.ceilPowerOfTwoPromote(u16, (bits + 7) / 8);
            },

            .optional => {
                var buf: Payload.ElemType = undefined;
                const child_type = self.optionalChild(&buf);
                if (!child_type.hasCodeGenBits()) return 1;

                if (child_type.zigTypeTag() == .Pointer and !child_type.isCPtr())
                    return @divExact(target.cpu.arch.ptrBitWidth(), 8);

                // Optional types are represented as a struct with the child type as the first
                // field and a boolean as the second. Since the child type's abi alignment is
                // guaranteed to be >= that of bool's (1 byte) the added size is exactly equal
                // to the child type's ABI alignment.
                return child_type.abiAlignment(target) + child_type.abiSize(target);
            },

            .error_union => {
                const data = self.castTag(.error_union).?.data;
                if (!data.error_set.hasCodeGenBits() and !data.payload.hasCodeGenBits()) {
                    return 0;
                } else if (!data.error_set.hasCodeGenBits()) {
                    return data.payload.abiSize(target);
                } else if (!data.payload.hasCodeGenBits()) {
                    return data.error_set.abiSize(target);
                }
                const code_align = abiAlignment(data.error_set, target);
                const payload_align = abiAlignment(data.payload, target);
                const big_align = @maximum(code_align, payload_align);
                const payload_size = abiSize(data.payload, target);

                var size: u64 = 0;
                size += abiSize(data.error_set, target);
                size = std.mem.alignForwardGeneric(u64, size, payload_align);
                size += payload_size;
                size = std.mem.alignForwardGeneric(u64, size, big_align);
                return size;
            },
        };
    }

    /// Asserts the type has the bit size already resolved.
    pub fn bitSize(self: Type, target: Target) u64 {
        return switch (self.tag()) {
            .fn_noreturn_no_args => unreachable, // represents machine code; not a pointer
            .fn_void_no_args => unreachable, // represents machine code; not a pointer
            .fn_naked_noreturn_no_args => unreachable, // represents machine code; not a pointer
            .fn_ccc_void_no_args => unreachable, // represents machine code; not a pointer
            .function => unreachable, // represents machine code; not a pointer
            .anyopaque => unreachable,
            .void => unreachable,
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

            .@"struct" => {
                @panic("TODO bitSize struct");
            },
            .enum_simple, .enum_full, .enum_nonexhaustive, .enum_numbered => {
                var buffer: Payload.Bits = undefined;
                const int_tag_ty = self.intTagType(&buffer);
                return int_tag_ty.bitSize(target);
            },
            .@"union", .union_tagged => {
                @panic("TODO bitSize unions");
            },

            .u8, .i8 => 8,

            .bool, .u1 => 1,

            .vector => {
                const payload = self.castTag(.vector).?.data;
                const elem_bit_size = payload.elem_type.bitSize(target);
                return elem_bit_size * payload.len;
            },
            .array_u8 => 8 * self.castTag(.array_u8).?.data,
            .array_u8_sentinel_0 => 8 * (self.castTag(.array_u8_sentinel_0).?.data + 1),
            .array => {
                const payload = self.castTag(.array).?.data;
                const elem_size = std.math.max(payload.elem_type.abiAlignment(target), payload.elem_type.abiSize(target));
                if (elem_size == 0 or payload.len == 0)
                    return 0;
                return (payload.len - 1) * 8 * elem_size + payload.elem_type.bitSize(target);
            },
            .array_sentinel => {
                const payload = self.castTag(.array_sentinel).?.data;
                const elem_size = std.math.max(
                    payload.elem_type.abiAlignment(target),
                    payload.elem_type.abiSize(target),
                );
                return payload.len * 8 * elem_size + payload.elem_type.bitSize(target);
            },
            .i16, .u16, .f16 => 16,
            .i32, .u32, .f32 => 32,
            .i64, .u64, .f64 => 64,
            .u128, .i128, .f128 => 128,

            .isize,
            .usize,
            .@"anyframe",
            .anyframe_T,
            => target.cpu.arch.ptrBitWidth(),

            .const_slice,
            .mut_slice,
            => {
                if (self.elemType().hasCodeGenBits()) {
                    return target.cpu.arch.ptrBitWidth() * 2;
                } else {
                    return target.cpu.arch.ptrBitWidth();
                }
            },
            .const_slice_u8 => target.cpu.arch.ptrBitWidth() * 2,

            .optional_single_const_pointer,
            .optional_single_mut_pointer,
            => {
                if (self.elemType().hasCodeGenBits()) {
                    return target.cpu.arch.ptrBitWidth();
                } else {
                    return 1;
                }
            },

            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .pointer,
            => {
                if (self.elemType().hasCodeGenBits()) {
                    return target.cpu.arch.ptrBitWidth();
                } else {
                    return 0;
                }
            },

            .manyptr_u8,
            .manyptr_const_u8,
            => return target.cpu.arch.ptrBitWidth(),

            .c_short => return CType.short.sizeInBits(target),
            .c_ushort => return CType.ushort.sizeInBits(target),
            .c_int => return CType.int.sizeInBits(target),
            .c_uint => return CType.uint.sizeInBits(target),
            .c_long => return CType.long.sizeInBits(target),
            .c_ulong => return CType.ulong.sizeInBits(target),
            .c_longlong => return CType.longlong.sizeInBits(target),
            .c_ulonglong => return CType.ulonglong.sizeInBits(target),
            .c_longdouble => 128,

            .error_set,
            .error_set_single,
            .anyerror_void_error_union,
            .anyerror,
            .error_set_inferred,
            .error_set_merged,
            => return 16, // TODO revisit this when we have the concept of the error tag type

            .int_signed, .int_unsigned => self.cast(Payload.Bits).?.data,

            .optional => {
                var buf: Payload.ElemType = undefined;
                const child_type = self.optionalChild(&buf);
                if (!child_type.hasCodeGenBits()) return 8;

                if (child_type.zigTypeTag() == .Pointer and !child_type.isCPtr())
                    return target.cpu.arch.ptrBitWidth();

                // Optional types are represented as a struct with the child type as the first
                // field and a boolean as the second. Since the child type's abi alignment is
                // guaranteed to be >= that of bool's (1 byte) the added size is exactly equal
                // to the child type's ABI alignment.
                return child_type.bitSize(target) + 1;
            },

            .error_union => {
                const payload = self.castTag(.error_union).?.data;
                if (!payload.error_set.hasCodeGenBits() and !payload.payload.hasCodeGenBits()) {
                    return 0;
                } else if (!payload.error_set.hasCodeGenBits()) {
                    return payload.payload.bitSize(target);
                } else if (!payload.payload.hasCodeGenBits()) {
                    return payload.error_set.bitSize(target);
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
        };
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
    pub fn ptrSize(self: Type) std.builtin.TypeInfo.Pointer.Size {
        return switch (self.tag()) {
            .const_slice,
            .mut_slice,
            .const_slice_u8,
            => .Slice,

            .many_const_pointer,
            .many_mut_pointer,
            .manyptr_u8,
            .manyptr_const_u8,
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
            .const_slice,
            .manyptr_const_u8,
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
            else => false,
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
                if (!child_type.hasCodeGenBits()) return false;
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

    /// For pointer-like optionals, it returns the pointer type. For pointers,
    /// the type is returned unmodified.
    pub fn ptrOrOptionalPtrTy(ty: Type, buf: *Payload.ElemType) ?Type {
        if (isPtrLikeOptional(ty)) return ty.optionalChild(buf);
        switch (ty.tag()) {
            .c_const_pointer,
            .c_mut_pointer,
            .single_const_pointer_to_comptime_int,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .manyptr_u8,
            .manyptr_const_u8,
            => return ty,

            .pointer => {
                if (ty.ptrSize() == .Slice) {
                    return null;
                } else {
                    return ty;
                }
            },

            .inferred_alloc_const => unreachable,
            .inferred_alloc_mut => unreachable,

            else => return null,
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
                var buf: Payload.ElemType = undefined;
                const child_type = self.optionalChild(&buf);
                // optionals of zero sized types behave like bools, not pointers
                if (!child_type.hasCodeGenBits()) return false;
                if (child_type.zigTypeTag() != .Pointer) return false;

                const info = child_type.ptrInfo().data;
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
            .manyptr_u8,
            .manyptr_const_u8,
            => Type.initTag(.u8),

            .single_const_pointer_to_comptime_int => Type.initTag(.comptime_int),
            .pointer => ty.castTag(.pointer).?.data.pointee_type,

            else => unreachable,
        };
    }

    /// Asserts the type is a pointer or array type.
    /// TODO this is deprecated in favor of `childType`.
    pub const elemType = childType;

    /// For *[N]T,  returns T.
    /// For ?*T,    returns T.
    /// For ?*[N]T, returns T.
    /// For ?[*]T,  returns T.
    /// For *T,     returns T.
    /// For [*]T,   returns T.
    /// For []T,    returns T.
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
            .manyptr_u8,
            .manyptr_const_u8,
            => Type.initTag(.u8),

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

            // TODO handle optionals

            else => unreachable,
        };
    }

    /// Returns the type of a pointer to an element.
    /// Asserts that the type is a pointer, and that the element type is indexable.
    /// For *[N]T, return *T
    /// For [*]T, returns *T
    /// For []T, returns *T
    /// Handles const-ness and address spaces in particular.
    pub fn elemPtrType(ptr_ty: Type, arena: Allocator) !Type {
        return try Type.ptr(arena, .{
            .pointee_type = ptr_ty.elemType2(),
            .mutable = ptr_ty.ptrIsMutable(),
            .@"addrspace" = ptr_ty.ptrAddressSpace(),
        });
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
            .union_tagged => ty.castTag(.union_tagged).?.data.tag_ty,

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

    pub fn unionFields(ty: Type) Module.Union.Fields {
        const union_obj = ty.cast(Payload.Union).?.data;
        assert(union_obj.haveFieldTypes());
        return union_obj.fields;
    }

    pub fn unionFieldType(ty: Type, enum_tag: Value) Type {
        const union_obj = ty.cast(Payload.Union).?.data;
        const index = union_obj.tag_ty.enumTagFieldIndex(enum_tag).?;
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

    /// Asserts the type is an array or vector.
    pub fn arrayLen(ty: Type) u64 {
        return switch (ty.tag()) {
            .vector => ty.castTag(.vector).?.data.len,
            .array => ty.castTag(.array).?.data.len,
            .array_sentinel => ty.castTag(.array_sentinel).?.data.len,
            .array_u8 => ty.castTag(.array_u8).?.data,
            .array_u8_sentinel_0 => ty.castTag(.array_u8_sentinel_0).?.data,

            else => unreachable,
        };
    }

    pub fn arrayLenIncludingSentinel(ty: Type) u64 {
        return ty.arrayLen() + @boolToInt(ty.sentinel() != null);
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
            => return null,

            .pointer => return self.castTag(.pointer).?.data.sentinel,
            .array_sentinel => return self.castTag(.array_sentinel).?.data.sentinel,
            .array_u8_sentinel_0 => return Value.zero,

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
            .u32,
            .u64,
            .u128,
            => true,

            else => false,
        };
    }

    /// Asserts the type is an integer, enum, or error set.
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
            .enum_numbered => ty = self.castTag(.enum_numbered).?.data.tag_ty,
            .enum_simple => {
                const enum_obj = self.castTag(.enum_simple).?.data;
                const field_count = enum_obj.fields.count();
                if (field_count == 0) return .{ .signedness = .unsigned, .bits = 0 };
                return .{ .signedness = .unsigned, .bits = smallestUnsignedBits(field_count - 1) };
            },

            .error_set, .error_set_single, .anyerror, .error_set_inferred, .error_set_merged => {
                // TODO revisit this when error sets support custom int types
                return .{ .signedness = .unsigned, .bits = 16 };
            },

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
                .is_var_args = false,
                .is_generic = false,
            },
            .fn_void_no_args => .{
                .param_types = &.{},
                .comptime_params = undefined,
                .return_type = initTag(.void),
                .cc = .Unspecified,
                .is_var_args = false,
                .is_generic = false,
            },
            .fn_naked_noreturn_no_args => .{
                .param_types = &.{},
                .comptime_params = undefined,
                .return_type = initTag(.noreturn),
                .cc = .Naked,
                .is_var_args = false,
                .is_generic = false,
            },
            .fn_ccc_void_no_args => .{
                .param_types = &.{},
                .comptime_params = undefined,
                .return_type = initTag(.void),
                .cc = .C,
                .is_var_args = false,
                .is_generic = false,
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
            .f128,
            .c_longdouble,
            .comptime_int,
            .comptime_float,
            .u1,
            .u8,
            .i8,
            .u16,
            .i16,
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
            .f128,
            .c_longdouble,
            .comptime_int,
            .comptime_float,
            .u1,
            .u8,
            .i8,
            .u16,
            .i16,
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
            .fn_noreturn_no_args,
            .fn_void_no_args,
            .fn_naked_noreturn_no_args,
            .fn_ccc_void_no_args,
            .function,
            .single_const_pointer_to_comptime_int,
            .array_sentinel,
            .array_u8_sentinel_0,
            .const_slice_u8,
            .const_slice,
            .mut_slice,
            .anyopaque,
            .optional,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            .enum_literal,
            .anyerror_void_error_union,
            .error_union,
            .error_set,
            .error_set_single,
            .error_set_inferred,
            .error_set_merged,
            .@"opaque",
            .var_args_param,
            .manyptr_u8,
            .manyptr_const_u8,
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
                    return enum_full.values.keys()[0];
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
                if (!tag_ty.hasCodeGenBits()) {
                    return Value.zero;
                } else {
                    return null;
                }
            },
            .@"union" => {
                return null; // TODO
            },
            .union_tagged => {
                return null; // TODO
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

    pub fn isIndexable(ty: Type) bool {
        return switch (ty.zigTypeTag()) {
            .Array, .Vector => true,
            .Pointer => switch (ty.ptrSize()) {
                .Slice, .Many, .C => true,
                .One => ty.elemType().zigTypeTag() == .Array,
            },
            else => false, // TODO tuples are indexable
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
    pub fn enumTagFieldIndex(ty: Type, enum_tag: Value) ?usize {
        if (enum_tag.castTag(.enum_field_index)) |payload| {
            return @as(usize, payload.data);
        }
        const S = struct {
            fn fieldWithRange(int_ty: Type, int_val: Value, end: usize) ?usize {
                if (int_val.compareWithZero(.lt)) return null;
                var end_payload: Value.Payload.U64 = .{
                    .base = .{ .tag = .int_u64 },
                    .data = end,
                };
                const end_val = Value.initPayload(&end_payload.base);
                if (int_val.compare(.gte, end_val, int_ty)) return null;
                return @intCast(usize, int_val.toUnsignedInt());
            }
        };
        switch (ty.tag()) {
            .enum_full, .enum_nonexhaustive => {
                const enum_full = ty.cast(Payload.EnumFull).?.data;
                const tag_ty = enum_full.tag_ty;
                if (enum_full.values.count() == 0) {
                    return S.fieldWithRange(tag_ty, enum_tag, enum_full.fields.count());
                } else {
                    return enum_full.values.getIndexContext(enum_tag, .{ .ty = tag_ty });
                }
            },
            .enum_numbered => {
                const enum_obj = ty.castTag(.enum_numbered).?.data;
                const tag_ty = enum_obj.tag_ty;
                if (enum_obj.values.count() == 0) {
                    return S.fieldWithRange(tag_ty, enum_tag, enum_obj.fields.count());
                } else {
                    return enum_obj.values.getIndexContext(enum_tag, .{ .ty = tag_ty });
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
                return S.fieldWithRange(tag_ty, enum_tag, fields_len);
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
            .empty_struct => return .{},
            .@"struct" => {
                const struct_obj = ty.castTag(.@"struct").?.data;
                assert(struct_obj.haveFieldTypes());
                return struct_obj.fields;
            },
            else => unreachable,
        }
    }

    pub fn structFieldCount(ty: Type) usize {
        switch (ty.tag()) {
            .@"struct" => {
                const struct_obj = ty.castTag(.@"struct").?.data;
                return struct_obj.fields.count();
            },
            .empty_struct => return 0,
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
            else => unreachable,
        }
    }

    /// Supports structs and unions.
    pub fn structFieldOffset(ty: Type, index: usize, target: Target) u64 {
        switch (ty.tag()) {
            .@"struct" => {
                const struct_obj = ty.castTag(.@"struct").?.data;
                assert(struct_obj.status == .have_layout);
                const is_packed = struct_obj.layout == .Packed;
                if (is_packed) @panic("TODO packed structs");

                var offset: u64 = 0;
                var big_align: u32 = 0;
                for (struct_obj.fields.values()) |field, i| {
                    if (!field.ty.hasCodeGenBits()) continue;

                    const field_align = a: {
                        if (field.abi_align.tag() == .abi_align_default) {
                            break :a field.ty.abiAlignment(target);
                        } else {
                            break :a @intCast(u32, field.abi_align.toUnsignedInt());
                        }
                    };
                    big_align = @maximum(big_align, field_align);
                    offset = std.mem.alignForwardGeneric(u64, offset, field_align);
                    if (i == index) return offset;
                    offset += field.ty.abiSize(target);
                }
                offset = std.mem.alignForwardGeneric(u64, offset, big_align);
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

    pub fn declSrcLoc(ty: Type) Module.SrcLoc {
        return declSrcLocOrNull(ty).?;
    }

    pub fn declSrcLocOrNull(ty: Type) ?Module.SrcLoc {
        switch (ty.tag()) {
            .enum_full, .enum_nonexhaustive => {
                const enum_full = ty.cast(Payload.EnumFull).?.data;
                return enum_full.srcLoc();
            },
            .enum_numbered => return ty.castTag(.enum_numbered).?.data.srcLoc(),
            .enum_simple => {
                const enum_simple = ty.castTag(.enum_simple).?.data;
                return enum_simple.srcLoc();
            },
            .@"struct" => {
                const struct_obj = ty.castTag(.@"struct").?.data;
                return struct_obj.srcLoc();
            },
            .error_set => {
                const error_set = ty.castTag(.error_set).?.data;
                return error_set.srcLoc();
            },
            .@"union", .union_tagged => {
                const union_obj = ty.cast(Payload.Union).?.data;
                return union_obj.srcLoc();
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

    pub fn getOwnerDecl(ty: Type) *Module.Decl {
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
            .@"opaque" => @panic("TODO"),
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
            => @panic("TODO resolve std.builtin types"),
            else => unreachable,
        }
    }

    /// Asserts the type is an enum.
    pub fn enumHasInt(ty: Type, int: Value, target: Target) bool {
        const S = struct {
            fn intInRange(tag_ty: Type, int_val: Value, end: usize) bool {
                if (int_val.compareWithZero(.lt)) return false;
                var end_payload: Value.Payload.U64 = .{
                    .base = .{ .tag = .int_u64 },
                    .data = end,
                };
                const end_val = Value.initPayload(&end_payload.base);
                if (int_val.compare(.gte, end_val, tag_ty)) return false;
                return true;
            }
        };
        switch (ty.tag()) {
            .enum_nonexhaustive => return int.intFitsInType(ty, target),
            .enum_full => {
                const enum_full = ty.castTag(.enum_full).?.data;
                const tag_ty = enum_full.tag_ty;
                if (enum_full.values.count() == 0) {
                    return S.intInRange(tag_ty, int, enum_full.fields.count());
                } else {
                    return enum_full.values.containsContext(int, .{ .ty = tag_ty });
                }
            },
            .enum_numbered => {
                const enum_obj = ty.castTag(.enum_numbered).?.data;
                const tag_ty = enum_obj.tag_ty;
                if (enum_obj.values.count() == 0) {
                    return S.intInRange(tag_ty, int, enum_obj.fields.count());
                } else {
                    return enum_obj.values.containsContext(int, .{ .ty = tag_ty });
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
                return S.intInRange(tag_ty, int, fields_len);
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
        fn_noreturn_no_args,
        fn_void_no_args,
        fn_naked_noreturn_no_args,
        fn_ccc_void_no_args,
        single_const_pointer_to_comptime_int,
        const_slice_u8,
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
            return switch (t) {
                .u1,
                .u8,
                .i8,
                .u16,
                .i16,
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
                .generic_poison,
                .inferred_alloc_const,
                .inferred_alloc_mut,
                .var_args_param,
                .empty_struct_literal,
                .manyptr_u8,
                .manyptr_const_u8,
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
                cc: std.builtin.CallingConvention,
                is_var_args: bool,
                is_generic: bool,

                pub fn paramIsComptime(self: @This(), i: usize) bool {
                    if (!self.is_generic) return false;
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
            data: []const []const u8,
        };

        pub const ErrorSetInferred = struct {
            pub const base_tag = Tag.error_set_inferred;

            base: Payload = Payload{ .tag = base_tag },
            data: Data,

            pub const Data = struct {
                func: *Module.Fn,
                /// Direct additions to the inferred error set via `return error.Foo;`.
                map: std.StringHashMapUnmanaged(void),
                /// Other functions with inferred error sets which this error set includes.
                functions: std.AutoHashMapUnmanaged(*Module.Fn, void),
                is_anyerror: bool,

                pub fn addErrorSet(self: *Data, gpa: Allocator, err_set_ty: Type) !void {
                    switch (err_set_ty.tag()) {
                        .error_set => {
                            const names = err_set_ty.castTag(.error_set).?.data.names();
                            for (names) |name| {
                                try self.map.put(gpa, name, {});
                            }
                        },
                        .error_set_single => {
                            const name = err_set_ty.castTag(.error_set_single).?.data;
                            try self.map.put(gpa, name, {});
                        },
                        .error_set_inferred => {
                            const func = err_set_ty.castTag(.error_set_inferred).?.data.func;
                            try self.functions.put(gpa, func, {});
                            var it = func.owner_decl.ty.fnReturnType().errorUnionSet()
                                .castTag(.error_set_inferred).?.data.map.iterator();
                            while (it.next()) |entry| {
                                try self.map.put(gpa, entry.key_ptr.*, {});
                            }
                        },
                        .error_set_merged => {
                            const names = err_set_ty.castTag(.error_set_merged).?.data;
                            for (names) |name| {
                                try self.map.put(gpa, name, {});
                            }
                        },
                        .anyerror => {
                            self.is_anyerror = true;
                        },
                        else => unreachable,
                    }
                }
            };
        };

        pub const Pointer = struct {
            pub const base_tag = Tag.pointer;

            base: Payload = Payload{ .tag = base_tag },
            data: Data,

            pub const Data = struct {
                pointee_type: Type,
                sentinel: ?Value = null,
                /// If zero use pointee_type.AbiAlign()
                @"align": u32 = 0,
                /// See src/target.zig defaultAddressSpace function for how to obtain
                /// an appropriate value for this field.
                @"addrspace": std.builtin.AddressSpace,
                bit_offset: u16 = 0,
                host_size: u16 = 0,
                @"allowzero": bool = false,
                mutable: bool = true, // TODO rename this to const, not mutable
                @"volatile": bool = false,
                size: std.builtin.TypeInfo.Pointer.Size = .One,
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

    pub const @"u8" = initTag(.u8);
    pub const @"bool" = initTag(.bool);
    pub const @"usize" = initTag(.usize);
    pub const @"isize" = initTag(.isize);
    pub const @"comptime_int" = initTag(.comptime_int);
    pub const @"void" = initTag(.void);
    pub const @"type" = initTag(.type);
    pub const @"anyerror" = initTag(.anyerror);

    pub fn ptr(arena: Allocator, d: Payload.Pointer.Data) !Type {
        assert(d.host_size == 0 or d.bit_offset < d.host_size * 8);

        if (d.sentinel != null or d.@"align" != 0 or d.@"addrspace" != .generic or
            d.bit_offset != 0 or d.host_size != 0 or d.@"allowzero" or d.@"volatile")
        {
            if (d.size == .C) {
                assert(d.@"allowzero"); // All C pointers must set allowzero to true.
            }
            return Type.Tag.pointer.create(arena, d);
        }

        if (!d.mutable and d.size == .Slice and d.pointee_type.eql(Type.initTag(.u8))) {
            return Type.initTag(.const_slice_u8);
        }

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

    pub fn array(
        arena: Allocator,
        len: u64,
        sent: ?Value,
        elem_type: Type,
    ) Allocator.Error!Type {
        if (elem_type.eql(Type.u8)) {
            if (sent) |some| {
                if (some.eql(Value.zero, elem_type)) {
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
                    .short,
                    .ushort,
                    .int,
                    .uint,
                    => return 16,
                    .long,
                    .ulong,
                    => return 32,
                    .longlong,
                    .ulonglong,
                    => return 64,
                    .longdouble => @panic("TODO figure out what kind of float `long double` is on this target"),
                },
                else => switch (self) {
                    .short,
                    .ushort,
                    => return 16,
                    .int,
                    .uint,
                    => return 32,
                    .long,
                    .ulong,
                    => return target.cpu.arch.ptrBitWidth(),
                    .longlong,
                    .ulonglong,
                    => return 64,
                    .longdouble => @panic("TODO figure out what kind of float `long double` is on this target"),
                },
            },

            .linux,
            .macos,
            .freebsd,
            .netbsd,
            .dragonfly,
            .openbsd,
            .wasi,
            .emscripten,
            .plan9,
            .solaris,
            => switch (self) {
                .short,
                .ushort,
                => return 16,
                .int,
                .uint,
                => return 32,
                .long,
                .ulong,
                => return target.cpu.arch.ptrBitWidth(),
                .longlong,
                .ulonglong,
                => return 64,
                .longdouble => @panic("TODO figure out what kind of float `long double` is on this target"),
            },

            .windows, .uefi => switch (self) {
                .short,
                .ushort,
                => return 16,
                .int,
                .uint,
                .long,
                .ulong,
                => return 32,
                .longlong,
                .ulonglong,
                => return 64,
                .longdouble => @panic("TODO figure out what kind of float `long double` is on this target"),
            },

            .ios => switch (self) {
                .short,
                .ushort,
                => return 16,
                .int,
                .uint,
                => return 32,
                .long,
                .ulong,
                .longlong,
                .ulonglong,
                => return 64,
                .longdouble => @panic("TODO figure out what kind of float `long double` is on this target"),
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
            .tvos,
            .watchos,
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
