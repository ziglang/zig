const std = @import("std");
const Value = @import("value.zig").Value;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Target = std.Target;
const Module = @import("Module.zig");

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

            .c_void => return .Opaque,
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

            .array, .array_u8_sentinel_0, .array_u8, .array_sentinel => return .Array,
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
            => return .Pointer,

            .optional,
            .optional_single_const_pointer,
            .optional_single_mut_pointer,
            => return .Optional,
            .enum_literal => return .EnumLiteral,

            .anyerror_void_error_union, .error_union => return .ErrorUnion,

            .anyframe_T, .@"anyframe" => return .AnyFrame,

            .empty_struct => return .Struct,
        }
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
            return @intToEnum(Tag, @intCast(@TagType(Tag), self.tag_if_small_enough));
        } else {
            return self.ptr_otherwise.tag;
        }
    }

    pub fn cast(self: Type, comptime T: type) ?*T {
        if (self.tag_if_small_enough < Tag.no_payload_count)
            return null;

        const expected_tag = std.meta.fieldInfo(T, "base").default_value.?.tag;
        if (self.ptr_otherwise.tag != expected_tag)
            return null;

        return @fieldParentPtr(T, "base", self.ptr_otherwise);
    }

    pub fn castPointer(self: Type) ?*Payload.PointerSimple {
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
            => @fieldParentPtr(Payload.PointerSimple, "base", self.ptr_otherwise),
            else => null,
        };
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
                // Hot path for common case:
                if (a.castPointer()) |a_payload| {
                    if (b.castPointer()) |b_payload| {
                        return a.tag() == b.tag() and eql(a_payload.pointee_type, b_payload.pointee_type);
                    }
                }
                const is_slice_a = isSlice(a);
                const is_slice_b = isSlice(b);
                if (is_slice_a != is_slice_b)
                    return false;

                const ptr_size_a = ptrSize(a);
                const ptr_size_b = ptrSize(b);
                if (ptr_size_a != ptr_size_b)
                    return false;

                std.debug.panic("TODO implement more pointer Type equality comparison: {} and {}", .{
                    a, b,
                });
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
            .Array => {
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
                return true;
            },
            .Optional => {
                var buf_a: Payload.PointerSimple = undefined;
                var buf_b: Payload.PointerSimple = undefined;
                return a.optionalChild(&buf_a).eql(b.optionalChild(&buf_b));
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
            .Vector,
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
            .Array => {
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
            },
            .Optional => {
                var buf: Payload.PointerSimple = undefined;
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
            .Vector,
            .EnumLiteral,
            => {
                // TODO implement more type hashing
            },
        }
        return hasher.final();
    }

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
            .@"anyframe",
            => unreachable,

            .array_u8_sentinel_0 => return self.copyPayloadShallow(allocator, Payload.Array_u8_Sentinel0),
            .array_u8 => return self.copyPayloadShallow(allocator, Payload.Array_u8),
            .array => {
                const payload = @fieldParentPtr(Payload.Array, "base", self.ptr_otherwise);
                const new_payload = try allocator.create(Payload.Array);
                new_payload.* = .{
                    .base = payload.base,
                    .len = payload.len,
                    .elem_type = try payload.elem_type.copy(allocator),
                };
                return Type{ .ptr_otherwise = &new_payload.base };
            },
            .array_sentinel => {
                const payload = @fieldParentPtr(Payload.ArraySentinel, "base", self.ptr_otherwise);
                const new_payload = try allocator.create(Payload.ArraySentinel);
                new_payload.* = .{
                    .base = payload.base,
                    .len = payload.len,
                    .sentinel = try payload.sentinel.copy(allocator),
                    .elem_type = try payload.elem_type.copy(allocator),
                };
                return Type{ .ptr_otherwise = &new_payload.base };
            },
            .int_signed => return self.copyPayloadShallow(allocator, Payload.IntSigned),
            .int_unsigned => return self.copyPayloadShallow(allocator, Payload.IntUnsigned),
            .function => {
                const payload = @fieldParentPtr(Payload.Function, "base", self.ptr_otherwise);
                const new_payload = try allocator.create(Payload.Function);
                const param_types = try allocator.alloc(Type, payload.param_types.len);
                for (payload.param_types) |param_type, i| {
                    param_types[i] = try param_type.copy(allocator);
                }
                new_payload.* = .{
                    .base = payload.base,
                    .return_type = try payload.return_type.copy(allocator),
                    .param_types = param_types,
                    .cc = payload.cc,
                };
                return Type{ .ptr_otherwise = &new_payload.base };
            },
            .optional => return self.copyPayloadSingleField(allocator, Payload.Optional, "child_type"),
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            => return self.copyPayloadSingleField(allocator, Payload.PointerSimple, "pointee_type"),
            .anyframe_T => return self.copyPayloadSingleField(allocator, Payload.AnyFrame, "return_type"),

            .pointer => {
                const payload = @fieldParentPtr(Payload.Pointer, "base", self.ptr_otherwise);
                const new_payload = try allocator.create(Payload.Pointer);
                new_payload.* = .{
                    .base = payload.base,

                    .pointee_type = try payload.pointee_type.copy(allocator),
                    .sentinel = if (payload.sentinel) |some| try some.copy(allocator) else null,
                    .@"align" = payload.@"align",
                    .bit_offset = payload.bit_offset,
                    .host_size = payload.host_size,
                    .@"allowzero" = payload.@"allowzero",
                    .mutable = payload.mutable,
                    .@"volatile" = payload.@"volatile",
                    .size = payload.size,
                };
                return Type{ .ptr_otherwise = &new_payload.base };
            },
            .error_union => {
                const payload = @fieldParentPtr(Payload.ErrorUnion, "base", self.ptr_otherwise);
                const new_payload = try allocator.create(Payload.ErrorUnion);
                new_payload.* = .{
                    .base = payload.base,

                    .error_set = try payload.error_set.copy(allocator),
                    .payload = try payload.payload.copy(allocator),
                };
                return Type{ .ptr_otherwise = &new_payload.base };
            },
            .error_set => return self.copyPayloadShallow(allocator, Payload.ErrorSet),
            .error_set_single => return self.copyPayloadShallow(allocator, Payload.ErrorSetSingle),
            .empty_struct => return self.copyPayloadShallow(allocator, Payload.EmptyStruct),
        }
    }

    fn copyPayloadShallow(self: Type, allocator: *Allocator, comptime T: type) error{OutOfMemory}!Type {
        const payload = @fieldParentPtr(T, "base", self.ptr_otherwise);
        const new_payload = try allocator.create(T);
        new_payload.* = payload.*;
        return Type{ .ptr_otherwise = &new_payload.base };
    }

    fn copyPayloadSingleField(self: Type, allocator: *Allocator, comptime T: type, comptime field_name: []const u8) error{OutOfMemory}!Type {
        const payload = @fieldParentPtr(T, "base", self.ptr_otherwise);
        const new_payload = try allocator.create(T);
        new_payload.base = payload.base;
        @field(new_payload, field_name) = try @field(payload, field_name).copy(allocator);
        return Type{ .ptr_otherwise = &new_payload.base };
    }

    pub fn format(
        self: Type,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) @TypeOf(out_stream).Error!void {
        comptime assert(fmt.len == 0);
        var ty = self;
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
                => return out_stream.writeAll(@tagName(t)),

                .enum_literal => return out_stream.writeAll("@Type(.EnumLiteral)"),
                .@"null" => return out_stream.writeAll("@Type(.Null)"),
                .@"undefined" => return out_stream.writeAll("@Type(.Undefined)"),

                // TODO this should print the structs name
                .empty_struct => return out_stream.writeAll("struct {}"),
                .@"anyframe" => return out_stream.writeAll("anyframe"),
                .anyerror_void_error_union => return out_stream.writeAll("anyerror!void"),
                .const_slice_u8 => return out_stream.writeAll("[]const u8"),
                .fn_noreturn_no_args => return out_stream.writeAll("fn() noreturn"),
                .fn_void_no_args => return out_stream.writeAll("fn() void"),
                .fn_naked_noreturn_no_args => return out_stream.writeAll("fn() callconv(.Naked) noreturn"),
                .fn_ccc_void_no_args => return out_stream.writeAll("fn() callconv(.C) void"),
                .single_const_pointer_to_comptime_int => return out_stream.writeAll("*const comptime_int"),
                .function => {
                    const payload = @fieldParentPtr(Payload.Function, "base", ty.ptr_otherwise);
                    try out_stream.writeAll("fn(");
                    for (payload.param_types) |param_type, i| {
                        if (i != 0) try out_stream.writeAll(", ");
                        try param_type.format("", .{}, out_stream);
                    }
                    try out_stream.writeAll(") ");
                    ty = payload.return_type;
                    continue;
                },

                .anyframe_T => {
                    const payload = @fieldParentPtr(Payload.AnyFrame, "base", ty.ptr_otherwise);
                    try out_stream.print("anyframe->", .{});
                    ty = payload.return_type;
                    continue;
                },
                .array_u8 => {
                    const payload = @fieldParentPtr(Payload.Array_u8, "base", ty.ptr_otherwise);
                    return out_stream.print("[{}]u8", .{payload.len});
                },
                .array_u8_sentinel_0 => {
                    const payload = @fieldParentPtr(Payload.Array_u8_Sentinel0, "base", ty.ptr_otherwise);
                    return out_stream.print("[{}:0]u8", .{payload.len});
                },
                .array => {
                    const payload = @fieldParentPtr(Payload.Array, "base", ty.ptr_otherwise);
                    try out_stream.print("[{}]", .{payload.len});
                    ty = payload.elem_type;
                    continue;
                },
                .array_sentinel => {
                    const payload = @fieldParentPtr(Payload.ArraySentinel, "base", ty.ptr_otherwise);
                    try out_stream.print("[{}:{}]", .{ payload.len, payload.sentinel });
                    ty = payload.elem_type;
                    continue;
                },
                .single_const_pointer => {
                    const payload = @fieldParentPtr(Payload.PointerSimple, "base", ty.ptr_otherwise);
                    try out_stream.writeAll("*const ");
                    ty = payload.pointee_type;
                    continue;
                },
                .single_mut_pointer => {
                    const payload = @fieldParentPtr(Payload.PointerSimple, "base", ty.ptr_otherwise);
                    try out_stream.writeAll("*");
                    ty = payload.pointee_type;
                    continue;
                },
                .many_const_pointer => {
                    const payload = @fieldParentPtr(Payload.PointerSimple, "base", ty.ptr_otherwise);
                    try out_stream.writeAll("[*]const ");
                    ty = payload.pointee_type;
                    continue;
                },
                .many_mut_pointer => {
                    const payload = @fieldParentPtr(Payload.PointerSimple, "base", ty.ptr_otherwise);
                    try out_stream.writeAll("[*]");
                    ty = payload.pointee_type;
                    continue;
                },
                .c_const_pointer => {
                    const payload = @fieldParentPtr(Payload.PointerSimple, "base", ty.ptr_otherwise);
                    try out_stream.writeAll("[*c]const ");
                    ty = payload.pointee_type;
                    continue;
                },
                .c_mut_pointer => {
                    const payload = @fieldParentPtr(Payload.PointerSimple, "base", ty.ptr_otherwise);
                    try out_stream.writeAll("[*c]");
                    ty = payload.pointee_type;
                    continue;
                },
                .const_slice => {
                    const payload = @fieldParentPtr(Payload.PointerSimple, "base", ty.ptr_otherwise);
                    try out_stream.writeAll("[]const ");
                    ty = payload.pointee_type;
                    continue;
                },
                .mut_slice => {
                    const payload = @fieldParentPtr(Payload.PointerSimple, "base", ty.ptr_otherwise);
                    try out_stream.writeAll("[]");
                    ty = payload.pointee_type;
                    continue;
                },
                .int_signed => {
                    const payload = @fieldParentPtr(Payload.IntSigned, "base", ty.ptr_otherwise);
                    return out_stream.print("i{}", .{payload.bits});
                },
                .int_unsigned => {
                    const payload = @fieldParentPtr(Payload.IntUnsigned, "base", ty.ptr_otherwise);
                    return out_stream.print("u{}", .{payload.bits});
                },
                .optional => {
                    const payload = @fieldParentPtr(Payload.Optional, "base", ty.ptr_otherwise);
                    try out_stream.writeByte('?');
                    ty = payload.child_type;
                    continue;
                },
                .optional_single_const_pointer => {
                    const payload = @fieldParentPtr(Payload.PointerSimple, "base", ty.ptr_otherwise);
                    try out_stream.writeAll("?*const ");
                    ty = payload.pointee_type;
                    continue;
                },
                .optional_single_mut_pointer => {
                    const payload = @fieldParentPtr(Payload.PointerSimple, "base", ty.ptr_otherwise);
                    try out_stream.writeAll("?*");
                    ty = payload.pointee_type;
                    continue;
                },

                .pointer => {
                    const payload = @fieldParentPtr(Payload.Pointer, "base", ty.ptr_otherwise);
                    if (payload.sentinel) |some| switch (payload.size) {
                        .One, .C => unreachable,
                        .Many => try out_stream.print("[*:{}]", .{some}),
                        .Slice => try out_stream.print("[:{}]", .{some}),
                    } else switch (payload.size) {
                        .One => try out_stream.writeAll("*"),
                        .Many => try out_stream.writeAll("[*]"),
                        .C => try out_stream.writeAll("[*c]"),
                        .Slice => try out_stream.writeAll("[]"),
                    }
                    if (payload.@"align" != 0) {
                        try out_stream.print("align({}", .{payload.@"align"});

                        if (payload.bit_offset != 0) {
                            try out_stream.print(":{}:{}", .{ payload.bit_offset, payload.host_size });
                        }
                        try out_stream.writeAll(") ");
                    }
                    if (!payload.mutable) try out_stream.writeAll("const ");
                    if (payload.@"volatile") try out_stream.writeAll("volatile ");
                    if (payload.@"allowzero") try out_stream.writeAll("allowzero ");

                    ty = payload.pointee_type;
                    continue;
                },
                .error_union => {
                    const payload = @fieldParentPtr(Payload.ErrorUnion, "base", ty.ptr_otherwise);
                    try payload.error_set.format("", .{}, out_stream);
                    try out_stream.writeAll("!");
                    ty = payload.payload;
                    continue;
                },
                .error_set => {
                    const payload = @fieldParentPtr(Payload.ErrorSet, "base", ty.ptr_otherwise);
                    return out_stream.writeAll(std.mem.spanZ(payload.decl.name));
                },
                .error_set_single => {
                    const payload = @fieldParentPtr(Payload.ErrorSetSingle, "base", ty.ptr_otherwise);
                    return out_stream.print("error{{{}}}", .{payload.name});
                },
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
            else => {
                const ty_payload = try allocator.create(Value.Payload.Ty);
                ty_payload.* = .{ .ty = self };
                return Value.initPayload(&ty_payload.base);
            },
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
            .@"anyframe",
            .anyframe_T,
            .anyerror_void_error_union,
            .error_set,
            .error_set_single,
            => true,
            // TODO lazy types
            .array => self.elemType().hasCodeGenBits() and self.arrayLen() != 0,
            .array_u8 => self.arrayLen() != 0,
            .array_sentinel, .single_const_pointer, .single_mut_pointer, .many_const_pointer, .many_mut_pointer, .c_const_pointer, .c_mut_pointer, .const_slice, .mut_slice, .pointer => self.elemType().hasCodeGenBits(),
            .int_signed => self.cast(Payload.IntSigned).?.bits != 0,
            .int_unsigned => self.cast(Payload.IntUnsigned).?.bits != 0,

            .error_union => {
                const payload = self.cast(Payload.ErrorUnion).?;
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
            => false,
        };
    }

    pub fn isNoReturn(self: Type) bool {
        return self.zigTypeTag() == .NoReturn;
    }

    /// Asserts that hasCodeGenBits() is true.
    pub fn abiAlignment(self: Type, target: Target) u32 {
        return switch (self.tag()) {
            .u8,
            .i8,
            .bool,
            .array_u8_sentinel_0,
            .array_u8,
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
            .@"anyframe",
            .anyframe_T,
            => return @divExact(target.cpu.arch.ptrBitWidth(), 8),

            .pointer => {
                const payload = @fieldParentPtr(Payload.Pointer, "base", self.ptr_otherwise);

                if (payload.@"align" != 0) return payload.@"align";
                return @divExact(target.cpu.arch.ptrBitWidth(), 8);
            },

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

            .int_signed, .int_unsigned => {
                const bits: u16 = if (self.cast(Payload.IntSigned)) |pl|
                    pl.bits
                else if (self.cast(Payload.IntUnsigned)) |pl|
                    pl.bits
                else
                    unreachable;

                return std.math.ceilPowerOfTwoPromote(u16, (bits + 7) / 8);
            },

            .optional => {
                var buf: Payload.PointerSimple = undefined;
                const child_type = self.optionalChild(&buf);
                if (!child_type.hasCodeGenBits()) return 1;

                if (child_type.zigTypeTag() == .Pointer and !child_type.isCPtr())
                    return @divExact(target.cpu.arch.ptrBitWidth(), 8);

                return child_type.abiAlignment(target);
            },

            .error_union => {
                const payload = self.cast(Payload.ErrorUnion).?;
                if (!payload.error_set.hasCodeGenBits()) {
                    return payload.payload.abiAlignment(target);
                } else if (!payload.payload.hasCodeGenBits()) {
                    return payload.error_set.abiAlignment(target);
                }
                @panic("TODO abiAlignment error union");
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

            .u8,
            .i8,
            .bool,
            => return 1,

            .array_u8 => @fieldParentPtr(Payload.Array_u8_Sentinel0, "base", self.ptr_otherwise).len,
            .array_u8_sentinel_0 => @fieldParentPtr(Payload.Array_u8_Sentinel0, "base", self.ptr_otherwise).len + 1,
            .array => {
                const payload = @fieldParentPtr(Payload.Array, "base", self.ptr_otherwise);
                const elem_size = std.math.max(payload.elem_type.abiAlignment(target), payload.elem_type.abiSize(target));
                return payload.len * elem_size;
            },
            .array_sentinel => {
                const payload = @fieldParentPtr(Payload.ArraySentinel, "base", self.ptr_otherwise);
                const elem_size = std.math.max(payload.elem_type.abiAlignment(target), payload.elem_type.abiSize(target));
                return (payload.len + 1) * elem_size;
            },
            .i16, .u16 => return 2,
            .i32, .u32 => return 4,
            .i64, .u64 => return 8,

            .@"anyframe", .anyframe_T, .isize, .usize => return @divExact(target.cpu.arch.ptrBitWidth(), 8),

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
                const bits: u16 = if (self.cast(Payload.IntSigned)) |pl|
                    pl.bits
                else if (self.cast(Payload.IntUnsigned)) |pl|
                    pl.bits
                else
                    unreachable;

                return std.math.ceilPowerOfTwoPromote(u16, (bits + 7) / 8);
            },

            .optional => {
                var buf: Payload.PointerSimple = undefined;
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
                const payload = self.cast(Payload.ErrorUnion).?;
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

    pub fn isSinglePointer(self: Type) bool {
        return switch (self.tag()) {
            .u8,
            .i8,
            .u16,
            .i16,
            .u32,
            .i32,
            .u64,
            .i64,
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
            .@"null",
            .@"undefined",
            .array,
            .array_sentinel,
            .array_u8,
            .array_u8_sentinel_0,
            .const_slice_u8,
            .fn_noreturn_no_args,
            .fn_void_no_args,
            .fn_naked_noreturn_no_args,
            .fn_ccc_void_no_args,
            .function,
            .int_unsigned,
            .int_signed,
            .optional,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            .enum_literal,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            .error_union,
            .@"anyframe",
            .anyframe_T,
            .anyerror_void_error_union,
            .error_set,
            .error_set_single,
            .empty_struct,
            => false,

            .single_const_pointer,
            .single_mut_pointer,
            .single_const_pointer_to_comptime_int,
            => true,

            .pointer => self.cast(Payload.Pointer).?.size == .One,
        };
    }

    /// Asserts the `Type` is a pointer.
    pub fn ptrSize(self: Type) std.builtin.TypeInfo.Pointer.Size {
        return switch (self.tag()) {
            .u8,
            .i8,
            .u16,
            .i16,
            .u32,
            .i32,
            .u64,
            .i64,
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
            .@"null",
            .@"undefined",
            .array,
            .array_sentinel,
            .array_u8,
            .array_u8_sentinel_0,
            .fn_noreturn_no_args,
            .fn_void_no_args,
            .fn_naked_noreturn_no_args,
            .fn_ccc_void_no_args,
            .function,
            .int_unsigned,
            .int_signed,
            .optional,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            .enum_literal,
            .error_union,
            .@"anyframe",
            .anyframe_T,
            .anyerror_void_error_union,
            .error_set,
            .error_set_single,
            .empty_struct,
            => unreachable,

            .const_slice,
            .mut_slice,
            .const_slice_u8,
            => .Slice,

            .many_const_pointer,
            .many_mut_pointer,
            => .Many,

            .c_const_pointer,
            .c_mut_pointer,
            => .C,

            .single_const_pointer,
            .single_mut_pointer,
            .single_const_pointer_to_comptime_int,
            => .One,

            .pointer => self.cast(Payload.Pointer).?.size,
        };
    }

    pub fn isSlice(self: Type) bool {
        return switch (self.tag()) {
            .u8,
            .i8,
            .u16,
            .i16,
            .u32,
            .i32,
            .u64,
            .i64,
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
            .@"null",
            .@"undefined",
            .array,
            .array_sentinel,
            .array_u8,
            .array_u8_sentinel_0,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .single_const_pointer_to_comptime_int,
            .fn_noreturn_no_args,
            .fn_void_no_args,
            .fn_naked_noreturn_no_args,
            .fn_ccc_void_no_args,
            .function,
            .int_unsigned,
            .int_signed,
            .optional,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            .enum_literal,
            .error_union,
            .@"anyframe",
            .anyframe_T,
            .anyerror_void_error_union,
            .error_set,
            .error_set_single,
            .empty_struct,
            => false,

            .const_slice,
            .mut_slice,
            .const_slice_u8,
            => true,

            .pointer => self.cast(Payload.Pointer).?.size == .Slice,
        };
    }

    pub fn isConstPtr(self: Type) bool {
        return switch (self.tag()) {
            .u8,
            .i8,
            .u16,
            .i16,
            .u32,
            .i32,
            .u64,
            .i64,
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
            .@"null",
            .@"undefined",
            .array,
            .array_sentinel,
            .array_u8,
            .array_u8_sentinel_0,
            .fn_noreturn_no_args,
            .fn_void_no_args,
            .fn_naked_noreturn_no_args,
            .fn_ccc_void_no_args,
            .function,
            .int_unsigned,
            .int_signed,
            .single_mut_pointer,
            .many_mut_pointer,
            .c_mut_pointer,
            .optional,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            .enum_literal,
            .mut_slice,
            .error_union,
            .@"anyframe",
            .anyframe_T,
            .anyerror_void_error_union,
            .error_set,
            .error_set_single,
            .empty_struct,
            => false,

            .single_const_pointer,
            .many_const_pointer,
            .c_const_pointer,
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            .const_slice,
            => true,

            .pointer => !self.cast(Payload.Pointer).?.mutable,
        };
    }

    pub fn isVolatilePtr(self: Type) bool {
        return switch (self.tag()) {
            .u8,
            .i8,
            .u16,
            .i16,
            .u32,
            .i32,
            .u64,
            .i64,
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
            .@"null",
            .@"undefined",
            .array,
            .array_sentinel,
            .array_u8,
            .array_u8_sentinel_0,
            .fn_noreturn_no_args,
            .fn_void_no_args,
            .fn_naked_noreturn_no_args,
            .fn_ccc_void_no_args,
            .function,
            .int_unsigned,
            .int_signed,
            .single_mut_pointer,
            .single_const_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            .optional,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            .enum_literal,
            .error_union,
            .@"anyframe",
            .anyframe_T,
            .anyerror_void_error_union,
            .error_set,
            .error_set_single,
            .empty_struct,
            => false,

            .pointer => {
                const payload = @fieldParentPtr(Payload.Pointer, "base", self.ptr_otherwise);
                return payload.@"volatile";
            },
        };
    }

    pub fn isAllowzeroPtr(self: Type) bool {
        return switch (self.tag()) {
            .u8,
            .i8,
            .u16,
            .i16,
            .u32,
            .i32,
            .u64,
            .i64,
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
            .@"null",
            .@"undefined",
            .array,
            .array_sentinel,
            .array_u8,
            .array_u8_sentinel_0,
            .fn_noreturn_no_args,
            .fn_void_no_args,
            .fn_naked_noreturn_no_args,
            .fn_ccc_void_no_args,
            .function,
            .int_unsigned,
            .int_signed,
            .single_mut_pointer,
            .single_const_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            .optional,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            .enum_literal,
            .error_union,
            .@"anyframe",
            .anyframe_T,
            .anyerror_void_error_union,
            .error_set,
            .error_set_single,
            .empty_struct,
            => false,

            .pointer => {
                const payload = @fieldParentPtr(Payload.Pointer, "base", self.ptr_otherwise);
                return payload.@"allowzero";
            },
        };
    }

    /// Asserts that the type is an optional
    pub fn isPtrLikeOptional(self: Type) bool {
        switch (self.tag()) {
            .optional_single_const_pointer, .optional_single_mut_pointer => return true,
            .optional => {
                var buf: Payload.PointerSimple = undefined;
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
            .Vector,
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
                var buf: Payload.PointerSimple = undefined;
                return ty.optionalChild(&buf).isValidVarType(is_extern);
            },
            .Pointer, .Array => ty = ty.elemType(),

            .ErrorUnion => @panic("TODO fn isValidVarType"),
            .Fn => @panic("TODO fn isValidVarType"),
            .Struct => @panic("TODO struct isValidVarType"),
            .Union => @panic("TODO union isValidVarType"),
        };
    }

    /// Asserts the type is a pointer or array type.
    pub fn elemType(self: Type) Type {
        return switch (self.tag()) {
            .u8,
            .i8,
            .u16,
            .i16,
            .u32,
            .i32,
            .u64,
            .i64,
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
            .@"null",
            .@"undefined",
            .fn_noreturn_no_args,
            .fn_void_no_args,
            .fn_naked_noreturn_no_args,
            .fn_ccc_void_no_args,
            .function,
            .int_unsigned,
            .int_signed,
            .optional,
            .optional_single_const_pointer,
            .optional_single_mut_pointer,
            .enum_literal,
            .error_union,
            .@"anyframe",
            .anyframe_T,
            .anyerror_void_error_union,
            .error_set,
            .error_set_single,
            .empty_struct,
            => unreachable,

            .array => self.cast(Payload.Array).?.elem_type,
            .array_sentinel => self.cast(Payload.ArraySentinel).?.elem_type,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            => self.castPointer().?.pointee_type,
            .array_u8, .array_u8_sentinel_0, .const_slice_u8 => Type.initTag(.u8),
            .single_const_pointer_to_comptime_int => Type.initTag(.comptime_int),
            .pointer => self.cast(Payload.Pointer).?.pointee_type,
        };
    }

    /// Asserts that the type is an optional.
    pub fn optionalChild(self: Type, buf: *Payload.PointerSimple) Type {
        return switch (self.tag()) {
            .optional => self.cast(Payload.Optional).?.child_type,
            .optional_single_mut_pointer => {
                buf.* = .{
                    .base = .{ .tag = .single_mut_pointer },
                    .pointee_type = self.castPointer().?.pointee_type,
                };
                return Type.initPayload(&buf.base);
            },
            .optional_single_const_pointer => {
                buf.* = .{
                    .base = .{ .tag = .single_const_pointer },
                    .pointee_type = self.castPointer().?.pointee_type,
                };
                return Type.initPayload(&buf.base);
            },
            else => unreachable,
        };
    }

    /// Asserts that the type is an optional.
    /// Same as `optionalChild` but allocates the buffer if needed.
    pub fn optionalChildAlloc(self: Type, allocator: *Allocator) !Type {
        return switch (self.tag()) {
            .optional => self.cast(Payload.Optional).?.child_type,
            .optional_single_mut_pointer, .optional_single_const_pointer => {
                const payload = try allocator.create(Payload.PointerSimple);
                payload.* = .{
                    .base = .{
                        .tag = if (self.tag() == .optional_single_const_pointer)
                            .single_const_pointer
                        else
                            .single_mut_pointer,
                    },
                    .pointee_type = self.castPointer().?.pointee_type,
                };
                return Type.initPayload(&payload.base);
            },
            else => unreachable,
        };
    }

    /// Asserts the type is an array or vector.
    pub fn arrayLen(self: Type) u64 {
        return switch (self.tag()) {
            .u8,
            .i8,
            .u16,
            .i16,
            .u32,
            .i32,
            .u64,
            .i64,
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
            .@"null",
            .@"undefined",
            .fn_noreturn_no_args,
            .fn_void_no_args,
            .fn_naked_noreturn_no_args,
            .fn_ccc_void_no_args,
            .function,
            .pointer,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            .int_unsigned,
            .int_signed,
            .optional,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            .enum_literal,
            .error_union,
            .@"anyframe",
            .anyframe_T,
            .anyerror_void_error_union,
            .error_set,
            .error_set_single,
            .empty_struct,
            => unreachable,

            .array => self.cast(Payload.Array).?.len,
            .array_sentinel => self.cast(Payload.ArraySentinel).?.len,
            .array_u8 => self.cast(Payload.Array_u8).?.len,
            .array_u8_sentinel_0 => self.cast(Payload.Array_u8_Sentinel0).?.len,
        };
    }

    /// Asserts the type is an array, pointer or vector.
    pub fn sentinel(self: Type) ?Value {
        return switch (self.tag()) {
            .u8,
            .i8,
            .u16,
            .i16,
            .u32,
            .i32,
            .u64,
            .i64,
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
            .@"null",
            .@"undefined",
            .fn_noreturn_no_args,
            .fn_void_no_args,
            .fn_naked_noreturn_no_args,
            .fn_ccc_void_no_args,
            .function,
            .const_slice,
            .mut_slice,
            .const_slice_u8,
            .int_unsigned,
            .int_signed,
            .optional,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            .enum_literal,
            .error_union,
            .@"anyframe",
            .anyframe_T,
            .anyerror_void_error_union,
            .error_set,
            .error_set_single,
            .empty_struct,
            => unreachable,

            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .single_const_pointer_to_comptime_int,
            .array,
            .array_u8,
            => return null,

            .pointer => return self.cast(Payload.Pointer).?.sentinel,
            .array_sentinel => return self.cast(Payload.ArraySentinel).?.sentinel,
            .array_u8_sentinel_0 => return Value.initTag(.zero),
        };
    }

    /// Returns true if and only if the type is a fixed-width integer.
    pub fn isInt(self: Type) bool {
        return self.isSignedInt() or self.isUnsignedInt();
    }

    /// Returns true if and only if the type is a fixed-width, signed integer.
    pub fn isSignedInt(self: Type) bool {
        return switch (self.tag()) {
            .f16,
            .f32,
            .f64,
            .f128,
            .c_longdouble,
            .c_void,
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
            .function,
            .array,
            .array_sentinel,
            .array_u8,
            .array_u8_sentinel_0,
            .pointer,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
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
            .optional,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            .enum_literal,
            .error_union,
            .@"anyframe",
            .anyframe_T,
            .anyerror_void_error_union,
            .error_set,
            .error_set_single,
            .empty_struct,
            => false,

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
            => true,
        };
    }

    /// Returns true if and only if the type is a fixed-width, unsigned integer.
    pub fn isUnsignedInt(self: Type) bool {
        return switch (self.tag()) {
            .f16,
            .f32,
            .f64,
            .f128,
            .c_longdouble,
            .c_void,
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
            .function,
            .array,
            .array_sentinel,
            .array_u8,
            .array_u8_sentinel_0,
            .pointer,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
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
            .optional,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            .enum_literal,
            .error_union,
            .@"anyframe",
            .anyframe_T,
            .anyerror_void_error_union,
            .error_set,
            .error_set_single,
            .empty_struct,
            => false,

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
            => true,
        };
    }

    /// Asserts the type is an integer.
    pub fn intInfo(self: Type, target: Target) struct { signedness: std.builtin.Signedness, bits: u16 } {
        return switch (self.tag()) {
            .f16,
            .f32,
            .f64,
            .f128,
            .c_longdouble,
            .c_void,
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
            .function,
            .array,
            .array_sentinel,
            .array_u8,
            .array_u8_sentinel_0,
            .pointer,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            .optional,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            .enum_literal,
            .error_union,
            .@"anyframe",
            .anyframe_T,
            .anyerror_void_error_union,
            .error_set,
            .error_set_single,
            .empty_struct,
            => unreachable,

            .int_unsigned => .{ .signedness = .unsigned, .bits = self.cast(Payload.IntUnsigned).?.bits },
            .int_signed => .{ .signedness = .signed, .bits = self.cast(Payload.IntSigned).?.bits },
            .u8 => .{ .signedness = .unsigned, .bits = 8 },
            .i8 => .{ .signedness = .signed, .bits = 8 },
            .u16 => .{ .signedness = .unsigned, .bits = 16 },
            .i16 => .{ .signedness = .signed, .bits = 16 },
            .u32 => .{ .signedness = .unsigned, .bits = 32 },
            .i32 => .{ .signedness = .signed, .bits = 32 },
            .u64 => .{ .signedness = .unsigned, .bits = 64 },
            .i64 => .{ .signedness = .signed, .bits = 64 },
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
        };
    }

    pub fn isNamedInt(self: Type) bool {
        return switch (self.tag()) {
            .f16,
            .f32,
            .f64,
            .f128,
            .c_longdouble,
            .c_void,
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
            .function,
            .array,
            .array_sentinel,
            .array_u8,
            .array_u8_sentinel_0,
            .pointer,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            .int_unsigned,
            .int_signed,
            .u8,
            .i8,
            .u16,
            .i16,
            .u32,
            .i32,
            .u64,
            .i64,
            .optional,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            .enum_literal,
            .error_union,
            .@"anyframe",
            .anyframe_T,
            .anyerror_void_error_union,
            .error_set,
            .error_set_single,
            .empty_struct,
            => false,

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
            .function => @fieldParentPtr(Payload.Function, "base", self.ptr_otherwise).param_types.len,

            .f16,
            .f32,
            .f64,
            .f128,
            .c_longdouble,
            .c_void,
            .bool,
            .void,
            .type,
            .anyerror,
            .comptime_int,
            .comptime_float,
            .noreturn,
            .@"null",
            .@"undefined",
            .array,
            .array_sentinel,
            .array_u8,
            .array_u8_sentinel_0,
            .pointer,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            .u8,
            .i8,
            .u16,
            .i16,
            .u32,
            .i32,
            .u64,
            .i64,
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
            .optional,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            .enum_literal,
            .error_union,
            .@"anyframe",
            .anyframe_T,
            .anyerror_void_error_union,
            .error_set,
            .error_set_single,
            .empty_struct,
            => unreachable,
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
                const payload = @fieldParentPtr(Payload.Function, "base", self.ptr_otherwise);
                std.mem.copy(Type, types, payload.param_types);
            },

            .f16,
            .f32,
            .f64,
            .f128,
            .c_longdouble,
            .c_void,
            .bool,
            .void,
            .type,
            .anyerror,
            .comptime_int,
            .comptime_float,
            .noreturn,
            .@"null",
            .@"undefined",
            .array,
            .array_sentinel,
            .array_u8,
            .array_u8_sentinel_0,
            .pointer,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            .u8,
            .i8,
            .u16,
            .i16,
            .u32,
            .i32,
            .u64,
            .i64,
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
            .optional,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            .enum_literal,
            .error_union,
            .@"anyframe",
            .anyframe_T,
            .anyerror_void_error_union,
            .error_set,
            .error_set_single,
            .empty_struct,
            => unreachable,
        }
    }

    /// Asserts the type is a function.
    pub fn fnParamType(self: Type, index: usize) Type {
        switch (self.tag()) {
            .function => {
                const payload = @fieldParentPtr(Payload.Function, "base", self.ptr_otherwise);
                return payload.param_types[index];
            },

            .fn_noreturn_no_args,
            .fn_void_no_args,
            .fn_naked_noreturn_no_args,
            .fn_ccc_void_no_args,
            .f16,
            .f32,
            .f64,
            .f128,
            .c_longdouble,
            .c_void,
            .bool,
            .void,
            .type,
            .anyerror,
            .comptime_int,
            .comptime_float,
            .noreturn,
            .@"null",
            .@"undefined",
            .array,
            .array_sentinel,
            .array_u8,
            .array_u8_sentinel_0,
            .pointer,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            .u8,
            .i8,
            .u16,
            .i16,
            .u32,
            .i32,
            .u64,
            .i64,
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
            .optional,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            .enum_literal,
            .error_union,
            .@"anyframe",
            .anyframe_T,
            .anyerror_void_error_union,
            .error_set,
            .error_set_single,
            .empty_struct,
            => unreachable,
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

            .function => @fieldParentPtr(Payload.Function, "base", self.ptr_otherwise).return_type,

            .f16,
            .f32,
            .f64,
            .f128,
            .c_longdouble,
            .c_void,
            .bool,
            .void,
            .type,
            .anyerror,
            .comptime_int,
            .comptime_float,
            .noreturn,
            .@"null",
            .@"undefined",
            .array,
            .array_sentinel,
            .array_u8,
            .array_u8_sentinel_0,
            .pointer,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            .u8,
            .i8,
            .u16,
            .i16,
            .u32,
            .i32,
            .u64,
            .i64,
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
            .optional,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            .enum_literal,
            .error_union,
            .@"anyframe",
            .anyframe_T,
            .anyerror_void_error_union,
            .error_set,
            .error_set_single,
            .empty_struct,
            => unreachable,
        };
    }

    /// Asserts the type is a function.
    pub fn fnCallingConvention(self: Type) std.builtin.CallingConvention {
        return switch (self.tag()) {
            .fn_noreturn_no_args => .Unspecified,
            .fn_void_no_args => .Unspecified,
            .fn_naked_noreturn_no_args => .Naked,
            .fn_ccc_void_no_args => .C,
            .function => @fieldParentPtr(Payload.Function, "base", self.ptr_otherwise).cc,

            .f16,
            .f32,
            .f64,
            .f128,
            .c_longdouble,
            .c_void,
            .bool,
            .void,
            .type,
            .anyerror,
            .comptime_int,
            .comptime_float,
            .noreturn,
            .@"null",
            .@"undefined",
            .array,
            .array_sentinel,
            .array_u8,
            .array_u8_sentinel_0,
            .pointer,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            .u8,
            .i8,
            .u16,
            .i16,
            .u32,
            .i32,
            .u64,
            .i64,
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
            .optional,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            .enum_literal,
            .error_union,
            .@"anyframe",
            .anyframe_T,
            .anyerror_void_error_union,
            .error_set,
            .error_set_single,
            .empty_struct,
            => unreachable,
        };
    }

    /// Asserts the type is a function.
    pub fn fnIsVarArgs(self: Type) bool {
        return switch (self.tag()) {
            .fn_noreturn_no_args => false,
            .fn_void_no_args => false,
            .fn_naked_noreturn_no_args => false,
            .fn_ccc_void_no_args => false,
            .function => false,

            .f16,
            .f32,
            .f64,
            .f128,
            .c_longdouble,
            .c_void,
            .bool,
            .void,
            .type,
            .anyerror,
            .comptime_int,
            .comptime_float,
            .noreturn,
            .@"null",
            .@"undefined",
            .array,
            .array_sentinel,
            .array_u8,
            .array_u8_sentinel_0,
            .pointer,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            .u8,
            .i8,
            .u16,
            .i16,
            .u32,
            .i32,
            .u64,
            .i64,
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
            .optional,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            .enum_literal,
            .error_union,
            .@"anyframe",
            .anyframe_T,
            .anyerror_void_error_union,
            .error_set,
            .error_set_single,
            .empty_struct,
            => unreachable,
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

            .c_void,
            .bool,
            .void,
            .type,
            .anyerror,
            .noreturn,
            .@"null",
            .@"undefined",
            .fn_noreturn_no_args,
            .fn_void_no_args,
            .fn_naked_noreturn_no_args,
            .fn_ccc_void_no_args,
            .function,
            .array,
            .array_sentinel,
            .array_u8,
            .array_u8_sentinel_0,
            .pointer,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .const_slice,
            .mut_slice,
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            .optional,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            .enum_literal,
            .error_union,
            .@"anyframe",
            .anyframe_T,
            .anyerror_void_error_union,
            .error_set,
            .error_set_single,
            .empty_struct,
            => false,
        };
    }

    pub fn onePossibleValue(self: Type) ?Value {
        var ty = self;
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
            .anyframe_T,
            .@"anyframe",
            .error_union,
            .error_set,
            .error_set_single,
            => return null,

            .empty_struct => return Value.initTag(.empty_struct_value),
            .void => return Value.initTag(.void_value),
            .noreturn => return Value.initTag(.unreachable_value),
            .@"null" => return Value.initTag(.null_value),
            .@"undefined" => return Value.initTag(.undef),

            .int_unsigned => {
                if (ty.cast(Payload.IntUnsigned).?.bits == 0) {
                    return Value.initTag(.zero);
                } else {
                    return null;
                }
            },
            .int_signed => {
                if (ty.cast(Payload.IntSigned).?.bits == 0) {
                    return Value.initTag(.zero);
                } else {
                    return null;
                }
            },
            .array, .array_u8 => {
                if (ty.arrayLen() == 0)
                    return Value.initTag(.empty_array);
                ty = ty.elemType();
                continue;
            },
            .many_const_pointer,
            .many_mut_pointer,
            .c_const_pointer,
            .c_mut_pointer,
            .single_const_pointer,
            .single_mut_pointer,
            => {
                const ptr = ty.castPointer().?;
                ty = ptr.pointee_type;
                continue;
            },
            .pointer => {
                ty = ty.cast(Payload.Pointer).?.pointee_type;
                continue;
            },
        };
    }

    pub fn isCPtr(self: Type) bool {
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
            .const_slice_u8,
            .c_void,
            .void,
            .noreturn,
            .@"null",
            .@"undefined",
            .int_unsigned,
            .int_signed,
            .array,
            .array_sentinel,
            .array_u8,
            .array_u8_sentinel_0,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .const_slice,
            .mut_slice,
            .optional,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            .enum_literal,
            .error_union,
            .@"anyframe",
            .anyframe_T,
            .anyerror_void_error_union,
            .error_set,
            .error_set_single,
            .empty_struct,
            => return false,

            .c_const_pointer,
            .c_mut_pointer,
            => return true,

            .pointer => self.cast(Payload.Pointer).?.size == .C,
        };
    }

    pub fn isIndexable(self: Type) bool {
        const zig_tag = self.zigTypeTag();
        // TODO tuples are indexable
        return zig_tag == .Array or zig_tag == .Vector or self.isSlice() or
            (self.isSinglePointer() and self.elemType().zigTypeTag() == .Array);
    }

    /// Asserts that the type is a container. (note: ErrorSet is not a container).
    pub fn getContainerScope(self: Type) *Module.Scope.Container {
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
            .const_slice_u8,
            .c_void,
            .void,
            .noreturn,
            .@"null",
            .@"undefined",
            .int_unsigned,
            .int_signed,
            .array,
            .array_sentinel,
            .array_u8,
            .array_u8_sentinel_0,
            .single_const_pointer,
            .single_mut_pointer,
            .many_const_pointer,
            .many_mut_pointer,
            .const_slice,
            .mut_slice,
            .optional,
            .optional_single_mut_pointer,
            .optional_single_const_pointer,
            .enum_literal,
            .error_union,
            .@"anyframe",
            .anyframe_T,
            .anyerror_void_error_union,
            .error_set,
            .error_set_single,
            .c_const_pointer,
            .c_mut_pointer,
            .pointer,
            => unreachable,

            .empty_struct => self.cast(Type.Payload.EmptyStruct).?.scope,
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
            const payload = try arena.allocator.create(Value.Payload.Int_i64);
            payload.* = .{
                .int = -(@as(i64, 1) << @truncate(u6, info.bits - 1)),
            };
            return Value.initPayload(&payload.base);
        }

        var res = try std.math.big.int.Managed.initSet(&arena.allocator, 1);
        try res.shiftLeft(res, info.bits - 1);
        res.negate();

        const res_const = res.toConst();
        if (res_const.positive) {
            const val_payload = try arena.allocator.create(Value.Payload.IntBigPositive);
            val_payload.* = .{ .limbs = res_const.limbs };
            return Value.initPayload(&val_payload.base);
        } else {
            const val_payload = try arena.allocator.create(Value.Payload.IntBigNegative);
            val_payload.* = .{ .limbs = res_const.limbs };
            return Value.initPayload(&val_payload.base);
        }
    }

    /// Asserts that self.zigTypeTag() == .Int.
    pub fn maxInt(self: Type, arena: *std.heap.ArenaAllocator, target: Target) !Value {
        assert(self.zigTypeTag() == .Int);
        const info = self.intInfo(target);

        if (info.signedness == .signed and (info.bits - 1) <= std.math.maxInt(u6)) {
            const payload = try arena.allocator.create(Value.Payload.Int_i64);
            payload.* = .{
                .int = (@as(i64, 1) << @truncate(u6, info.bits - 1)) - 1,
            };
            return Value.initPayload(&payload.base);
        } else if (info.signedness == .signed and info.bits <= std.math.maxInt(u6)) {
            const payload = try arena.allocator.create(Value.Payload.Int_u64);
            payload.* = .{
                .int = (@as(u64, 1) << @truncate(u6, info.bits)) - 1,
            };
            return Value.initPayload(&payload.base);
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
            const val_payload = try arena.allocator.create(Value.Payload.IntBigPositive);
            val_payload.* = .{ .limbs = res_const.limbs };
            return Value.initPayload(&val_payload.base);
        } else {
            const val_payload = try arena.allocator.create(Value.Payload.IntBigNegative);
            val_payload.* = .{ .limbs = res_const.limbs };
            return Value.initPayload(&val_payload.base);
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
        enum_literal,
        @"null",
        @"undefined",
        fn_noreturn_no_args,
        fn_void_no_args,
        fn_naked_noreturn_no_args,
        fn_ccc_void_no_args,
        single_const_pointer_to_comptime_int,
        anyerror_void_error_union,
        @"anyframe",
        const_slice_u8, // See last_no_payload_tag below.
        // After this, the tag requires a payload.

        array_u8,
        array_u8_sentinel_0,
        array,
        array_sentinel,
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

        pub const last_no_payload_tag = Tag.const_slice_u8;
        pub const no_payload_count = @enumToInt(last_no_payload_tag) + 1;
    };

    pub const Payload = struct {
        tag: Tag,

        pub const Array_u8_Sentinel0 = struct {
            base: Payload = Payload{ .tag = .array_u8_sentinel_0 },

            len: u64,
        };

        pub const Array_u8 = struct {
            base: Payload = Payload{ .tag = .array_u8 },

            len: u64,
        };

        pub const Array = struct {
            base: Payload = Payload{ .tag = .array },

            len: u64,
            elem_type: Type,
        };

        pub const ArraySentinel = struct {
            base: Payload = Payload{ .tag = .array_sentinel },

            len: u64,
            sentinel: Value,
            elem_type: Type,
        };

        pub const PointerSimple = struct {
            base: Payload,

            pointee_type: Type,
        };

        pub const IntSigned = struct {
            base: Payload = Payload{ .tag = .int_signed },

            bits: u16,
        };

        pub const IntUnsigned = struct {
            base: Payload = Payload{ .tag = .int_unsigned },

            bits: u16,
        };

        pub const Function = struct {
            base: Payload = Payload{ .tag = .function },

            param_types: []Type,
            return_type: Type,
            cc: std.builtin.CallingConvention,
        };

        pub const Optional = struct {
            base: Payload = Payload{ .tag = .optional },

            child_type: Type,
        };

        pub const Pointer = struct {
            base: Payload = .{ .tag = .pointer },

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
        };

        pub const ErrorUnion = struct {
            base: Payload = .{ .tag = .error_union },

            error_set: Type,
            payload: Type,
        };

        pub const AnyFrame = struct {
            base: Payload = .{ .tag = .anyframe_T },

            return_type: Type,
        };

        pub const ErrorSet = struct {
            base: Payload = .{ .tag = .error_set },

            decl: *Module.Decl,
        };

        pub const ErrorSetSingle = struct {
            base: Payload = .{ .tag = .error_set_single },

            /// memory is owned by `Module`
            name: []const u8,
        };

        /// Mostly used for namespace like structs with zero fields.
        /// Most commonly used for files.
        pub const EmptyStruct = struct {
            base: Payload = .{ .tag = .empty_struct },

            scope: *Module.Scope.Container,
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
            .haiku,
            .minix,
            .rtems,
            .nacl,
            .cnk,
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
            => @panic("TODO specify the C integer and float type sizes for this OS"),
        }
    }
};
