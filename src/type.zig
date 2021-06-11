const std = @import("std");
const Value = @import("value.zig").Value;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Target = std.Target;
const Module = @import("Module.zig");
const log = std.log.scoped(.Type);

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
    tag_if_small_enough: usize,
    ptr_otherwise: *Payload,

    pub fn zigTypeTag(self: Type) std.builtin.TypeId {
        switch (self.tag()) {
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

            .c_void, .@"opaque" => return .Opaque,
            .bool => return .Bool,
            .void => return .Void,
            .type => return .Type,
            .error_set, .error_set_single, .anyerror => return .ErrorSet,
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
            .export_options,
            .extern_options,
            => return .Struct,

            .enum_full,
            .enum_nonexhaustive,
            .enum_simple,
            .atomic_ordering,
            .atomic_rmw_op,
            .calling_convention,
            .float_mode,
            .reduce_op,
            => return .Enum,

            .@"union",
            .union_tagged,
            => return .Union,

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
            .Optional => is_equality_cmp and ty.isPtrLikeOptional(),
        };
    }

    pub fn initTag(comptime small_tag: Tag) Type {
        comptime assert(@enumToInt(small_tag) < Tag.no_payload_count);
        return .{ .tag_if_small_enough = @enumToInt(small_tag) };
    }

    pub fn initPayload(payload: *Payload) Type {
        assert(@enumToInt(payload.tag) >= Tag.no_payload_count);
        return .{ .ptr_otherwise = payload };
    }

    pub fn tag(self: Type) Tag {
        if (self.tag_if_small_enough < Tag.no_payload_count) {
            return @intToEnum(Tag, @intCast(std.meta.Tag(Tag), self.tag_if_small_enough));
        } else {
            return self.ptr_otherwise.tag;
        }
    }

    /// Prefer `castTag` to this.
    pub fn cast(self: Type, comptime T: type) ?*T {
        if (@hasField(T, "base_tag")) {
            return base.castTag(T.base_tag);
        }
        if (self.tag_if_small_enough < Tag.no_payload_count) {
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
        if (self.tag_if_small_enough < Tag.no_payload_count)
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

    pub fn ptrInfo(self: Type) Payload.Pointer {
        switch (self.tag()) {
            .single_const_pointer_to_comptime_int => return .{ .data = .{
                .pointee_type = Type.initTag(.comptime_int),
                .sentinel = null,
                .@"align" = 0,
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
                .bit_offset = 0,
                .host_size = 0,
                .@"allowzero" = false,
                .mutable = false,
                .@"volatile" = false,
                .size = .C,
            } },
            .c_mut_pointer => return .{ .data = .{
                .pointee_type = self.castPointer().?.data,
                .sentinel = null,
                .@"align" = 0,
                .bit_offset = 0,
                .host_size = 0,
                .@"allowzero" = false,
                .mutable = true,
                .@"volatile" = false,
                .size = .C,
            } },
            .const_slice => return .{ .data = .{
                .pointee_type = self.castPointer().?.data,
                .sentinel = null,
                .@"align" = 0,
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

                const sentinel_a = info_a.sentinel;
                const sentinel_b = info_b.sentinel;
                if (sentinel_a) |sa| {
                    if (sentinel_b) |sb| {
                        if (!sa.eql(sb))
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
                if (!a.elemType().eql(b.elemType()))
                    return false;
                const sentinel_a = a.sentinel();
                const sentinel_b = b.sentinel();
                if (sentinel_a) |sa| {
                    if (sentinel_b) |sb| {
                        return sa.eql(sb);
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
            .Union => {
                if (a.cast(Payload.Union)) |a_payload| {
                    if (b.cast(Payload.Union)) |b_payload| {
                        return a_payload.data == b_payload.data;
                    }
                }
                return a.tag() == b.tag();
            },
            .Opaque,
            .Float,
            .ErrorUnion,
            .ErrorSet,
            .BoundFn,
            .Frame,
            => std.debug.panic("TODO implement Type equality comparison of {} and {}", .{ a, b }),
        }
    }

    pub fn hash(self: Type) u64 {
        var hasher = std.hash.Wyhash.init(0);
        const zig_type_tag = self.zigTypeTag();
        std.hash.autoHash(&hasher, zig_type_tag);
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
                    std.hash.autoHash(&hasher, self.tag());
                } else {
                    // Remaining cases are arbitrary sized integers.
                    // The target will not be branched upon, because we handled target-dependent cases above.
                    const info = self.intInfo(@as(Target, undefined));
                    std.hash.autoHash(&hasher, info.signedness);
                    std.hash.autoHash(&hasher, info.bits);
                }
            },
            .Array, .Vector => {
                std.hash.autoHash(&hasher, self.arrayLen());
                std.hash.autoHash(&hasher, self.elemType().hash());
                // TODO hash array sentinel
            },
            .Fn => {
                std.hash.autoHash(&hasher, self.fnReturnType().hash());
                std.hash.autoHash(&hasher, self.fnCallingConvention());
                const params_len = self.fnParamLen();
                std.hash.autoHash(&hasher, params_len);
                var i: usize = 0;
                while (i < params_len) : (i += 1) {
                    std.hash.autoHash(&hasher, self.fnParamType(i).hash());
                }
                std.hash.autoHash(&hasher, self.fnIsVarArgs());
            },
            .Optional => {
                var buf: Payload.ElemType = undefined;
                std.hash.autoHash(&hasher, self.optionalChild(&buf).hash());
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
        return hasher.final();
    }

    pub const HashContext = struct {
        pub fn hash(self: @This(), t: Type) u64 {
            return t.hash();
        }
        pub fn eql(self: @This(), a: Type, b: Type) bool {
            return a.eql(b);
        }
    };

    pub fn copy(self: Type, allocator: *Allocator) error{OutOfMemory}!Type {
        if (self.tag_if_small_enough < Tag.no_payload_count) {
            return Type{ .tag_if_small_enough = self.tag_if_small_enough };
        } else switch (self.ptr_otherwise.tag) {
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
            .c_void,
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
            .atomic_ordering,
            .atomic_rmw_op,
            .calling_convention,
            .float_mode,
            .reduce_op,
            .call_options,
            .export_options,
            .extern_options,
            .@"anyframe",
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
            => return self.copyPayloadShallow(allocator, Payload.ElemType),

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
                return Tag.function.create(allocator, .{
                    .return_type = try payload.return_type.copy(allocator),
                    .param_types = param_types,
                    .cc = payload.cc,
                    .is_var_args = payload.is_var_args,
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
            .error_set => return self.copyPayloadShallow(allocator, Payload.ErrorSet),
            .error_set_single => return self.copyPayloadShallow(allocator, Payload.Name),
            .empty_struct => return self.copyPayloadShallow(allocator, Payload.ContainerScope),
            .@"struct" => return self.copyPayloadShallow(allocator, Payload.Struct),
            .@"union", .union_tagged => return self.copyPayloadShallow(allocator, Payload.Union),
            .enum_simple => return self.copyPayloadShallow(allocator, Payload.EnumSimple),
            .enum_full, .enum_nonexhaustive => return self.copyPayloadShallow(allocator, Payload.EnumFull),
            .@"opaque" => return self.copyPayloadShallow(allocator, Payload.Opaque),
        }
    }

    fn copyPayloadShallow(self: Type, allocator: *Allocator, comptime T: type) error{OutOfMemory}!Type {
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
        comptime assert(fmt.len == 0);
        var ty = start_type;
        while (true) {
            const t = ty.tag();
            switch (t) {
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
                .c_void,
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
                .atomic_ordering => return writer.writeAll("std.builtin.AtomicOrdering"),
                .atomic_rmw_op => return writer.writeAll("std.builtin.AtomicRmwOp"),
                .calling_convention => return writer.writeAll("std.builtin.CallingConvention"),
                .float_mode => return writer.writeAll("std.builtin.FloatMode"),
                .reduce_op => return writer.writeAll("std.builtin.ReduceOp"),
                .call_options => return writer.writeAll("std.builtin.CallOptions"),
                .export_options => return writer.writeAll("std.builtin.ExportOptions"),
                .extern_options => return writer.writeAll("std.builtin.ExternOptions"),
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
                    try writer.writeAll(")");
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
                    if (!payload.mutable) try writer.writeAll("const ");
                    if (payload.@"volatile") try writer.writeAll("volatile ");
                    if (payload.@"allowzero") try writer.writeAll("allowzero ");

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
                    return writer.writeAll(std.mem.spanZ(error_set.owner_decl.name));
                },
                .error_set_single => {
                    const name = ty.castTag(.error_set_single).?.data;
                    return writer.print("error{{{s}}}", .{name});
                },
                .inferred_alloc_const => return writer.writeAll("(inferred_alloc_const)"),
                .inferred_alloc_mut => return writer.writeAll("(inferred_alloc_mut)"),
            }
            unreachable;
        }
    }

    pub fn toValue(self: Type, allocator: *Allocator) Allocator.Error!Value {
        switch (self.tag()) {
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
            .c_void => return Value.initTag(.c_void_type),
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
            .atomic_ordering => return Value.initTag(.atomic_ordering_type),
            .atomic_rmw_op => return Value.initTag(.atomic_rmw_op_type),
            .calling_convention => return Value.initTag(.calling_convention_type),
            .float_mode => return Value.initTag(.float_mode_type),
            .reduce_op => return Value.initTag(.reduce_op_type),
            .call_options => return Value.initTag(.call_options_type),
            .export_options => return Value.initTag(.export_options_type),
            .extern_options => return Value.initTag(.extern_options_type),
            .inferred_alloc_const => unreachable,
            .inferred_alloc_mut => unreachable,
            else => return Value.Tag.ty.create(allocator, self),
        }
    }

    pub fn hasCodeGenBits(self: Type) bool {
        return switch (self.tag()) {
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
            .fn_noreturn_no_args,
            .fn_void_no_args,
            .fn_naked_noreturn_no_args,
            .fn_ccc_void_no_args,
            .function,
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            .array_u8_sentinel_0,
            .optional,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            .anyerror_void_error_union,
            .error_set,
            .error_set_single,
            .manyptr_u8,
            .manyptr_const_u8,
            .atomic_ordering,
            .atomic_rmw_op,
            .calling_convention,
            .float_mode,
            .reduce_op,
            .call_options,
            .export_options,
            .extern_options,
            .@"anyframe",
            .anyframe_T,
            => true,

            .@"struct" => {
                // TODO introduce lazy value mechanism
                const struct_obj = self.castTag(.@"struct").?.data;
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
            .enum_nonexhaustive => {
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
                const union_obj = self.castTag(.@"union").?.data;
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

            // TODO lazy types
            .array, .vector => self.elemType().hasCodeGenBits() and self.arrayLen() != 0,
            .array_u8 => self.arrayLen() != 0,
            .array_sentinel, .single_const_pointer, .single_mut_pointer, .many_const_pointer, .many_mut_pointer, .c_const_pointer, .c_mut_pointer, .const_slice, .mut_slice, .pointer => self.elemType().hasCodeGenBits(),
            .int_signed, .int_unsigned => self.cast(Payload.Bits).?.data != 0,

            .error_union => {
                const payload = self.castTag(.error_union).?.data;
                return payload.error_set.hasCodeGenBits() or payload.payload.hasCodeGenBits();
            },

            .c_void,
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
            .@"opaque",
            => false,

            .inferred_alloc_const => unreachable,
            .inferred_alloc_mut => unreachable,
            .var_args_param => unreachable,
        };
    }

    pub fn isNoReturn(self: Type) bool {
        const definitely_correct_result = self.zigTypeTag() == .NoReturn;
        const fast_result = self.tag_if_small_enough == @enumToInt(Tag.noreturn);
        assert(fast_result == definitely_correct_result);
        return fast_result;
    }

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

    /// Asserts that hasCodeGenBits() is true.
    pub fn abiAlignment(self: Type, target: Target) u32 {
        return switch (self.tag()) {
            .u8,
            .i8,
            .bool,
            .array_u8_sentinel_0,
            .array_u8,
            .atomic_ordering,
            .atomic_rmw_op,
            .calling_convention,
            .float_mode,
            .reduce_op,
            .call_options,
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
            => return 2, // TODO revisit this when we have the concept of the error tag type

            .array, .array_sentinel => return self.elemType().abiAlignment(target),

            // TODO audit this - is there any more complicated logic to determine
            // ABI alignment of vectors?
            .vector => return 16,

            .int_signed, .int_unsigned => {
                const bits: u16 = self.cast(Payload.Bits).?.data;
                return std.math.ceilPowerOfTwoPromote(u16, (bits + 7) / 8);
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
                const payload = self.castTag(.error_union).?.data;
                if (!payload.error_set.hasCodeGenBits()) {
                    return payload.payload.abiAlignment(target);
                } else if (!payload.payload.hasCodeGenBits()) {
                    return payload.error_set.abiAlignment(target);
                }
                return std.math.max(
                    payload.payload.abiAlignment(target),
                    payload.error_set.abiAlignment(target),
                );
            },

            .@"struct" => {
                // TODO take into account field alignment
                // also make this possible to fail, and lazy
                // I think we need to move all the functions from type.zig which can
                // fail into Sema.
                // Probably will need to introduce multi-stage struct resolution just
                // like we have in stage1.
                const struct_obj = self.castTag(.@"struct").?.data;
                var biggest: u32 = 0;
                for (struct_obj.fields.values()) |field| {
                    if (!field.ty.hasCodeGenBits()) continue;
                    const field_align = field.ty.abiAlignment(target);
                    if (field_align > biggest) {
                        return field_align;
                    }
                }
                assert(biggest != 0);
                return biggest;
            },
            .enum_full, .enum_nonexhaustive, .enum_simple => {
                var buffer: Payload.Bits = undefined;
                const int_tag_ty = self.intTagType(&buffer);
                return int_tag_ty.abiAlignment(target);
            },
            .union_tagged => {
                const union_obj = self.castTag(.union_tagged).?.data;
                var biggest: u32 = union_obj.tag_ty.abiAlignment(target);
                for (union_obj.fields.values()) |field| {
                    if (!field.ty.hasCodeGenBits()) continue;
                    const field_align = field.ty.abiAlignment(target);
                    if (field_align > biggest) {
                        biggest = field_align;
                    }
                }
                assert(biggest != 0);
                return biggest;
            },
            .@"union" => {
                const union_obj = self.castTag(.@"union").?.data;
                var biggest: u32 = 0;
                for (union_obj.fields.values()) |field| {
                    if (!field.ty.hasCodeGenBits()) continue;
                    const field_align = field.ty.abiAlignment(target);
                    if (field_align > biggest) {
                        biggest = field_align;
                    }
                }
                assert(biggest != 0);
                return biggest;
            },
            .c_void,
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
            .inferred_alloc_const,
            .inferred_alloc_mut,
            .@"opaque",
            .var_args_param,
            => unreachable,
        };
    }

    /// Asserts the type has the ABI size already resolved.
    pub fn abiSize(self: Type, target: Target) u64 {
        return switch (self.tag()) {
            .fn_noreturn_no_args => unreachable, // represents machine code; not a pointer
            .fn_void_no_args => unreachable, // represents machine code; not a pointer
            .fn_naked_noreturn_no_args => unreachable, // represents machine code; not a pointer
            .fn_ccc_void_no_args => unreachable, // represents machine code; not a pointer
            .function => unreachable, // represents machine code; not a pointer
            .c_void => unreachable,
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

            .@"struct" => {
                @panic("TODO abiSize struct");
            },
            .enum_simple, .enum_full, .enum_nonexhaustive => {
                var buffer: Payload.Bits = undefined;
                const int_tag_ty = self.intTagType(&buffer);
                return int_tag_ty.abiSize(target);
            },
            .@"union", .union_tagged => {
                @panic("TODO abiSize unions");
            },

            .u8,
            .i8,
            .bool,
            .atomic_ordering,
            .atomic_rmw_op,
            .calling_convention,
            .float_mode,
            .reduce_op,
            .call_options,
            .export_options,
            .extern_options,
            => return 1,

            .array_u8 => self.castTag(.array_u8).?.data,
            .array_u8_sentinel_0 => self.castTag(.array_u8_sentinel_0).?.data + 1,
            .array, .vector => {
                const payload = self.cast(Payload.Array).?.data;
                const elem_size = std.math.max(payload.elem_type.abiAlignment(target), payload.elem_type.abiSize(target));
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
                if (self.elemType().hasCodeGenBits()) return 1;
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
                if (self.elemType().hasCodeGenBits()) return 0;
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
            => return 2, // TODO revisit this when we have the concept of the error tag type

            .int_signed, .int_unsigned => {
                const bits: u16 = self.cast(Payload.Bits).?.data;
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
                const payload = self.castTag(.error_union).?.data;
                if (!payload.error_set.hasCodeGenBits() and !payload.payload.hasCodeGenBits()) {
                    return 0;
                } else if (!payload.error_set.hasCodeGenBits()) {
                    return payload.payload.abiSize(target);
                } else if (!payload.payload.hasCodeGenBits()) {
                    return payload.error_set.abiSize(target);
                }
                @panic("TODO abiSize error union");
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
            .c_void => unreachable,
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

            .@"struct" => {
                @panic("TODO bitSize struct");
            },
            .enum_simple, .enum_full, .enum_nonexhaustive => {
                var buffer: Payload.Bits = undefined;
                const int_tag_ty = self.intTagType(&buffer);
                return int_tag_ty.bitSize(target);
            },
            .@"union", .union_tagged => {
                @panic("TODO bitSize unions");
            },

            .u8, .i8 => 8,

            .bool => 1,

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

            .atomic_ordering,
            .atomic_rmw_op,
            .calling_convention,
            .float_mode,
            .reduce_op,
            .call_options,
            .export_options,
            .extern_options,
            => @panic("TODO at some point we gotta resolve builtin types"),
        };
    }

    /// Asserts the type is an enum.
    pub fn intTagType(self: Type, buffer: *Payload.Bits) Type {
        switch (self.tag()) {
            .enum_full, .enum_nonexhaustive => return self.cast(Payload.EnumFull).?.data.tag_ty,
            .enum_simple => {
                const enum_simple = self.castTag(.enum_simple).?.data;
                const bits = std.math.log2_int_ceil(usize, enum_simple.fields.count());
                buffer.* = .{
                    .base = .{ .tag = .int_unsigned },
                    .data = bits,
                };
                return Type.initPayload(&buffer.base);
            },
            else => unreachable,
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

    /// Asserts that the type is an optional
    pub fn isPtrLikeOptional(self: Type) bool {
        switch (self.tag()) {
            .optional_single_const_pointer, .optional_single_mut_pointer => return true,
            .optional => {
                var buf: Payload.ElemType = undefined;
                const child_type = self.optionalChild(&buf);
                // optionals of zero sized pointers behave like bools
                if (!child_type.hasCodeGenBits()) return false;

                return child_type.zigTypeTag() == .Pointer and !child_type.isCPtr();
            },
            else => unreachable,
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
            .ErrorUnion => ty = ty.errorUnionChild(),

            .Fn => @panic("TODO fn isValidVarType"),
            .Struct => {
                // TODO this is not always correct; introduce lazy value mechanism
                // and here we need to force a resolve of "type requires comptime".
                return true;
            },
            .Union => @panic("TODO union isValidVarType"),
        };
    }

    /// Asserts the type is a pointer or array type.
    pub fn elemType(self: Type) Type {
        return switch (self.tag()) {
            .vector => self.castTag(.vector).?.data.elem_type,
            .array => self.castTag(.array).?.data.elem_type,
            .array_sentinel => self.castTag(.array_sentinel).?.data.elem_type,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            => self.castPointer().?.data,

            .array_u8,
            .array_u8_sentinel_0,
            .const_slice_u8,
            .manyptr_u8,
            .manyptr_const_u8,
            => Type.initTag(.u8),

            .single_const_pointer_to_comptime_int => Type.initTag(.comptime_int),
            .pointer => self.castTag(.pointer).?.data.pointee_type,

            else => unreachable,
        };
    }

    /// Asserts that the type is an optional.
    /// Resulting `Type` will have inner memory referencing `buf`.
    pub fn optionalChild(self: Type, buf: *Payload.ElemType) Type {
        return switch (self.tag()) {
            .optional => self.castTag(.optional).?.data,
            .optional_single_mut_pointer => {
                buf.* = .{
                    .base = .{ .tag = .single_mut_pointer },
                    .data = self.castPointer().?.data,
                };
                return Type.initPayload(&buf.base);
            },
            .optional_single_const_pointer => {
                buf.* = .{
                    .base = .{ .tag = .single_const_pointer },
                    .data = self.castPointer().?.data,
                };
                return Type.initPayload(&buf.base);
            },
            else => unreachable,
        };
    }

    /// Asserts that the type is an optional.
    /// Same as `optionalChild` but allocates the buffer if needed.
    pub fn optionalChildAlloc(self: Type, allocator: *Allocator) !Type {
        switch (self.tag()) {
            .optional => return self.castTag(.optional).?.data,
            .optional_single_mut_pointer => {
                return Tag.single_mut_pointer.create(allocator, self.castPointer().?.data);
            },
            .optional_single_const_pointer => {
                return Tag.single_const_pointer.create(allocator, self.castPointer().?.data);
            },
            else => unreachable,
        }
    }

    /// Asserts that the type is an error union.
    pub fn errorUnionChild(self: Type) Type {
        return switch (self.tag()) {
            .anyerror_void_error_union => Type.initTag(.anyerror),
            .error_union => {
                const payload = self.castTag(.error_union).?;
                return payload.data.payload;
            },
            else => unreachable,
        };
    }

    pub fn errorUnionSet(self: Type) Type {
        return switch (self.tag()) {
            .anyerror_void_error_union => Type.initTag(.anyerror),
            .error_union => {
                const payload = self.castTag(.error_union).?;
                return payload.data.error_set;
            },
            else => unreachable,
        };
    }

    /// Asserts the type is an array or vector.
    pub fn arrayLen(self: Type) u64 {
        return switch (self.tag()) {
            .vector => self.castTag(.vector).?.data.len,
            .array => self.castTag(.array).?.data.len,
            .array_sentinel => self.castTag(.array_sentinel).?.data.len,
            .array_u8 => self.castTag(.array_u8).?.data,
            .array_u8_sentinel_0 => self.castTag(.array_u8_sentinel_0).?.data,

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
            => return null,

            .pointer => return self.castTag(.pointer).?.data.sentinel,
            .array_sentinel => return self.castTag(.array_sentinel).?.data.sentinel,
            .array_u8_sentinel_0 => return Value.initTag(.zero),

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
            .u8,
            .usize,
            .c_ushort,
            .c_uint,
            .c_ulong,
            .c_ulonglong,
            .u16,
            .u32,
            .u64,
            .u128,
            => true,

            else => false,
        };
    }

    /// Asserts the type is an integer.
    pub fn intInfo(self: Type, target: Target) struct { signedness: std.builtin.Signedness, bits: u16 } {
        return switch (self.tag()) {
            .int_unsigned => .{
                .signedness = .unsigned,
                .bits = self.castTag(.int_unsigned).?.data,
            },
            .int_signed => .{
                .signedness = .signed,
                .bits = self.castTag(.int_signed).?.data,
            },
            .u8 => .{ .signedness = .unsigned, .bits = 8 },
            .i8 => .{ .signedness = .signed, .bits = 8 },
            .u16 => .{ .signedness = .unsigned, .bits = 16 },
            .i16 => .{ .signedness = .signed, .bits = 16 },
            .u32 => .{ .signedness = .unsigned, .bits = 32 },
            .i32 => .{ .signedness = .signed, .bits = 32 },
            .u64 => .{ .signedness = .unsigned, .bits = 64 },
            .i64 => .{ .signedness = .signed, .bits = 64 },
            .u128 => .{ .signedness = .unsigned, .bits = 128 },
            .i128 => .{ .signedness = .signed, .bits = 128 },
            .usize => .{ .signedness = .unsigned, .bits = target.cpu.arch.ptrBitWidth() },
            .isize => .{ .signedness = .signed, .bits = target.cpu.arch.ptrBitWidth() },
            .c_short => .{ .signedness = .signed, .bits = CType.short.sizeInBits(target) },
            .c_ushort => .{ .signedness = .unsigned, .bits = CType.ushort.sizeInBits(target) },
            .c_int => .{ .signedness = .signed, .bits = CType.int.sizeInBits(target) },
            .c_uint => .{ .signedness = .unsigned, .bits = CType.uint.sizeInBits(target) },
            .c_long => .{ .signedness = .signed, .bits = CType.long.sizeInBits(target) },
            .c_ulong => .{ .signedness = .unsigned, .bits = CType.ulong.sizeInBits(target) },
            .c_longlong => .{ .signedness = .signed, .bits = CType.longlong.sizeInBits(target) },
            .c_ulonglong => .{ .signedness = .unsigned, .bits = CType.ulonglong.sizeInBits(target) },

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

    pub fn isFloat(self: Type) bool {
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

    /// Asserts the type is a fixed-size float.
    pub fn floatBits(self: Type, target: Target) u16 {
        return switch (self.tag()) {
            .f16 => 16,
            .f32 => 32,
            .f64 => 64,
            .f128 => 128,
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

    pub fn isNumeric(self: Type) bool {
        return switch (self.tag()) {
            .f16,
            .f32,
            .f64,
            .f128,
            .c_longdouble,
            .comptime_int,
            .comptime_float,
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
            .c_void,
            .optional,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            .enum_literal,
            .anyerror_void_error_union,
            .error_union,
            .error_set,
            .error_set_single,
            .@"opaque",
            .var_args_param,
            .manyptr_u8,
            .manyptr_const_u8,
            .atomic_ordering,
            .atomic_rmw_op,
            .calling_convention,
            .float_mode,
            .reduce_op,
            .call_options,
            .export_options,
            .extern_options,
            .@"anyframe",
            .anyframe_T,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .single_const_pointer,
            .single_mut_pointer,
            .pointer,
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
                    return Value.initTag(.zero);
                } else {
                    return null;
                }
            },
            .enum_nonexhaustive => ty = ty.castTag(.enum_nonexhaustive).?.data.tag_ty,
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
                    return Value.initTag(.zero);
                } else {
                    return null;
                }
            },
            .vector, .array, .array_u8 => {
                if (ty.arrayLen() == 0)
                    return Value.initTag(.empty_array);
                ty = ty.elemType();
                continue;
            },

            .inferred_alloc_const => unreachable,
            .inferred_alloc_mut => unreachable,
        };
    }

    pub fn isIndexable(self: Type) bool {
        const zig_tag = self.zigTypeTag();
        // TODO tuples are indexable
        return zig_tag == .Array or zig_tag == .Vector or self.isSlice() or
            (self.isSinglePointer() and self.elemType().zigTypeTag() == .Array);
    }

    /// Returns null if the type has no namespace.
    pub fn getNamespace(self: Type) ?*Module.Scope.Namespace {
        return switch (self.tag()) {
            .@"struct" => &self.castTag(.@"struct").?.data.namespace,
            .enum_full => &self.castTag(.enum_full).?.data.namespace,
            .empty_struct => self.castTag(.empty_struct).?.data,
            .@"opaque" => &self.castTag(.@"opaque").?.data,
            .@"union" => &self.castTag(.@"union").?.data.namespace,
            .union_tagged => &self.castTag(.union_tagged).?.data.namespace,

            else => null,
        };
    }

    /// Asserts that self.zigTypeTag() == .Int.
    pub fn minInt(self: Type, arena: *std.heap.ArenaAllocator, target: Target) !Value {
        assert(self.zigTypeTag() == .Int);
        const info = self.intInfo(target);

        if (info.signedness == .unsigned) {
            return Value.initTag(.zero);
        }

        if ((info.bits - 1) <= std.math.maxInt(u6)) {
            const n: i64 = -(@as(i64, 1) << @truncate(u6, info.bits - 1));
            return Value.Tag.int_i64.create(&arena.allocator, n);
        }

        var res = try std.math.big.int.Managed.initSet(&arena.allocator, 1);
        try res.shiftLeft(res, info.bits - 1);
        res.negate();

        const res_const = res.toConst();
        if (res_const.positive) {
            return Value.Tag.int_big_positive.create(&arena.allocator, res_const.limbs);
        } else {
            return Value.Tag.int_big_negative.create(&arena.allocator, res_const.limbs);
        }
    }

    /// Asserts that self.zigTypeTag() == .Int.
    pub fn maxInt(self: Type, arena: *std.heap.ArenaAllocator, target: Target) !Value {
        assert(self.zigTypeTag() == .Int);
        const info = self.intInfo(target);

        if (info.signedness == .signed and (info.bits - 1) <= std.math.maxInt(u6)) {
            const n: i64 = (@as(i64, 1) << @truncate(u6, info.bits - 1)) - 1;
            return Value.Tag.int_i64.create(&arena.allocator, n);
        } else if (info.signedness == .signed and info.bits <= std.math.maxInt(u6)) {
            const n: u64 = (@as(u64, 1) << @truncate(u6, info.bits)) - 1;
            return Value.Tag.int_u64.create(&arena.allocator, n);
        }

        var res = try std.math.big.int.Managed.initSet(&arena.allocator, 1);
        try res.shiftLeft(res, info.bits - @boolToInt(info.signedness == .signed));
        const one = std.math.big.int.Const{
            .limbs = &[_]std.math.big.Limb{1},
            .positive = true,
        };
        res.sub(res.toConst(), one) catch unreachable;

        const res_const = res.toConst();
        if (res_const.positive) {
            return Value.Tag.int_big_positive.create(&arena.allocator, res_const.limbs);
        } else {
            return Value.Tag.int_big_negative.create(&arena.allocator, res_const.limbs);
        }
    }

    pub fn isNonexhaustiveEnum(ty: Type) bool {
        return switch (ty.tag()) {
            .enum_nonexhaustive => true,
            else => false,
        };
    }

    pub fn enumFieldCount(ty: Type) usize {
        switch (ty.tag()) {
            .enum_full, .enum_nonexhaustive => {
                const enum_full = ty.cast(Payload.EnumFull).?.data;
                return enum_full.fields.count();
            },
            .enum_simple => {
                const enum_simple = ty.castTag(.enum_simple).?.data;
                return enum_simple.fields.count();
            },
            .atomic_ordering,
            .atomic_rmw_op,
            .calling_convention,
            .float_mode,
            .reduce_op,
            .call_options,
            .export_options,
            .extern_options,
            => @panic("TODO resolve std.builtin types"),

            else => unreachable,
        }
    }

    pub fn enumFieldName(ty: Type, field_index: usize) []const u8 {
        switch (ty.tag()) {
            .enum_full, .enum_nonexhaustive => {
                const enum_full = ty.cast(Payload.EnumFull).?.data;
                return enum_full.fields.keys()[field_index];
            },
            .enum_simple => {
                const enum_simple = ty.castTag(.enum_simple).?.data;
                return enum_simple.fields.keys()[field_index];
            },
            .atomic_ordering,
            .atomic_rmw_op,
            .calling_convention,
            .float_mode,
            .reduce_op,
            .call_options,
            .export_options,
            .extern_options,
            => @panic("TODO resolve std.builtin types"),
            else => unreachable,
        }
    }

    pub fn enumFieldIndex(ty: Type, field_name: []const u8) ?usize {
        switch (ty.tag()) {
            .enum_full, .enum_nonexhaustive => {
                const enum_full = ty.cast(Payload.EnumFull).?.data;
                return enum_full.fields.getIndex(field_name);
            },
            .enum_simple => {
                const enum_simple = ty.castTag(.enum_simple).?.data;
                return enum_simple.fields.getIndex(field_name);
            },
            .atomic_ordering,
            .atomic_rmw_op,
            .calling_convention,
            .float_mode,
            .reduce_op,
            .call_options,
            .export_options,
            .extern_options,
            => @panic("TODO resolve std.builtin types"),
            else => unreachable,
        }
    }

    /// Asserts `ty` is an enum. `enum_tag` can either be `enum_field_index` or
    /// an integer which represents the enum value. Returns the field index in
    /// declaration order, or `null` if `enum_tag` does not match any field.
    pub fn enumTagFieldIndex(ty: Type, enum_tag: Value) ?usize {
        if (enum_tag.castTag(.enum_field_index)) |payload| {
            return @as(usize, payload.data);
        }
        const S = struct {
            fn fieldWithRange(int_val: Value, end: usize) ?usize {
                if (int_val.compareWithZero(.lt)) return null;
                var end_payload: Value.Payload.U64 = .{
                    .base = .{ .tag = .int_u64 },
                    .data = end,
                };
                const end_val = Value.initPayload(&end_payload.base);
                if (int_val.compare(.gte, end_val)) return null;
                return @intCast(usize, int_val.toUnsignedInt());
            }
        };
        switch (ty.tag()) {
            .enum_full, .enum_nonexhaustive => {
                const enum_full = ty.cast(Payload.EnumFull).?.data;
                if (enum_full.values.count() == 0) {
                    return S.fieldWithRange(enum_tag, enum_full.fields.count());
                } else {
                    return enum_full.values.getIndex(enum_tag);
                }
            },
            .enum_simple => {
                const enum_simple = ty.castTag(.enum_simple).?.data;
                return S.fieldWithRange(enum_tag, enum_simple.fields.count());
            },
            .atomic_ordering,
            .atomic_rmw_op,
            .calling_convention,
            .float_mode,
            .reduce_op,
            .call_options,
            .export_options,
            .extern_options,
            => @panic("TODO resolve std.builtin types"),
            else => unreachable,
        }
    }

    pub fn declSrcLoc(ty: Type) Module.SrcLoc {
        switch (ty.tag()) {
            .enum_full, .enum_nonexhaustive => {
                const enum_full = ty.cast(Payload.EnumFull).?.data;
                return enum_full.srcLoc();
            },
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
            .atomic_ordering,
            .atomic_rmw_op,
            .calling_convention,
            .float_mode,
            .reduce_op,
            .call_options,
            .export_options,
            .extern_options,
            => @panic("TODO resolve std.builtin types"),
            else => unreachable,
        }
    }

    pub fn getOwnerDecl(ty: Type) *Module.Decl {
        switch (ty.tag()) {
            .enum_full, .enum_nonexhaustive => {
                const enum_full = ty.cast(Payload.EnumFull).?.data;
                return enum_full.owner_decl;
            },
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
            .atomic_ordering,
            .atomic_rmw_op,
            .calling_convention,
            .float_mode,
            .reduce_op,
            .call_options,
            .export_options,
            .extern_options,
            => @panic("TODO resolve std.builtin types"),
            else => unreachable,
        }
    }

    /// Asserts the type is an enum.
    pub fn enumHasInt(ty: Type, int: Value, target: Target) bool {
        const S = struct {
            fn intInRange(int_val: Value, end: usize) bool {
                if (int_val.compareWithZero(.lt)) return false;
                var end_payload: Value.Payload.U64 = .{
                    .base = .{ .tag = .int_u64 },
                    .data = end,
                };
                const end_val = Value.initPayload(&end_payload.base);
                if (int_val.compare(.gte, end_val)) return false;
                return true;
            }
        };
        switch (ty.tag()) {
            .enum_nonexhaustive => return int.intFitsInType(ty, target),
            .enum_full => {
                const enum_full = ty.castTag(.enum_full).?.data;
                if (enum_full.values.count() == 0) {
                    return S.intInRange(int, enum_full.fields.count());
                } else {
                    return enum_full.values.contains(int);
                }
            },
            .enum_simple => {
                const enum_simple = ty.castTag(.enum_simple).?.data;
                return S.intInRange(int, enum_simple.fields.count());
            },
            .atomic_ordering,
            .atomic_rmw_op,
            .calling_convention,
            .float_mode,
            .reduce_op,
            .call_options,
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
    pub const Tag = enum {
        // The first section of this enum are tags that require no payload.
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
        c_void,
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
        atomic_ordering,
        atomic_rmw_op,
        calling_convention,
        float_mode,
        reduce_op,
        call_options,
        export_options,
        extern_options,
        manyptr_u8,
        manyptr_const_u8,
        fn_noreturn_no_args,
        fn_void_no_args,
        fn_naked_noreturn_no_args,
        fn_ccc_void_no_args,
        single_const_pointer_to_comptime_int,
        const_slice_u8,
        anyerror_void_error_union,
        /// This is a special type for variadic parameters of a function call.
        /// Casts to it will validate that the type can be passed to a c calling convetion function.
        var_args_param,
        /// Same as `empty_struct` except it has an empty namespace.
        empty_struct_literal,
        /// This is a special value that tracks a set of types that have been stored
        /// to an inferred allocation. It does not support most of the normal type queries.
        /// However it does respond to `isConstPtr`, `ptrSize`, `zigTypeTag`, etc.
        inferred_alloc_mut,
        /// Same as `inferred_alloc_mut` but the local is `var` not `const`.
        inferred_alloc_const, // See last_no_payload_tag below.
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
        empty_struct,
        @"opaque",
        @"struct",
        @"union",
        union_tagged,
        enum_simple,
        enum_full,
        enum_nonexhaustive,

        pub const last_no_payload_tag = Tag.inferred_alloc_const;
        pub const no_payload_count = @enumToInt(last_no_payload_tag) + 1;

        pub fn Type(comptime t: Tag) type {
            return switch (t) {
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
                .c_void,
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
                .inferred_alloc_const,
                .inferred_alloc_mut,
                .var_args_param,
                .empty_struct_literal,
                .manyptr_u8,
                .manyptr_const_u8,
                .atomic_ordering,
                .atomic_rmw_op,
                .calling_convention,
                .float_mode,
                .reduce_op,
                .call_options,
                .export_options,
                .extern_options,
                .@"anyframe",
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
                .empty_struct => Payload.ContainerScope,
            };
        }

        pub fn init(comptime t: Tag) Type {
            comptime std.debug.assert(@enumToInt(t) < Tag.no_payload_count);
            return .{ .tag_if_small_enough = @enumToInt(t) };
        }

        pub fn create(comptime t: Tag, ally: *Allocator, data: Data(t)) error{OutOfMemory}!Type {
            const ptr = try ally.create(t.Type());
            ptr.* = .{
                .base = .{ .tag = t },
                .data = data,
            };
            return Type{ .ptr_otherwise = &ptr.base };
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
            data: struct {
                param_types: []Type,
                return_type: Type,
                cc: std.builtin.CallingConvention,
                is_var_args: bool,
            },
        };

        pub const ErrorSet = struct {
            pub const base_tag = Tag.error_set;

            base: Payload = Payload{ .tag = base_tag },
            data: *Module.ErrorSet,
        };

        pub const Pointer = struct {
            pub const base_tag = Tag.pointer;

            base: Payload = Payload{ .tag = base_tag },
            data: struct {
                pointee_type: Type,
                sentinel: ?Value,
                /// If zero use pointee_type.AbiAlign()
                @"align": u32,
                bit_offset: u16,
                host_size: u16,
                @"allowzero": bool,
                mutable: bool,
                @"volatile": bool,
                size: std.builtin.TypeInfo.Pointer.Size,
            },
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
            data: *Module.Scope.Namespace,
        };

        pub const Opaque = struct {
            base: Payload = .{ .tag = .@"opaque" },
            data: Module.Scope.Namespace,
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
    };
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
        const arch = target.cpu.arch;
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
            .solaris,
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
