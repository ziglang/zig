const std = @import("std");
const Type = @import("type.zig").Type;
const log2 = std.math.log2;
const assert = std.debug.assert;
const BigIntConst = std.math.big.int.Const;
const BigIntMutable = std.math.big.int.Mutable;
const Target = std.Target;
const Allocator = std.mem.Allocator;
const Module = @import("Module.zig");

/// This is the raw data, with no bookkeeping, no memory awareness,
/// no de-duplication, and no type system awareness.
/// It's important for this type to be small.
/// This union takes advantage of the fact that the first page of memory
/// is unmapped, giving us 4096 possible enum tags that have no payload.
pub const Value = extern union {
    /// If the tag value is less than Tag.no_payload_count, then no pointer
    /// dereference is needed.
    tag_if_small_enough: usize,
    ptr_otherwise: *Payload,

    pub const Tag = enum {
        // The first section of this enum are tags that require no payload.
        u8_type,
        i8_type,
        u16_type,
        i16_type,
        u32_type,
        i32_type,
        u64_type,
        i64_type,
        usize_type,
        isize_type,
        c_short_type,
        c_ushort_type,
        c_int_type,
        c_uint_type,
        c_long_type,
        c_ulong_type,
        c_longlong_type,
        c_ulonglong_type,
        c_longdouble_type,
        f16_type,
        f32_type,
        f64_type,
        f128_type,
        c_void_type,
        bool_type,
        void_type,
        type_type,
        anyerror_type,
        comptime_int_type,
        comptime_float_type,
        noreturn_type,
        null_type,
        undefined_type,
        fn_noreturn_no_args_type,
        fn_void_no_args_type,
        fn_naked_noreturn_no_args_type,
        fn_ccc_void_no_args_type,
        single_const_pointer_to_comptime_int_type,
        const_slice_u8_type,
        enum_literal_type,
        anyframe_type,

        undef,
        zero,
        one,
        void_value,
        unreachable_value,
        empty_struct_value,
        empty_array,
        null_value,
        bool_true,
        bool_false, // See last_no_payload_tag below.
        // After this, the tag requires a payload.

        ty,
        int_type,
        int_u64,
        int_i64,
        int_big_positive,
        int_big_negative,
        function,
        variable,
        ref_val,
        decl_ref,
        elem_ptr,
        bytes,
        repeated, // the value is a value repeated some number of times
        float_16,
        float_32,
        float_64,
        float_128,
        enum_literal,
        error_set,
        @"error",

        pub const last_no_payload_tag = Tag.bool_false;
        pub const no_payload_count = @enumToInt(last_no_payload_tag) + 1;
    };

    pub fn initTag(small_tag: Tag) Value {
        assert(@enumToInt(small_tag) < Tag.no_payload_count);
        return .{ .tag_if_small_enough = @enumToInt(small_tag) };
    }

    pub fn initPayload(payload: *Payload) Value {
        assert(@enumToInt(payload.tag) >= Tag.no_payload_count);
        return .{ .ptr_otherwise = payload };
    }

    pub fn tag(self: Value) Tag {
        if (self.tag_if_small_enough < Tag.no_payload_count) {
            return @intToEnum(Tag, @intCast(@TagType(Tag), self.tag_if_small_enough));
        } else {
            return self.ptr_otherwise.tag;
        }
    }

    pub fn cast(self: Value, comptime T: type) ?*T {
        if (self.tag_if_small_enough < Tag.no_payload_count)
            return null;

        const expected_tag = std.meta.fieldInfo(T, "base").default_value.?.tag;
        if (self.ptr_otherwise.tag != expected_tag)
            return null;

        return @fieldParentPtr(T, "base", self.ptr_otherwise);
    }

    pub fn copy(self: Value, allocator: *Allocator) error{OutOfMemory}!Value {
        if (self.tag_if_small_enough < Tag.no_payload_count) {
            return Value{ .tag_if_small_enough = self.tag_if_small_enough };
        } else switch (self.ptr_otherwise.tag) {
            .u8_type,
            .i8_type,
            .u16_type,
            .i16_type,
            .u32_type,
            .i32_type,
            .u64_type,
            .i64_type,
            .usize_type,
            .isize_type,
            .c_short_type,
            .c_ushort_type,
            .c_int_type,
            .c_uint_type,
            .c_long_type,
            .c_ulong_type,
            .c_longlong_type,
            .c_ulonglong_type,
            .c_longdouble_type,
            .f16_type,
            .f32_type,
            .f64_type,
            .f128_type,
            .c_void_type,
            .bool_type,
            .void_type,
            .type_type,
            .anyerror_type,
            .comptime_int_type,
            .comptime_float_type,
            .noreturn_type,
            .null_type,
            .undefined_type,
            .fn_noreturn_no_args_type,
            .fn_void_no_args_type,
            .fn_naked_noreturn_no_args_type,
            .fn_ccc_void_no_args_type,
            .single_const_pointer_to_comptime_int_type,
            .const_slice_u8_type,
            .enum_literal_type,
            .anyframe_type,
            .undef,
            .zero,
            .one,
            .void_value,
            .unreachable_value,
            .empty_array,
            .null_value,
            .bool_true,
            .bool_false,
            .empty_struct_value,
            => unreachable,

            .ty => {
                const payload = @fieldParentPtr(Payload.Ty, "base", self.ptr_otherwise);
                const new_payload = try allocator.create(Payload.Ty);
                new_payload.* = .{
                    .base = payload.base,
                    .ty = try payload.ty.copy(allocator),
                };
                return Value{ .ptr_otherwise = &new_payload.base };
            },
            .int_type => return self.copyPayloadShallow(allocator, Payload.IntType),
            .int_u64 => return self.copyPayloadShallow(allocator, Payload.Int_u64),
            .int_i64 => return self.copyPayloadShallow(allocator, Payload.Int_i64),
            .int_big_positive => {
                @panic("TODO implement copying of big ints");
            },
            .int_big_negative => {
                @panic("TODO implement copying of big ints");
            },
            .function => return self.copyPayloadShallow(allocator, Payload.Function),
            .variable => return self.copyPayloadShallow(allocator, Payload.Variable),
            .ref_val => {
                const payload = @fieldParentPtr(Payload.RefVal, "base", self.ptr_otherwise);
                const new_payload = try allocator.create(Payload.RefVal);
                new_payload.* = .{
                    .base = payload.base,
                    .val = try payload.val.copy(allocator),
                };
                return Value{ .ptr_otherwise = &new_payload.base };
            },
            .decl_ref => return self.copyPayloadShallow(allocator, Payload.DeclRef),
            .elem_ptr => {
                const payload = @fieldParentPtr(Payload.ElemPtr, "base", self.ptr_otherwise);
                const new_payload = try allocator.create(Payload.ElemPtr);
                new_payload.* = .{
                    .base = payload.base,
                    .array_ptr = try payload.array_ptr.copy(allocator),
                    .index = payload.index,
                };
                return Value{ .ptr_otherwise = &new_payload.base };
            },
            .bytes => return self.copyPayloadShallow(allocator, Payload.Bytes),
            .repeated => {
                const payload = @fieldParentPtr(Payload.Repeated, "base", self.ptr_otherwise);
                const new_payload = try allocator.create(Payload.Repeated);
                new_payload.* = .{
                    .base = payload.base,
                    .val = try payload.val.copy(allocator),
                };
                return Value{ .ptr_otherwise = &new_payload.base };
            },
            .float_16 => return self.copyPayloadShallow(allocator, Payload.Float_16),
            .float_32 => return self.copyPayloadShallow(allocator, Payload.Float_32),
            .float_64 => return self.copyPayloadShallow(allocator, Payload.Float_64),
            .float_128 => return self.copyPayloadShallow(allocator, Payload.Float_128),
            .enum_literal => {
                const payload = @fieldParentPtr(Payload.Bytes, "base", self.ptr_otherwise);
                const new_payload = try allocator.create(Payload.Bytes);
                new_payload.* = .{
                    .base = payload.base,
                    .data = try allocator.dupe(u8, payload.data),
                };
                return Value{ .ptr_otherwise = &new_payload.base };
            },
            .@"error" => return self.copyPayloadShallow(allocator, Payload.Error),

            // memory is managed by the declaration
            .error_set => return self.copyPayloadShallow(allocator, Payload.ErrorSet),
        }
    }

    fn copyPayloadShallow(self: Value, allocator: *Allocator, comptime T: type) error{OutOfMemory}!Value {
        const payload = @fieldParentPtr(T, "base", self.ptr_otherwise);
        const new_payload = try allocator.create(T);
        new_payload.* = payload.*;
        return Value{ .ptr_otherwise = &new_payload.base };
    }

    pub fn format(
        self: Value,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) !void {
        comptime assert(fmt.len == 0);
        var val = self;
        while (true) switch (val.tag()) {
            .u8_type => return out_stream.writeAll("u8"),
            .i8_type => return out_stream.writeAll("i8"),
            .u16_type => return out_stream.writeAll("u16"),
            .i16_type => return out_stream.writeAll("i16"),
            .u32_type => return out_stream.writeAll("u32"),
            .i32_type => return out_stream.writeAll("i32"),
            .u64_type => return out_stream.writeAll("u64"),
            .i64_type => return out_stream.writeAll("i64"),
            .isize_type => return out_stream.writeAll("isize"),
            .usize_type => return out_stream.writeAll("usize"),
            .c_short_type => return out_stream.writeAll("c_short"),
            .c_ushort_type => return out_stream.writeAll("c_ushort"),
            .c_int_type => return out_stream.writeAll("c_int"),
            .c_uint_type => return out_stream.writeAll("c_uint"),
            .c_long_type => return out_stream.writeAll("c_long"),
            .c_ulong_type => return out_stream.writeAll("c_ulong"),
            .c_longlong_type => return out_stream.writeAll("c_longlong"),
            .c_ulonglong_type => return out_stream.writeAll("c_ulonglong"),
            .c_longdouble_type => return out_stream.writeAll("c_longdouble"),
            .f16_type => return out_stream.writeAll("f16"),
            .f32_type => return out_stream.writeAll("f32"),
            .f64_type => return out_stream.writeAll("f64"),
            .f128_type => return out_stream.writeAll("f128"),
            .c_void_type => return out_stream.writeAll("c_void"),
            .bool_type => return out_stream.writeAll("bool"),
            .void_type => return out_stream.writeAll("void"),
            .type_type => return out_stream.writeAll("type"),
            .anyerror_type => return out_stream.writeAll("anyerror"),
            .comptime_int_type => return out_stream.writeAll("comptime_int"),
            .comptime_float_type => return out_stream.writeAll("comptime_float"),
            .noreturn_type => return out_stream.writeAll("noreturn"),
            .null_type => return out_stream.writeAll("@Type(.Null)"),
            .undefined_type => return out_stream.writeAll("@Type(.Undefined)"),
            .fn_noreturn_no_args_type => return out_stream.writeAll("fn() noreturn"),
            .fn_void_no_args_type => return out_stream.writeAll("fn() void"),
            .fn_naked_noreturn_no_args_type => return out_stream.writeAll("fn() callconv(.Naked) noreturn"),
            .fn_ccc_void_no_args_type => return out_stream.writeAll("fn() callconv(.C) void"),
            .single_const_pointer_to_comptime_int_type => return out_stream.writeAll("*const comptime_int"),
            .const_slice_u8_type => return out_stream.writeAll("[]const u8"),
            .enum_literal_type => return out_stream.writeAll("@Type(.EnumLiteral)"),
            .anyframe_type => return out_stream.writeAll("anyframe"),

            // TODO this should print `NAME{}`
            .empty_struct_value => return out_stream.writeAll("struct {}{}"),
            .null_value => return out_stream.writeAll("null"),
            .undef => return out_stream.writeAll("undefined"),
            .zero => return out_stream.writeAll("0"),
            .one => return out_stream.writeAll("1"),
            .void_value => return out_stream.writeAll("{}"),
            .unreachable_value => return out_stream.writeAll("unreachable"),
            .bool_true => return out_stream.writeAll("true"),
            .bool_false => return out_stream.writeAll("false"),
            .ty => return val.cast(Payload.Ty).?.ty.format("", options, out_stream),
            .int_type => {
                const int_type = val.cast(Payload.IntType).?;
                return out_stream.print("{}{}", .{
                    if (int_type.signed) "s" else "u",
                    int_type.bits,
                });
            },
            .int_u64 => return std.fmt.formatIntValue(val.cast(Payload.Int_u64).?.int, "", options, out_stream),
            .int_i64 => return std.fmt.formatIntValue(val.cast(Payload.Int_i64).?.int, "", options, out_stream),
            .int_big_positive => return out_stream.print("{}", .{val.cast(Payload.IntBigPositive).?.asBigInt()}),
            .int_big_negative => return out_stream.print("{}", .{val.cast(Payload.IntBigNegative).?.asBigInt()}),
            .function => return out_stream.writeAll("(function)"),
            .variable => return out_stream.writeAll("(variable)"),
            .ref_val => {
                const ref_val = val.cast(Payload.RefVal).?;
                try out_stream.writeAll("&const ");
                val = ref_val.val;
            },
            .decl_ref => return out_stream.writeAll("(decl ref)"),
            .elem_ptr => {
                const elem_ptr = val.cast(Payload.ElemPtr).?;
                try out_stream.print("&[{}] ", .{elem_ptr.index});
                val = elem_ptr.array_ptr;
            },
            .empty_array => return out_stream.writeAll(".{}"),
            .enum_literal => return out_stream.print(".{z}", .{self.cast(Payload.Bytes).?.data}),
            .bytes => return out_stream.print("\"{Z}\"", .{self.cast(Payload.Bytes).?.data}),
            .repeated => {
                try out_stream.writeAll("(repeated) ");
                val = val.cast(Payload.Repeated).?.val;
            },
            .float_16 => return out_stream.print("{}", .{val.cast(Payload.Float_16).?.val}),
            .float_32 => return out_stream.print("{}", .{val.cast(Payload.Float_32).?.val}),
            .float_64 => return out_stream.print("{}", .{val.cast(Payload.Float_64).?.val}),
            .float_128 => return out_stream.print("{}", .{val.cast(Payload.Float_128).?.val}),
            .error_set => {
                const error_set = val.cast(Payload.ErrorSet).?;
                try out_stream.writeAll("error{");
                var it = error_set.fields.iterator();
                while (it.next()) |entry| {
                    try out_stream.print("{},", .{entry.value});
                }
                return out_stream.writeAll("}");
            },
            .@"error" => return out_stream.print("error.{}", .{val.cast(Payload.Error).?.name}),
        };
    }

    /// Asserts that the value is representable as an array of bytes.
    /// Copies the value into a freshly allocated slice of memory, which is owned by the caller.
    pub fn toAllocatedBytes(self: Value, allocator: *Allocator) ![]u8 {
        if (self.cast(Payload.Bytes)) |bytes| {
            return std.mem.dupe(allocator, u8, bytes.data);
        }
        if (self.cast(Payload.Repeated)) |repeated| {
            @panic("TODO implement toAllocatedBytes for this Value tag");
        }
        if (self.cast(Payload.DeclRef)) |declref| {
            const val = try declref.decl.value();
            return val.toAllocatedBytes(allocator);
        }
        unreachable;
    }

    /// Asserts that the value is representable as a type.
    pub fn toType(self: Value, allocator: *Allocator) !Type {
        return switch (self.tag()) {
            .ty => self.cast(Payload.Ty).?.ty,
            .u8_type => Type.initTag(.u8),
            .i8_type => Type.initTag(.i8),
            .u16_type => Type.initTag(.u16),
            .i16_type => Type.initTag(.i16),
            .u32_type => Type.initTag(.u32),
            .i32_type => Type.initTag(.i32),
            .u64_type => Type.initTag(.u64),
            .i64_type => Type.initTag(.i64),
            .usize_type => Type.initTag(.usize),
            .isize_type => Type.initTag(.isize),
            .c_short_type => Type.initTag(.c_short),
            .c_ushort_type => Type.initTag(.c_ushort),
            .c_int_type => Type.initTag(.c_int),
            .c_uint_type => Type.initTag(.c_uint),
            .c_long_type => Type.initTag(.c_long),
            .c_ulong_type => Type.initTag(.c_ulong),
            .c_longlong_type => Type.initTag(.c_longlong),
            .c_ulonglong_type => Type.initTag(.c_ulonglong),
            .c_longdouble_type => Type.initTag(.c_longdouble),
            .f16_type => Type.initTag(.f16),
            .f32_type => Type.initTag(.f32),
            .f64_type => Type.initTag(.f64),
            .f128_type => Type.initTag(.f128),
            .c_void_type => Type.initTag(.c_void),
            .bool_type => Type.initTag(.bool),
            .void_type => Type.initTag(.void),
            .type_type => Type.initTag(.type),
            .anyerror_type => Type.initTag(.anyerror),
            .comptime_int_type => Type.initTag(.comptime_int),
            .comptime_float_type => Type.initTag(.comptime_float),
            .noreturn_type => Type.initTag(.noreturn),
            .null_type => Type.initTag(.@"null"),
            .undefined_type => Type.initTag(.@"undefined"),
            .fn_noreturn_no_args_type => Type.initTag(.fn_noreturn_no_args),
            .fn_void_no_args_type => Type.initTag(.fn_void_no_args),
            .fn_naked_noreturn_no_args_type => Type.initTag(.fn_naked_noreturn_no_args),
            .fn_ccc_void_no_args_type => Type.initTag(.fn_ccc_void_no_args),
            .single_const_pointer_to_comptime_int_type => Type.initTag(.single_const_pointer_to_comptime_int),
            .const_slice_u8_type => Type.initTag(.const_slice_u8),
            .enum_literal_type => Type.initTag(.enum_literal),
            .anyframe_type => Type.initTag(.@"anyframe"),

            .int_type => {
                const payload = self.cast(Payload.IntType).?;
                if (payload.signed) {
                    const new = try allocator.create(Type.Payload.IntSigned);
                    new.* = .{ .bits = payload.bits };
                    return Type.initPayload(&new.base);
                } else {
                    const new = try allocator.create(Type.Payload.IntUnsigned);
                    new.* = .{ .bits = payload.bits };
                    return Type.initPayload(&new.base);
                }
            },
            .error_set => {
                const payload = self.cast(Payload.ErrorSet).?;
                const new = try allocator.create(Type.Payload.ErrorSet);
                new.* = .{ .decl = payload.decl };
                return Type.initPayload(&new.base);
            },

            .undef,
            .zero,
            .one,
            .void_value,
            .unreachable_value,
            .empty_array,
            .bool_true,
            .bool_false,
            .null_value,
            .int_u64,
            .int_i64,
            .int_big_positive,
            .int_big_negative,
            .function,
            .variable,
            .ref_val,
            .decl_ref,
            .elem_ptr,
            .bytes,
            .repeated,
            .float_16,
            .float_32,
            .float_64,
            .float_128,
            .enum_literal,
            .@"error",
            .empty_struct_value,
            => unreachable,
        };
    }

    /// Asserts the value is an integer.
    pub fn toBigInt(self: Value, space: *BigIntSpace) BigIntConst {
        switch (self.tag()) {
            .ty,
            .int_type,
            .u8_type,
            .i8_type,
            .u16_type,
            .i16_type,
            .u32_type,
            .i32_type,
            .u64_type,
            .i64_type,
            .usize_type,
            .isize_type,
            .c_short_type,
            .c_ushort_type,
            .c_int_type,
            .c_uint_type,
            .c_long_type,
            .c_ulong_type,
            .c_longlong_type,
            .c_ulonglong_type,
            .c_longdouble_type,
            .f16_type,
            .f32_type,
            .f64_type,
            .f128_type,
            .c_void_type,
            .bool_type,
            .void_type,
            .type_type,
            .anyerror_type,
            .comptime_int_type,
            .comptime_float_type,
            .noreturn_type,
            .null_type,
            .undefined_type,
            .fn_noreturn_no_args_type,
            .fn_void_no_args_type,
            .fn_naked_noreturn_no_args_type,
            .fn_ccc_void_no_args_type,
            .single_const_pointer_to_comptime_int_type,
            .const_slice_u8_type,
            .enum_literal_type,
            .anyframe_type,
            .null_value,
            .function,
            .variable,
            .ref_val,
            .decl_ref,
            .elem_ptr,
            .bytes,
            .repeated,
            .float_16,
            .float_32,
            .float_64,
            .float_128,
            .void_value,
            .unreachable_value,
            .empty_array,
            .enum_literal,
            .error_set,
            .@"error",
            .empty_struct_value,
            => unreachable,

            .undef => unreachable,

            .zero,
            .bool_false,
            => return BigIntMutable.init(&space.limbs, 0).toConst(),

            .one,
            .bool_true,
            => return BigIntMutable.init(&space.limbs, 1).toConst(),

            .int_u64 => return BigIntMutable.init(&space.limbs, self.cast(Payload.Int_u64).?.int).toConst(),
            .int_i64 => return BigIntMutable.init(&space.limbs, self.cast(Payload.Int_i64).?.int).toConst(),
            .int_big_positive => return self.cast(Payload.IntBigPositive).?.asBigInt(),
            .int_big_negative => return self.cast(Payload.IntBigNegative).?.asBigInt(),
        }
    }

    /// Asserts the value is an integer and it fits in a u64
    pub fn toUnsignedInt(self: Value) u64 {
        switch (self.tag()) {
            .ty,
            .int_type,
            .u8_type,
            .i8_type,
            .u16_type,
            .i16_type,
            .u32_type,
            .i32_type,
            .u64_type,
            .i64_type,
            .usize_type,
            .isize_type,
            .c_short_type,
            .c_ushort_type,
            .c_int_type,
            .c_uint_type,
            .c_long_type,
            .c_ulong_type,
            .c_longlong_type,
            .c_ulonglong_type,
            .c_longdouble_type,
            .f16_type,
            .f32_type,
            .f64_type,
            .f128_type,
            .c_void_type,
            .bool_type,
            .void_type,
            .type_type,
            .anyerror_type,
            .comptime_int_type,
            .comptime_float_type,
            .noreturn_type,
            .null_type,
            .undefined_type,
            .fn_noreturn_no_args_type,
            .fn_void_no_args_type,
            .fn_naked_noreturn_no_args_type,
            .fn_ccc_void_no_args_type,
            .single_const_pointer_to_comptime_int_type,
            .const_slice_u8_type,
            .enum_literal_type,
            .anyframe_type,
            .null_value,
            .function,
            .variable,
            .ref_val,
            .decl_ref,
            .elem_ptr,
            .bytes,
            .repeated,
            .float_16,
            .float_32,
            .float_64,
            .float_128,
            .void_value,
            .unreachable_value,
            .empty_array,
            .enum_literal,
            .error_set,
            .@"error",
            .empty_struct_value,
            => unreachable,

            .undef => unreachable,

            .zero,
            .bool_false,
            => return 0,

            .one,
            .bool_true,
            => return 1,

            .int_u64 => return self.cast(Payload.Int_u64).?.int,
            .int_i64 => return @intCast(u64, self.cast(Payload.Int_i64).?.int),
            .int_big_positive => return self.cast(Payload.IntBigPositive).?.asBigInt().to(u64) catch unreachable,
            .int_big_negative => return self.cast(Payload.IntBigNegative).?.asBigInt().to(u64) catch unreachable,
        }
    }

    /// Asserts the value is an integer and it fits in a i64
    pub fn toSignedInt(self: Value) i64 {
        switch (self.tag()) {
            .ty,
            .int_type,
            .u8_type,
            .i8_type,
            .u16_type,
            .i16_type,
            .u32_type,
            .i32_type,
            .u64_type,
            .i64_type,
            .usize_type,
            .isize_type,
            .c_short_type,
            .c_ushort_type,
            .c_int_type,
            .c_uint_type,
            .c_long_type,
            .c_ulong_type,
            .c_longlong_type,
            .c_ulonglong_type,
            .c_longdouble_type,
            .f16_type,
            .f32_type,
            .f64_type,
            .f128_type,
            .c_void_type,
            .bool_type,
            .void_type,
            .type_type,
            .anyerror_type,
            .comptime_int_type,
            .comptime_float_type,
            .noreturn_type,
            .null_type,
            .undefined_type,
            .fn_noreturn_no_args_type,
            .fn_void_no_args_type,
            .fn_naked_noreturn_no_args_type,
            .fn_ccc_void_no_args_type,
            .single_const_pointer_to_comptime_int_type,
            .const_slice_u8_type,
            .enum_literal_type,
            .anyframe_type,
            .null_value,
            .function,
            .variable,
            .ref_val,
            .decl_ref,
            .elem_ptr,
            .bytes,
            .repeated,
            .float_16,
            .float_32,
            .float_64,
            .float_128,
            .void_value,
            .unreachable_value,
            .empty_array,
            .enum_literal,
            .error_set,
            .@"error",
            .empty_struct_value,
            => unreachable,

            .undef => unreachable,

            .zero,
            .bool_false,
            => return 0,

            .one,
            .bool_true,
            => return 1,

            .int_u64 => return @intCast(i64, self.cast(Payload.Int_u64).?.int),
            .int_i64 => return self.cast(Payload.Int_i64).?.int,
            .int_big_positive => return self.cast(Payload.IntBigPositive).?.asBigInt().to(i64) catch unreachable,
            .int_big_negative => return self.cast(Payload.IntBigNegative).?.asBigInt().to(i64) catch unreachable,
        }
    }

    pub fn toBool(self: Value) bool {
        return switch (self.tag()) {
            .bool_true => true,
            .bool_false, .zero => false,
            else => unreachable,
        };
    }

    /// Asserts that the value is a float or an integer.
    pub fn toFloat(self: Value, comptime T: type) T {
        return switch (self.tag()) {
            .float_16 => @panic("TODO soft float"),
            .float_32 => @floatCast(T, self.cast(Payload.Float_32).?.val),
            .float_64 => @floatCast(T, self.cast(Payload.Float_64).?.val),
            .float_128 => @floatCast(T, self.cast(Payload.Float_128).?.val),

            .zero => 0,
            .one => 1,
            .int_u64 => @intToFloat(T, self.cast(Payload.Int_u64).?.int),
            .int_i64 => @intToFloat(T, self.cast(Payload.Int_i64).?.int),

            .int_big_positive, .int_big_negative => @panic("big int to f128"),
            else => unreachable,
        };
    }

    /// Asserts the value is an integer and not undefined.
    /// Returns the number of bits the value requires to represent stored in twos complement form.
    pub fn intBitCountTwosComp(self: Value) usize {
        switch (self.tag()) {
            .ty,
            .int_type,
            .u8_type,
            .i8_type,
            .u16_type,
            .i16_type,
            .u32_type,
            .i32_type,
            .u64_type,
            .i64_type,
            .usize_type,
            .isize_type,
            .c_short_type,
            .c_ushort_type,
            .c_int_type,
            .c_uint_type,
            .c_long_type,
            .c_ulong_type,
            .c_longlong_type,
            .c_ulonglong_type,
            .c_longdouble_type,
            .f16_type,
            .f32_type,
            .f64_type,
            .f128_type,
            .c_void_type,
            .bool_type,
            .void_type,
            .type_type,
            .anyerror_type,
            .comptime_int_type,
            .comptime_float_type,
            .noreturn_type,
            .null_type,
            .undefined_type,
            .fn_noreturn_no_args_type,
            .fn_void_no_args_type,
            .fn_naked_noreturn_no_args_type,
            .fn_ccc_void_no_args_type,
            .single_const_pointer_to_comptime_int_type,
            .const_slice_u8_type,
            .enum_literal_type,
            .anyframe_type,
            .null_value,
            .function,
            .variable,
            .ref_val,
            .decl_ref,
            .elem_ptr,
            .bytes,
            .undef,
            .repeated,
            .float_16,
            .float_32,
            .float_64,
            .float_128,
            .void_value,
            .unreachable_value,
            .empty_array,
            .enum_literal,
            .error_set,
            .@"error",
            .empty_struct_value,
            => unreachable,

            .zero,
            .bool_false,
            => return 0,

            .one,
            .bool_true,
            => return 1,

            .int_u64 => {
                const x = self.cast(Payload.Int_u64).?.int;
                if (x == 0) return 0;
                return @intCast(usize, std.math.log2(x) + 1);
            },
            .int_i64 => {
                @panic("TODO implement i64 intBitCountTwosComp");
            },
            .int_big_positive => return self.cast(Payload.IntBigPositive).?.asBigInt().bitCountTwosComp(),
            .int_big_negative => return self.cast(Payload.IntBigNegative).?.asBigInt().bitCountTwosComp(),
        }
    }

    /// Asserts the value is an integer, and the destination type is ComptimeInt or Int.
    pub fn intFitsInType(self: Value, ty: Type, target: Target) bool {
        switch (self.tag()) {
            .ty,
            .int_type,
            .u8_type,
            .i8_type,
            .u16_type,
            .i16_type,
            .u32_type,
            .i32_type,
            .u64_type,
            .i64_type,
            .usize_type,
            .isize_type,
            .c_short_type,
            .c_ushort_type,
            .c_int_type,
            .c_uint_type,
            .c_long_type,
            .c_ulong_type,
            .c_longlong_type,
            .c_ulonglong_type,
            .c_longdouble_type,
            .f16_type,
            .f32_type,
            .f64_type,
            .f128_type,
            .c_void_type,
            .bool_type,
            .void_type,
            .type_type,
            .anyerror_type,
            .comptime_int_type,
            .comptime_float_type,
            .noreturn_type,
            .null_type,
            .undefined_type,
            .fn_noreturn_no_args_type,
            .fn_void_no_args_type,
            .fn_naked_noreturn_no_args_type,
            .fn_ccc_void_no_args_type,
            .single_const_pointer_to_comptime_int_type,
            .const_slice_u8_type,
            .enum_literal_type,
            .anyframe_type,
            .null_value,
            .function,
            .variable,
            .ref_val,
            .decl_ref,
            .elem_ptr,
            .bytes,
            .repeated,
            .float_16,
            .float_32,
            .float_64,
            .float_128,
            .void_value,
            .unreachable_value,
            .empty_array,
            .enum_literal,
            .error_set,
            .@"error",
            .empty_struct_value,
            => unreachable,

            .zero,
            .undef,
            .bool_false,
            => return true,

            .one,
            .bool_true,
            => {
                const info = ty.intInfo(target);
                return switch (info.signedness) {
                    .signed => info.bits >= 2,
                    .unsigned => info.bits >= 1,
                };
            },

            .int_u64 => switch (ty.zigTypeTag()) {
                .Int => {
                    const x = self.cast(Payload.Int_u64).?.int;
                    if (x == 0) return true;
                    const info = ty.intInfo(target);
                    const needed_bits = std.math.log2(x) + 1 + @boolToInt(info.signedness == .signed);
                    return info.bits >= needed_bits;
                },
                .ComptimeInt => return true,
                else => unreachable,
            },
            .int_i64 => switch (ty.zigTypeTag()) {
                .Int => {
                    const x = self.cast(Payload.Int_i64).?.int;
                    if (x == 0) return true;
                    const info = ty.intInfo(target);
                    if (info.signedness == .unsigned and x < 0)
                        return false;
                    @panic("TODO implement i64 intFitsInType");
                },
                .ComptimeInt => return true,
                else => unreachable,
            },
            .int_big_positive => switch (ty.zigTypeTag()) {
                .Int => {
                    const info = ty.intInfo(target);
                    return self.cast(Payload.IntBigPositive).?.asBigInt().fitsInTwosComp(info.signedness, info.bits);
                },
                .ComptimeInt => return true,
                else => unreachable,
            },
            .int_big_negative => switch (ty.zigTypeTag()) {
                .Int => {
                    const info = ty.intInfo(target);
                    return self.cast(Payload.IntBigNegative).?.asBigInt().fitsInTwosComp(info.signedness, info.bits);
                },
                .ComptimeInt => return true,
                else => unreachable,
            },
        }
    }

    /// Converts an integer or a float to a float.
    /// Returns `error.Overflow` if the value does not fit in the new type.
    pub fn floatCast(self: Value, allocator: *Allocator, ty: Type, target: Target) !Value {
        const dest_bit_count = switch (ty.tag()) {
            .comptime_float => 128,
            else => ty.floatBits(target),
        };
        switch (dest_bit_count) {
            16, 32, 64, 128 => {},
            else => std.debug.panic("TODO float cast bit count {}\n", .{dest_bit_count}),
        }
        if (ty.isInt()) {
            @panic("TODO int to float");
        }

        switch (dest_bit_count) {
            16 => {
                @panic("TODO soft float");
                // var res_payload = Value.Payload.Float_16{.val = self.toFloat(f16)};
                // if (!self.eql(Value.initPayload(&res_payload.base)))
                //     return error.Overflow;
                // return Value.initPayload(&res_payload.base).copy(allocator);
            },
            32 => {
                var res_payload = Value.Payload.Float_32{ .val = self.toFloat(f32) };
                if (!self.eql(Value.initPayload(&res_payload.base)))
                    return error.Overflow;
                return Value.initPayload(&res_payload.base).copy(allocator);
            },
            64 => {
                var res_payload = Value.Payload.Float_64{ .val = self.toFloat(f64) };
                if (!self.eql(Value.initPayload(&res_payload.base)))
                    return error.Overflow;
                return Value.initPayload(&res_payload.base).copy(allocator);
            },
            128 => {
                const float_payload = try allocator.create(Value.Payload.Float_128);
                float_payload.* = .{ .val = self.toFloat(f128) };
                return Value.initPayload(&float_payload.base);
            },
            else => unreachable,
        }
    }

    /// Asserts the value is a float
    pub fn floatHasFraction(self: Value) bool {
        return switch (self.tag()) {
            .ty,
            .int_type,
            .u8_type,
            .i8_type,
            .u16_type,
            .i16_type,
            .u32_type,
            .i32_type,
            .u64_type,
            .i64_type,
            .usize_type,
            .isize_type,
            .c_short_type,
            .c_ushort_type,
            .c_int_type,
            .c_uint_type,
            .c_long_type,
            .c_ulong_type,
            .c_longlong_type,
            .c_ulonglong_type,
            .c_longdouble_type,
            .f16_type,
            .f32_type,
            .f64_type,
            .f128_type,
            .c_void_type,
            .bool_type,
            .void_type,
            .type_type,
            .anyerror_type,
            .comptime_int_type,
            .comptime_float_type,
            .noreturn_type,
            .null_type,
            .undefined_type,
            .fn_noreturn_no_args_type,
            .fn_void_no_args_type,
            .fn_naked_noreturn_no_args_type,
            .fn_ccc_void_no_args_type,
            .single_const_pointer_to_comptime_int_type,
            .const_slice_u8_type,
            .enum_literal_type,
            .anyframe_type,
            .bool_true,
            .bool_false,
            .null_value,
            .function,
            .variable,
            .ref_val,
            .decl_ref,
            .elem_ptr,
            .bytes,
            .repeated,
            .undef,
            .int_u64,
            .int_i64,
            .int_big_positive,
            .int_big_negative,
            .empty_array,
            .void_value,
            .unreachable_value,
            .enum_literal,
            .error_set,
            .@"error",
            .empty_struct_value,
            => unreachable,

            .zero,
            .one,
            => false,

            .float_16 => @rem(self.cast(Payload.Float_16).?.val, 1) != 0,
            .float_32 => @rem(self.cast(Payload.Float_32).?.val, 1) != 0,
            .float_64 => @rem(self.cast(Payload.Float_64).?.val, 1) != 0,
            // .float_128 => @rem(self.cast(Payload.Float_128).?.val, 1) != 0,
            .float_128 => @panic("TODO lld: error: undefined symbol: fmodl"),
        };
    }

    pub fn orderAgainstZero(lhs: Value) std.math.Order {
        return switch (lhs.tag()) {
            .ty,
            .int_type,
            .u8_type,
            .i8_type,
            .u16_type,
            .i16_type,
            .u32_type,
            .i32_type,
            .u64_type,
            .i64_type,
            .usize_type,
            .isize_type,
            .c_short_type,
            .c_ushort_type,
            .c_int_type,
            .c_uint_type,
            .c_long_type,
            .c_ulong_type,
            .c_longlong_type,
            .c_ulonglong_type,
            .c_longdouble_type,
            .f16_type,
            .f32_type,
            .f64_type,
            .f128_type,
            .c_void_type,
            .bool_type,
            .void_type,
            .type_type,
            .anyerror_type,
            .comptime_int_type,
            .comptime_float_type,
            .noreturn_type,
            .null_type,
            .undefined_type,
            .fn_noreturn_no_args_type,
            .fn_void_no_args_type,
            .fn_naked_noreturn_no_args_type,
            .fn_ccc_void_no_args_type,
            .single_const_pointer_to_comptime_int_type,
            .const_slice_u8_type,
            .enum_literal_type,
            .anyframe_type,
            .null_value,
            .function,
            .variable,
            .ref_val,
            .decl_ref,
            .elem_ptr,
            .bytes,
            .repeated,
            .undef,
            .void_value,
            .unreachable_value,
            .empty_array,
            .enum_literal,
            .error_set,
            .@"error",
            .empty_struct_value,
            => unreachable,

            .zero,
            .bool_false,
            => .eq,

            .one,
            .bool_true,
            => .gt,

            .int_u64 => std.math.order(lhs.cast(Payload.Int_u64).?.int, 0),
            .int_i64 => std.math.order(lhs.cast(Payload.Int_i64).?.int, 0),
            .int_big_positive => lhs.cast(Payload.IntBigPositive).?.asBigInt().orderAgainstScalar(0),
            .int_big_negative => lhs.cast(Payload.IntBigNegative).?.asBigInt().orderAgainstScalar(0),

            .float_16 => std.math.order(lhs.cast(Payload.Float_16).?.val, 0),
            .float_32 => std.math.order(lhs.cast(Payload.Float_32).?.val, 0),
            .float_64 => std.math.order(lhs.cast(Payload.Float_64).?.val, 0),
            .float_128 => std.math.order(lhs.cast(Payload.Float_128).?.val, 0),
        };
    }

    /// Asserts the value is comparable.
    pub fn order(lhs: Value, rhs: Value) std.math.Order {
        const lhs_tag = lhs.tag();
        const rhs_tag = rhs.tag();
        const lhs_is_zero = lhs_tag == .zero;
        const rhs_is_zero = rhs_tag == .zero;
        if (lhs_is_zero) return rhs.orderAgainstZero().invert();
        if (rhs_is_zero) return lhs.orderAgainstZero();

        const lhs_float = lhs.isFloat();
        const rhs_float = rhs.isFloat();
        if (lhs_float and rhs_float) {
            if (lhs_tag == rhs_tag) {
                return switch (lhs.tag()) {
                    .float_16 => return std.math.order(lhs.cast(Payload.Float_16).?.val, rhs.cast(Payload.Float_16).?.val),
                    .float_32 => return std.math.order(lhs.cast(Payload.Float_32).?.val, rhs.cast(Payload.Float_32).?.val),
                    .float_64 => return std.math.order(lhs.cast(Payload.Float_64).?.val, rhs.cast(Payload.Float_64).?.val),
                    .float_128 => return std.math.order(lhs.cast(Payload.Float_128).?.val, rhs.cast(Payload.Float_128).?.val),
                    else => unreachable,
                };
            }
        }
        if (lhs_float or rhs_float) {
            const lhs_f128 = lhs.toFloat(f128);
            const rhs_f128 = rhs.toFloat(f128);
            return std.math.order(lhs_f128, rhs_f128);
        }

        var lhs_bigint_space: BigIntSpace = undefined;
        var rhs_bigint_space: BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_bigint_space);
        const rhs_bigint = rhs.toBigInt(&rhs_bigint_space);
        return lhs_bigint.order(rhs_bigint);
    }

    /// Asserts the value is comparable.
    pub fn compare(lhs: Value, op: std.math.CompareOperator, rhs: Value) bool {
        return order(lhs, rhs).compare(op);
    }

    /// Asserts the value is comparable.
    pub fn compareWithZero(lhs: Value, op: std.math.CompareOperator) bool {
        return orderAgainstZero(lhs).compare(op);
    }

    pub fn eql(a: Value, b: Value) bool {
        if (a.tag() == b.tag()) {
            if (a.tag() == .void_value or a.tag() == .null_value) {
                return true;
            } else if (a.tag() == .enum_literal) {
                const a_name = @fieldParentPtr(Payload.Bytes, "base", a.ptr_otherwise).data;
                const b_name = @fieldParentPtr(Payload.Bytes, "base", b.ptr_otherwise).data;
                return std.mem.eql(u8, a_name, b_name);
            }
        }
        if (a.isType() and b.isType()) {
            // 128 bytes should be enough to hold both types
            var buf: [128]u8 = undefined;
            var fib = std.heap.FixedBufferAllocator.init(&buf);
            const a_type = a.toType(&fib.allocator) catch unreachable;
            const b_type = b.toType(&fib.allocator) catch unreachable;
            return a_type.eql(b_type);
        }
        return compare(a, .eq, b);
    }

    pub fn hash(self: Value) u64 {
        var hasher = std.hash.Wyhash.init(0);

        switch (self.tag()) {
            .u8_type,
            .i8_type,
            .u16_type,
            .i16_type,
            .u32_type,
            .i32_type,
            .u64_type,
            .i64_type,
            .usize_type,
            .isize_type,
            .c_short_type,
            .c_ushort_type,
            .c_int_type,
            .c_uint_type,
            .c_long_type,
            .c_ulong_type,
            .c_longlong_type,
            .c_ulonglong_type,
            .c_longdouble_type,
            .f16_type,
            .f32_type,
            .f64_type,
            .f128_type,
            .c_void_type,
            .bool_type,
            .void_type,
            .type_type,
            .anyerror_type,
            .comptime_int_type,
            .comptime_float_type,
            .noreturn_type,
            .null_type,
            .undefined_type,
            .fn_noreturn_no_args_type,
            .fn_void_no_args_type,
            .fn_naked_noreturn_no_args_type,
            .fn_ccc_void_no_args_type,
            .single_const_pointer_to_comptime_int_type,
            .const_slice_u8_type,
            .enum_literal_type,
            .anyframe_type,
            .ty,
            => {
                // Directly return Type.hash, toType can only fail for .int_type and .error_set.
                var allocator = std.heap.FixedBufferAllocator.init(&[_]u8{});
                return (self.toType(&allocator.allocator) catch unreachable).hash();
            },
            .error_set => {
                // Payload.decl should be same for all instances of the type.
                const payload = @fieldParentPtr(Payload.ErrorSet, "base", self.ptr_otherwise);
                std.hash.autoHash(&hasher, payload.decl);
            },
            .int_type => {
                const payload = self.cast(Payload.IntType).?;
                if (payload.signed) {
                    var new = Type.Payload.IntSigned{ .bits = payload.bits };
                    return Type.initPayload(&new.base).hash();
                } else {
                    var new = Type.Payload.IntUnsigned{ .bits = payload.bits };
                    return Type.initPayload(&new.base).hash();
                }
            },

            .empty_struct_value,
            .empty_array,
            => {},

            .undef,
            .null_value,
            .void_value,
            .unreachable_value,
            => std.hash.autoHash(&hasher, self.tag()),

            .zero, .bool_false => std.hash.autoHash(&hasher, @as(u64, 0)),
            .one, .bool_true => std.hash.autoHash(&hasher, @as(u64, 1)),

            .float_16, .float_32, .float_64, .float_128 => {},
            .enum_literal, .bytes => {
                const payload = @fieldParentPtr(Payload.Bytes, "base", self.ptr_otherwise);
                hasher.update(payload.data);
            },
            .int_u64 => {
                const payload = @fieldParentPtr(Payload.Int_u64, "base", self.ptr_otherwise);
                std.hash.autoHash(&hasher, payload.int);
            },
            .int_i64 => {
                const payload = @fieldParentPtr(Payload.Int_i64, "base", self.ptr_otherwise);
                std.hash.autoHash(&hasher, payload.int);
            },
            .repeated => {
                const payload = @fieldParentPtr(Payload.Repeated, "base", self.ptr_otherwise);
                std.hash.autoHash(&hasher, payload.val.hash());
            },
            .ref_val => {
                const payload = @fieldParentPtr(Payload.RefVal, "base", self.ptr_otherwise);
                std.hash.autoHash(&hasher, payload.val.hash());
            },
            .int_big_positive, .int_big_negative => {
                var space: BigIntSpace = undefined;
                const big = self.toBigInt(&space);
                if (big.limbs.len == 1) {
                    // handle like {u,i}64 to ensure same hash as with Int{i,u}64
                    if (big.positive) {
                        std.hash.autoHash(&hasher, @as(u64, big.limbs[0]));
                    } else {
                        std.hash.autoHash(&hasher, @as(u64, @bitCast(usize, -@bitCast(isize, big.limbs[0]))));
                    }
                } else {
                    std.hash.autoHash(&hasher, big.positive);
                    for (big.limbs) |limb| {
                        std.hash.autoHash(&hasher, limb);
                    }
                }
            },
            .elem_ptr => {
                const payload = @fieldParentPtr(Payload.ElemPtr, "base", self.ptr_otherwise);
                std.hash.autoHash(&hasher, payload.array_ptr.hash());
                std.hash.autoHash(&hasher, payload.index);
            },
            .decl_ref => {
                const payload = @fieldParentPtr(Payload.DeclRef, "base", self.ptr_otherwise);
                std.hash.autoHash(&hasher, payload.decl);
            },
            .function => {
                const payload = @fieldParentPtr(Payload.Function, "base", self.ptr_otherwise);
                std.hash.autoHash(&hasher, payload.func);
            },
            .variable => {
                const payload = @fieldParentPtr(Payload.Variable, "base", self.ptr_otherwise);
                std.hash.autoHash(&hasher, payload.variable);
            },
            .@"error" => {
                const payload = @fieldParentPtr(Payload.Error, "base", self.ptr_otherwise);
                hasher.update(payload.name);
                std.hash.autoHash(&hasher, payload.value);
            },
        }
        return hasher.final();
    }

    /// Asserts the value is a pointer and dereferences it.
    /// Returns error.AnalysisFail if the pointer points to a Decl that failed semantic analysis.
    pub fn pointerDeref(self: Value, allocator: *Allocator) error{ AnalysisFail, OutOfMemory }!Value {
        return switch (self.tag()) {
            .ty,
            .int_type,
            .u8_type,
            .i8_type,
            .u16_type,
            .i16_type,
            .u32_type,
            .i32_type,
            .u64_type,
            .i64_type,
            .usize_type,
            .isize_type,
            .c_short_type,
            .c_ushort_type,
            .c_int_type,
            .c_uint_type,
            .c_long_type,
            .c_ulong_type,
            .c_longlong_type,
            .c_ulonglong_type,
            .c_longdouble_type,
            .f16_type,
            .f32_type,
            .f64_type,
            .f128_type,
            .c_void_type,
            .bool_type,
            .void_type,
            .type_type,
            .anyerror_type,
            .comptime_int_type,
            .comptime_float_type,
            .noreturn_type,
            .null_type,
            .undefined_type,
            .fn_noreturn_no_args_type,
            .fn_void_no_args_type,
            .fn_naked_noreturn_no_args_type,
            .fn_ccc_void_no_args_type,
            .single_const_pointer_to_comptime_int_type,
            .const_slice_u8_type,
            .enum_literal_type,
            .anyframe_type,
            .zero,
            .one,
            .bool_true,
            .bool_false,
            .null_value,
            .function,
            .variable,
            .int_u64,
            .int_i64,
            .int_big_positive,
            .int_big_negative,
            .bytes,
            .undef,
            .repeated,
            .float_16,
            .float_32,
            .float_64,
            .float_128,
            .void_value,
            .unreachable_value,
            .empty_array,
            .enum_literal,
            .error_set,
            .@"error",
            .empty_struct_value,
            => unreachable,

            .ref_val => self.cast(Payload.RefVal).?.val,
            .decl_ref => self.cast(Payload.DeclRef).?.decl.value(),
            .elem_ptr => {
                const elem_ptr = self.cast(Payload.ElemPtr).?;
                const array_val = try elem_ptr.array_ptr.pointerDeref(allocator);
                return array_val.elemValue(allocator, elem_ptr.index);
            },
        };
    }

    /// Asserts the value is a single-item pointer to an array, or an array,
    /// or an unknown-length pointer, and returns the element value at the index.
    pub fn elemValue(self: Value, allocator: *Allocator, index: usize) error{OutOfMemory}!Value {
        switch (self.tag()) {
            .ty,
            .int_type,
            .u8_type,
            .i8_type,
            .u16_type,
            .i16_type,
            .u32_type,
            .i32_type,
            .u64_type,
            .i64_type,
            .usize_type,
            .isize_type,
            .c_short_type,
            .c_ushort_type,
            .c_int_type,
            .c_uint_type,
            .c_long_type,
            .c_ulong_type,
            .c_longlong_type,
            .c_ulonglong_type,
            .c_longdouble_type,
            .f16_type,
            .f32_type,
            .f64_type,
            .f128_type,
            .c_void_type,
            .bool_type,
            .void_type,
            .type_type,
            .anyerror_type,
            .comptime_int_type,
            .comptime_float_type,
            .noreturn_type,
            .null_type,
            .undefined_type,
            .fn_noreturn_no_args_type,
            .fn_void_no_args_type,
            .fn_naked_noreturn_no_args_type,
            .fn_ccc_void_no_args_type,
            .single_const_pointer_to_comptime_int_type,
            .const_slice_u8_type,
            .enum_literal_type,
            .anyframe_type,
            .zero,
            .one,
            .bool_true,
            .bool_false,
            .null_value,
            .function,
            .variable,
            .int_u64,
            .int_i64,
            .int_big_positive,
            .int_big_negative,
            .undef,
            .elem_ptr,
            .ref_val,
            .decl_ref,
            .float_16,
            .float_32,
            .float_64,
            .float_128,
            .void_value,
            .unreachable_value,
            .enum_literal,
            .error_set,
            .@"error",
            .empty_struct_value,
            => unreachable,

            .empty_array => unreachable, // out of bounds array index

            .bytes => {
                const int_payload = try allocator.create(Payload.Int_u64);
                int_payload.* = .{ .int = self.cast(Payload.Bytes).?.data[index] };
                return Value.initPayload(&int_payload.base);
            },

            // No matter the index; all the elements are the same!
            .repeated => return self.cast(Payload.Repeated).?.val,
        }
    }

    /// Returns a pointer to the element value at the index.
    pub fn elemPtr(self: Value, allocator: *Allocator, index: usize) !Value {
        const payload = try allocator.create(Payload.ElemPtr);
        if (self.cast(Payload.ElemPtr)) |elem_ptr| {
            payload.* = .{ .array_ptr = elem_ptr.array_ptr, .index = elem_ptr.index + index };
        } else {
            payload.* = .{ .array_ptr = self, .index = index };
        }
        return Value.initPayload(&payload.base);
    }

    pub fn isUndef(self: Value) bool {
        return self.tag() == .undef;
    }

    /// Valid for all types. Asserts the value is not undefined and not unreachable.
    pub fn isNull(self: Value) bool {
        return switch (self.tag()) {
            .ty,
            .int_type,
            .u8_type,
            .i8_type,
            .u16_type,
            .i16_type,
            .u32_type,
            .i32_type,
            .u64_type,
            .i64_type,
            .usize_type,
            .isize_type,
            .c_short_type,
            .c_ushort_type,
            .c_int_type,
            .c_uint_type,
            .c_long_type,
            .c_ulong_type,
            .c_longlong_type,
            .c_ulonglong_type,
            .c_longdouble_type,
            .f16_type,
            .f32_type,
            .f64_type,
            .f128_type,
            .c_void_type,
            .bool_type,
            .void_type,
            .type_type,
            .anyerror_type,
            .comptime_int_type,
            .comptime_float_type,
            .noreturn_type,
            .null_type,
            .undefined_type,
            .fn_noreturn_no_args_type,
            .fn_void_no_args_type,
            .fn_naked_noreturn_no_args_type,
            .fn_ccc_void_no_args_type,
            .single_const_pointer_to_comptime_int_type,
            .const_slice_u8_type,
            .enum_literal_type,
            .anyframe_type,
            .zero,
            .one,
            .empty_array,
            .bool_true,
            .bool_false,
            .function,
            .variable,
            .int_u64,
            .int_i64,
            .int_big_positive,
            .int_big_negative,
            .ref_val,
            .decl_ref,
            .elem_ptr,
            .bytes,
            .repeated,
            .float_16,
            .float_32,
            .float_64,
            .float_128,
            .void_value,
            .enum_literal,
            .error_set,
            .@"error",
            .empty_struct_value,
            => false,

            .undef => unreachable,
            .unreachable_value => unreachable,
            .null_value => true,
        };
    }

    /// Valid for all types. Asserts the value is not undefined.
    pub fn isFloat(self: Value) bool {
        return switch (self.tag()) {
            .undef => unreachable,

            .float_16,
            .float_32,
            .float_64,
            .float_128,
            => true,
            else => false,
        };
    }

    /// Valid for all types. Asserts the value is not undefined.
    pub fn isType(self: Value) bool {
        return switch (self.tag()) {
            .ty,
            .int_type,
            .u8_type,
            .i8_type,
            .u16_type,
            .i16_type,
            .u32_type,
            .i32_type,
            .u64_type,
            .i64_type,
            .usize_type,
            .isize_type,
            .c_short_type,
            .c_ushort_type,
            .c_int_type,
            .c_uint_type,
            .c_long_type,
            .c_ulong_type,
            .c_longlong_type,
            .c_ulonglong_type,
            .c_longdouble_type,
            .f16_type,
            .f32_type,
            .f64_type,
            .f128_type,
            .c_void_type,
            .bool_type,
            .void_type,
            .type_type,
            .anyerror_type,
            .comptime_int_type,
            .comptime_float_type,
            .noreturn_type,
            .null_type,
            .undefined_type,
            .fn_noreturn_no_args_type,
            .fn_void_no_args_type,
            .fn_naked_noreturn_no_args_type,
            .fn_ccc_void_no_args_type,
            .single_const_pointer_to_comptime_int_type,
            .const_slice_u8_type,
            .enum_literal_type,
            .anyframe_type,
            .error_set,
            => true,

            .zero,
            .one,
            .empty_array,
            .bool_true,
            .bool_false,
            .function,
            .variable,
            .int_u64,
            .int_i64,
            .int_big_positive,
            .int_big_negative,
            .ref_val,
            .decl_ref,
            .elem_ptr,
            .bytes,
            .repeated,
            .float_16,
            .float_32,
            .float_64,
            .float_128,
            .void_value,
            .enum_literal,
            .@"error",
            .empty_struct_value,
            .null_value,
            => false,

            .undef => unreachable,
            .unreachable_value => unreachable,
        };
    }

    /// This type is not copyable since it may contain pointers to its inner data.
    pub const Payload = struct {
        tag: Tag,

        pub const Int_u64 = struct {
            base: Payload = Payload{ .tag = .int_u64 },
            int: u64,
        };

        pub const Int_i64 = struct {
            base: Payload = Payload{ .tag = .int_i64 },
            int: i64,
        };

        pub const IntBigPositive = struct {
            base: Payload = Payload{ .tag = .int_big_positive },
            limbs: []const std.math.big.Limb,

            pub fn asBigInt(self: IntBigPositive) BigIntConst {
                return BigIntConst{ .limbs = self.limbs, .positive = true };
            }
        };

        pub const IntBigNegative = struct {
            base: Payload = Payload{ .tag = .int_big_negative },
            limbs: []const std.math.big.Limb,

            pub fn asBigInt(self: IntBigNegative) BigIntConst {
                return BigIntConst{ .limbs = self.limbs, .positive = false };
            }
        };

        pub const Function = struct {
            base: Payload = Payload{ .tag = .function },
            func: *Module.Fn,
        };

        pub const Variable = struct {
            base: Payload = Payload{ .tag = .variable },
            variable: *Module.Var,
        };

        pub const ArraySentinel0_u8_Type = struct {
            base: Payload = Payload{ .tag = .array_sentinel_0_u8_type },
            len: u64,
        };

        /// Represents a pointer to another immutable value.
        pub const RefVal = struct {
            base: Payload = Payload{ .tag = .ref_val },
            val: Value,
        };

        /// Represents a pointer to a decl, not the value of the decl.
        pub const DeclRef = struct {
            base: Payload = Payload{ .tag = .decl_ref },
            decl: *Module.Decl,
        };

        pub const ElemPtr = struct {
            base: Payload = Payload{ .tag = .elem_ptr },
            array_ptr: Value,
            index: usize,
        };

        pub const Bytes = struct {
            base: Payload = Payload{ .tag = .bytes },
            data: []const u8,
        };

        pub const Ty = struct {
            base: Payload = Payload{ .tag = .ty },
            ty: Type,
        };

        pub const IntType = struct {
            base: Payload = Payload{ .tag = .int_type },
            bits: u16,
            signed: bool,
        };

        pub const Repeated = struct {
            base: Payload = Payload{ .tag = .ty },
            /// This value is repeated some number of times. The amount of times to repeat
            /// is stored externally.
            val: Value,
        };

        pub const Float_16 = struct {
            base: Payload = .{ .tag = .float_16 },
            val: f16,
        };

        pub const Float_32 = struct {
            base: Payload = .{ .tag = .float_32 },
            val: f32,
        };

        pub const Float_64 = struct {
            base: Payload = .{ .tag = .float_64 },
            val: f64,
        };

        pub const Float_128 = struct {
            base: Payload = .{ .tag = .float_128 },
            val: f128,
        };

        pub const ErrorSet = struct {
            base: Payload = .{ .tag = .error_set },

            // TODO revisit this when we have the concept of the error tag type
            fields: std.StringHashMapUnmanaged(u16),
            decl: *Module.Decl,
        };

        pub const Error = struct {
            base: Payload = .{ .tag = .@"error" },

            // TODO revisit this when we have the concept of the error tag type
            /// `name` is owned by `Module` and will be valid for the entire
            /// duration of the compilation.
            name: []const u8,
            value: u16,
        };
    };

    /// Big enough to fit any non-BigInt value
    pub const BigIntSpace = struct {
        /// The +1 is headroom so that operations such as incrementing once or decrementing once
        /// are possible without using an allocator.
        limbs: [(@sizeOf(u64) / @sizeOf(std.math.big.Limb)) + 1]std.math.big.Limb,
    };
};

test "hash same value different representation" {
    const zero_1 = Value.initTag(.zero);
    var payload_1 = Value.Payload.Int_u64{ .int = 0 };
    const zero_2 = Value.initPayload(&payload_1.base);
    std.testing.expectEqual(zero_1.hash(), zero_2.hash());

    var payload_2 = Value.Payload.Int_i64{ .int = 0 };
    const zero_3 = Value.initPayload(&payload_2.base);
    std.testing.expectEqual(zero_2.hash(), zero_3.hash());

    var payload_3 = Value.Payload.IntBigNegative{ .limbs = &[_]std.math.big.Limb{0} };
    const zero_4 = Value.initPayload(&payload_3.base);
    std.testing.expectEqual(zero_3.hash(), zero_4.hash());
}
