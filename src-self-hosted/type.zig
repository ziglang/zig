const std = @import("std");
const Value = @import("value.zig").Value;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Target = std.Target;

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
            .c_longdouble,
            .int_signed,
            .int_unsigned,
            => return .Int,

            .f16,
            .f32,
            .f64,
            .f128,
            => return .Float,

            .c_void => return .Opaque,
            .bool => return .Bool,
            .void => return .Void,
            .type => return .Type,
            .anyerror => return .ErrorSet,
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

            .array, .array_u8_sentinel_0 => return .Array,
            .single_const_pointer => return .Pointer,
            .single_const_pointer_to_comptime_int => return .Pointer,
            .const_slice_u8 => return .Pointer,
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

    pub fn eql(a: Type, b: Type) bool {
        //std.debug.warn("test {} == {}\n", .{ a, b });
        // As a shortcut, if the small tags / addresses match, we're done.
        if (a.tag_if_small_enough == b.tag_if_small_enough)
            return true;
        const zig_tag_a = a.zigTypeTag();
        const zig_tag_b = b.zigTypeTag();
        if (zig_tag_a != zig_tag_b)
            return false;
        switch (zig_tag_a) {
            .Type => return true,
            .Void => return true,
            .Bool => return true,
            .NoReturn => return true,
            .ComptimeFloat => return true,
            .ComptimeInt => return true,
            .Undefined => return true,
            .Null => return true,
            .Pointer => {
                // Hot path for common case:
                if (a.cast(Payload.SingleConstPointer)) |a_payload| {
                    if (b.cast(Payload.SingleConstPointer)) |b_payload| {
                        return eql(a_payload.pointee_type, b_payload.pointee_type);
                    }
                }
                const is_slice_a = isSlice(a);
                const is_slice_b = isSlice(b);
                if (is_slice_a != is_slice_b)
                    return false;
                @panic("TODO implement more pointer Type equality comparison");
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
                return info_a.signed == info_b.signed and info_a.bits == info_b.bits;
            },
            .Array => {
                if (a.arrayLen() != b.arrayLen())
                    return false;
                if (a.elemType().eql(b.elemType()))
                    return false;
                const sentinel_a = a.arraySentinel();
                const sentinel_b = b.arraySentinel();
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
            .Float,
            .Struct,
            .Optional,
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
            => std.debug.panic("TODO implement Type equality comparison of {} and {}", .{ a, b }),
        }
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
            => unreachable,

            .array_u8_sentinel_0 => return self.copyPayloadShallow(allocator, Payload.Array_u8_Sentinel0),
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
            .single_const_pointer => {
                const payload = @fieldParentPtr(Payload.SingleConstPointer, "base", self.ptr_otherwise);
                const new_payload = try allocator.create(Payload.SingleConstPointer);
                new_payload.* = .{
                    .base = payload.base,
                    .pointee_type = try payload.pointee_type.copy(allocator),
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
        }
    }

    fn copyPayloadShallow(self: Type, allocator: *Allocator, comptime T: type) error{OutOfMemory}!Type {
        const payload = @fieldParentPtr(T, "base", self.ptr_otherwise);
        const new_payload = try allocator.create(T);
        new_payload.* = payload.*;
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

                .@"null" => return out_stream.writeAll("@TypeOf(null)"),
                .@"undefined" => return out_stream.writeAll("@TypeOf(undefined)"),

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
                    try payload.return_type.format("", .{}, out_stream);
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
                .single_const_pointer => {
                    const payload = @fieldParentPtr(Payload.SingleConstPointer, "base", ty.ptr_otherwise);
                    try out_stream.writeAll("*const ");
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
            .array, // TODO check for zero bits
            .single_const_pointer,
            .int_signed, // TODO check for zero bits
            .int_unsigned, // TODO check for zero bits
            => true,

            .c_void,
            .void,
            .type,
            .comptime_int,
            .comptime_float,
            .noreturn,
            .@"null",
            .@"undefined",
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
            .fn_noreturn_no_args, // represents machine code; not a pointer
            .fn_void_no_args, // represents machine code; not a pointer
            .fn_naked_noreturn_no_args, // represents machine code; not a pointer
            .fn_ccc_void_no_args, // represents machine code; not a pointer
            .function, // represents machine code; not a pointer
            .array_u8_sentinel_0,
            => return 1,

            .i16, .u16 => return 2,
            .i32, .u32 => return 4,
            .i64, .u64 => return 8,

            .isize,
            .usize,
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            .single_const_pointer,
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

            .anyerror => return 2, // TODO revisit this when we have the concept of the error tag type

            .array => return self.cast(Payload.Array).?.elem_type.abiAlignment(target),

            .int_signed, .int_unsigned => {
                const bits: u16 = if (self.cast(Payload.IntSigned)) |pl|
                    pl.bits
                else if (self.cast(Payload.IntUnsigned)) |pl|
                    pl.bits
                else
                    unreachable;

                return std.math.ceilPowerOfTwoPromote(u16, (bits + 7) / 8);
            },

            .c_void,
            .void,
            .type,
            .comptime_int,
            .comptime_float,
            .noreturn,
            .@"null",
            .@"undefined",
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

            .u8,
            .i8,
            .bool,
            => return 1,

            .array_u8_sentinel_0 => @fieldParentPtr(Payload.Array_u8_Sentinel0, "base", self.ptr_otherwise).len,
            .array => {
                const payload = @fieldParentPtr(Payload.Array, "base", self.ptr_otherwise);
                const elem_size = std.math.max(payload.elem_type.abiAlignment(target), payload.elem_type.abiSize(target));
                return payload.len * elem_size;
            },
            .i16, .u16 => return 2,
            .i32, .u32 => return 4,
            .i64, .u64 => return 8,

            .isize,
            .usize,
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            .single_const_pointer,
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

            .anyerror => return 2, // TODO revisit this when we have the concept of the error tag type

            .int_signed, .int_unsigned => {
                const bits: u16 = if (self.cast(Payload.IntSigned)) |pl|
                    pl.bits
                else if (self.cast(Payload.IntUnsigned)) |pl|
                    pl.bits
                else
                    unreachable;

                return std.math.ceilPowerOfTwoPromote(u16, (bits + 7) / 8);
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
            .array_u8_sentinel_0,
            .const_slice_u8,
            .fn_noreturn_no_args,
            .fn_void_no_args,
            .fn_naked_noreturn_no_args,
            .fn_ccc_void_no_args,
            .function,
            .int_unsigned,
            .int_signed,
            => false,

            .single_const_pointer,
            .single_const_pointer_to_comptime_int,
            => true,
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
            .array_u8_sentinel_0,
            .single_const_pointer,
            .single_const_pointer_to_comptime_int,
            .fn_noreturn_no_args,
            .fn_void_no_args,
            .fn_naked_noreturn_no_args,
            .fn_ccc_void_no_args,
            .function,
            .int_unsigned,
            .int_signed,
            => false,

            .const_slice_u8 => true,
        };
    }

    /// Asserts the type is a pointer type.
    pub fn pointerIsConst(self: Type) bool {
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
            .array_u8_sentinel_0,
            .fn_noreturn_no_args,
            .fn_void_no_args,
            .fn_naked_noreturn_no_args,
            .fn_ccc_void_no_args,
            .function,
            .int_unsigned,
            .int_signed,
            => unreachable,

            .single_const_pointer,
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            => true,
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
            => unreachable,

            .array => self.cast(Payload.Array).?.elem_type,
            .single_const_pointer => self.cast(Payload.SingleConstPointer).?.pointee_type,
            .array_u8_sentinel_0, .const_slice_u8 => Type.initTag(.u8),
            .single_const_pointer_to_comptime_int => Type.initTag(.comptime_int),
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
            .single_const_pointer,
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            .int_unsigned,
            .int_signed,
            => unreachable,

            .array => self.cast(Payload.Array).?.len,
            .array_u8_sentinel_0 => self.cast(Payload.Array_u8_Sentinel0).?.len,
        };
    }

    /// Asserts the type is an array or vector.
    pub fn arraySentinel(self: Type) ?Value {
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
            .single_const_pointer,
            .single_const_pointer_to_comptime_int,
            .const_slice_u8,
            .int_unsigned,
            .int_signed,
            => unreachable,

            .array => return null,
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
            .single_const_pointer,
            .single_const_pointer_to_comptime_int,
            .array_u8_sentinel_0,
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
            .single_const_pointer,
            .single_const_pointer_to_comptime_int,
            .array_u8_sentinel_0,
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
    pub fn intInfo(self: Type, target: Target) struct { signed: bool, bits: u16 } {
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
            .single_const_pointer,
            .single_const_pointer_to_comptime_int,
            .array_u8_sentinel_0,
            .const_slice_u8,
            => unreachable,

            .int_unsigned => .{ .signed = false, .bits = self.cast(Payload.IntUnsigned).?.bits },
            .int_signed => .{ .signed = true, .bits = self.cast(Payload.IntSigned).?.bits },
            .u8 => .{ .signed = false, .bits = 8 },
            .i8 => .{ .signed = true, .bits = 8 },
            .u16 => .{ .signed = false, .bits = 16 },
            .i16 => .{ .signed = true, .bits = 16 },
            .u32 => .{ .signed = false, .bits = 32 },
            .i32 => .{ .signed = true, .bits = 32 },
            .u64 => .{ .signed = false, .bits = 64 },
            .i64 => .{ .signed = true, .bits = 64 },
            .usize => .{ .signed = false, .bits = target.cpu.arch.ptrBitWidth() },
            .isize => .{ .signed = true, .bits = target.cpu.arch.ptrBitWidth() },
            .c_short => .{ .signed = true, .bits = CType.short.sizeInBits(target) },
            .c_ushort => .{ .signed = false, .bits = CType.ushort.sizeInBits(target) },
            .c_int => .{ .signed = true, .bits = CType.int.sizeInBits(target) },
            .c_uint => .{ .signed = false, .bits = CType.uint.sizeInBits(target) },
            .c_long => .{ .signed = true, .bits = CType.long.sizeInBits(target) },
            .c_ulong => .{ .signed = false, .bits = CType.ulong.sizeInBits(target) },
            .c_longlong => .{ .signed = true, .bits = CType.longlong.sizeInBits(target) },
            .c_ulonglong => .{ .signed = false, .bits = CType.ulonglong.sizeInBits(target) },
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
            .single_const_pointer,
            .single_const_pointer_to_comptime_int,
            .array_u8_sentinel_0,
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
            .single_const_pointer,
            .single_const_pointer_to_comptime_int,
            .array_u8_sentinel_0,
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
            .single_const_pointer,
            .single_const_pointer_to_comptime_int,
            .array_u8_sentinel_0,
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
            .single_const_pointer,
            .single_const_pointer_to_comptime_int,
            .array_u8_sentinel_0,
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
            .single_const_pointer,
            .single_const_pointer_to_comptime_int,
            .array_u8_sentinel_0,
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
            .single_const_pointer,
            .single_const_pointer_to_comptime_int,
            .array_u8_sentinel_0,
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
            .single_const_pointer,
            .single_const_pointer_to_comptime_int,
            .array_u8_sentinel_0,
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
            .single_const_pointer,
            .single_const_pointer_to_comptime_int,
            .array_u8_sentinel_0,
            .const_slice_u8,
            => false,
        };
    }

    pub fn onePossibleValue(self: Type) bool {
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
            .array_u8_sentinel_0,
            .const_slice_u8,
            => return false,

            .c_void,
            .void,
            .noreturn,
            .@"null",
            .@"undefined",
            => return true,

            .int_unsigned => return ty.cast(Payload.IntUnsigned).?.bits == 0,
            .int_signed => return ty.cast(Payload.IntSigned).?.bits == 0,
            .array => {
                const array = ty.cast(Payload.Array).?;
                if (array.len == 0)
                    return true;
                ty = array.elem_type;
                continue;
            },
            .single_const_pointer => {
                const ptr = ty.cast(Payload.SingleConstPointer).?;
                ty = ptr.pointee_type;
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
            .array_u8_sentinel_0,
            .const_slice_u8,
            .c_void,
            .void,
            .noreturn,
            .@"null",
            .@"undefined",
            .int_unsigned,
            .int_signed,
            .array,
            .single_const_pointer,
            => return false,
        };
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
        @"null",
        @"undefined",
        fn_noreturn_no_args,
        fn_void_no_args,
        fn_naked_noreturn_no_args,
        fn_ccc_void_no_args,
        single_const_pointer_to_comptime_int,
        const_slice_u8, // See last_no_payload_tag below.
        // After this, the tag requires a payload.

        array_u8_sentinel_0,
        array,
        single_const_pointer,
        int_signed,
        int_unsigned,
        function,

        pub const last_no_payload_tag = Tag.const_slice_u8;
        pub const no_payload_count = @enumToInt(last_no_payload_tag) + 1;
    };

    pub const Payload = struct {
        tag: Tag,

        pub const Array_u8_Sentinel0 = struct {
            base: Payload = Payload{ .tag = .array_u8_sentinel_0 },

            len: u64,
        };

        pub const Array = struct {
            base: Payload = Payload{ .tag = .array },

            elem_type: Type,
            len: u64,
        };

        pub const SingleConstPointer = struct {
            base: Payload = Payload{ .tag = .single_const_pointer },

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
            .macosx,
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
