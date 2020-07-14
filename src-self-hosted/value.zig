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

        undef,
        zero,
        the_one_possible_value, // when the type only has one possible value
        null_value,
        bool_true,
        bool_false, // See last_no_payload_tag below.
        // After this, the tag requires a payload.

        ty,
        int_u64,
        int_i64,
        int_big_positive,
        int_big_negative,
        function,
        ref_val,
        decl_ref,
        elem_ptr,
        bytes,
        repeated, // the value is a value repeated some number of times

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
            .undef,
            .zero,
            .the_one_possible_value,
            .null_value,
            .bool_true,
            .bool_false,
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
            .int_u64 => return self.copyPayloadShallow(allocator, Payload.Int_u64),
            .int_i64 => return self.copyPayloadShallow(allocator, Payload.Int_i64),
            .int_big_positive => {
                @panic("TODO implement copying of big ints");
            },
            .int_big_negative => {
                @panic("TODO implement copying of big ints");
            },
            .function => return self.copyPayloadShallow(allocator, Payload.Function),
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
            .null_type => return out_stream.writeAll("@TypeOf(null)"),
            .undefined_type => return out_stream.writeAll("@TypeOf(undefined)"),
            .fn_noreturn_no_args_type => return out_stream.writeAll("fn() noreturn"),
            .fn_void_no_args_type => return out_stream.writeAll("fn() void"),
            .fn_naked_noreturn_no_args_type => return out_stream.writeAll("fn() callconv(.Naked) noreturn"),
            .fn_ccc_void_no_args_type => return out_stream.writeAll("fn() callconv(.C) void"),
            .single_const_pointer_to_comptime_int_type => return out_stream.writeAll("*const comptime_int"),
            .const_slice_u8_type => return out_stream.writeAll("[]const u8"),

            .null_value => return out_stream.writeAll("null"),
            .undef => return out_stream.writeAll("undefined"),
            .zero => return out_stream.writeAll("0"),
            .the_one_possible_value => return out_stream.writeAll("(one possible value)"),
            .bool_true => return out_stream.writeAll("true"),
            .bool_false => return out_stream.writeAll("false"),
            .ty => return val.cast(Payload.Ty).?.ty.format("", options, out_stream),
            .int_u64 => return std.fmt.formatIntValue(val.cast(Payload.Int_u64).?.int, "", options, out_stream),
            .int_i64 => return std.fmt.formatIntValue(val.cast(Payload.Int_i64).?.int, "", options, out_stream),
            .int_big_positive => return out_stream.print("{}", .{val.cast(Payload.IntBigPositive).?.asBigInt()}),
            .int_big_negative => return out_stream.print("{}", .{val.cast(Payload.IntBigNegative).?.asBigInt()}),
            .function => return out_stream.writeAll("(function)"),
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
            .bytes => return std.zig.renderStringLiteral(self.cast(Payload.Bytes).?.data, out_stream),
            .repeated => {
                try out_stream.writeAll("(repeated) ");
                val = val.cast(Payload.Repeated).?.val;
            },
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
    pub fn toType(self: Value) Type {
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

            .undef,
            .zero,
            .the_one_possible_value,
            .bool_true,
            .bool_false,
            .null_value,
            .int_u64,
            .int_i64,
            .int_big_positive,
            .int_big_negative,
            .function,
            .ref_val,
            .decl_ref,
            .elem_ptr,
            .bytes,
            .repeated,
            => unreachable,
        };
    }

    /// Asserts the value is an integer.
    pub fn toBigInt(self: Value, space: *BigIntSpace) BigIntConst {
        switch (self.tag()) {
            .ty,
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
            .null_value,
            .function,
            .ref_val,
            .decl_ref,
            .elem_ptr,
            .bytes,
            .undef,
            .repeated,
            => unreachable,

            .the_one_possible_value, // An integer with one possible value is always zero.
            .zero,
            .bool_false,
            => return BigIntMutable.init(&space.limbs, 0).toConst(),

            .bool_true => return BigIntMutable.init(&space.limbs, 1).toConst(),

            .int_u64 => return BigIntMutable.init(&space.limbs, self.cast(Payload.Int_u64).?.int).toConst(),
            .int_i64 => return BigIntMutable.init(&space.limbs, self.cast(Payload.Int_i64).?.int).toConst(),
            .int_big_positive => return self.cast(Payload.IntBigPositive).?.asBigInt(),
            .int_big_negative => return self.cast(Payload.IntBigPositive).?.asBigInt(),
        }
    }

    /// Asserts the value is an integer and it fits in a u64
    pub fn toUnsignedInt(self: Value) u64 {
        switch (self.tag()) {
            .ty,
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
            .null_value,
            .function,
            .ref_val,
            .decl_ref,
            .elem_ptr,
            .bytes,
            .undef,
            .repeated,
            => unreachable,

            .zero,
            .the_one_possible_value, // an integer with one possible value is always zero
            .bool_false,
            => return 0,

            .bool_true => return 1,

            .int_u64 => return self.cast(Payload.Int_u64).?.int,
            .int_i64 => return @intCast(u64, self.cast(Payload.Int_u64).?.int),
            .int_big_positive => return self.cast(Payload.IntBigPositive).?.asBigInt().to(u64) catch unreachable,
            .int_big_negative => return self.cast(Payload.IntBigNegative).?.asBigInt().to(u64) catch unreachable,
        }
    }

    /// Asserts the value is an integer and not undefined.
    /// Returns the number of bits the value requires to represent stored in twos complement form.
    pub fn intBitCountTwosComp(self: Value) usize {
        switch (self.tag()) {
            .ty,
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
            .null_value,
            .function,
            .ref_val,
            .decl_ref,
            .elem_ptr,
            .bytes,
            .undef,
            .repeated,
            => unreachable,

            .the_one_possible_value, // an integer with one possible value is always zero
            .zero,
            .bool_false,
            => return 0,

            .bool_true => return 1,

            .int_u64 => {
                const x = self.cast(Payload.Int_u64).?.int;
                if (x == 0) return 0;
                return std.math.log2(x) + 1;
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
            .null_value,
            .function,
            .ref_val,
            .decl_ref,
            .elem_ptr,
            .bytes,
            .repeated,
            => unreachable,

            .zero,
            .undef,
            .the_one_possible_value, // an integer with one possible value is always zero
            .bool_false,
            => return true,

            .bool_true => {
                const info = ty.intInfo(target);
                if (info.signed) {
                    return info.bits >= 2;
                } else {
                    return info.bits >= 1;
                }
            },

            .int_u64 => switch (ty.zigTypeTag()) {
                .Int => {
                    const x = self.cast(Payload.Int_u64).?.int;
                    if (x == 0) return true;
                    const info = ty.intInfo(target);
                    const needed_bits = std.math.log2(x) + 1 + @boolToInt(info.signed);
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
                    if (!info.signed and x < 0)
                        return false;
                    @panic("TODO implement i64 intFitsInType");
                },
                .ComptimeInt => return true,
                else => unreachable,
            },
            .int_big_positive => switch (ty.zigTypeTag()) {
                .Int => {
                    const info = ty.intInfo(target);
                    return self.cast(Payload.IntBigPositive).?.asBigInt().fitsInTwosComp(info.signed, info.bits);
                },
                .ComptimeInt => return true,
                else => unreachable,
            },
            .int_big_negative => switch (ty.zigTypeTag()) {
                .Int => {
                    const info = ty.intInfo(target);
                    return self.cast(Payload.IntBigNegative).?.asBigInt().fitsInTwosComp(info.signed, info.bits);
                },
                .ComptimeInt => return true,
                else => unreachable,
            },
        }
    }

    /// Asserts the value is a float
    pub fn floatHasFraction(self: Value) bool {
        return switch (self.tag()) {
            .ty,
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
            .bool_true,
            .bool_false,
            .null_value,
            .function,
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
            .the_one_possible_value,
            => unreachable,

            .zero => false,
        };
    }

    pub fn orderAgainstZero(lhs: Value) std.math.Order {
        switch (lhs.tag()) {
            .ty,
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
            .null_value,
            .function,
            .ref_val,
            .decl_ref,
            .elem_ptr,
            .bytes,
            .repeated,
            .undef,
            => unreachable,

            .zero,
            .the_one_possible_value, // an integer with one possible value is always zero
            .bool_false,
            => return .eq,

            .bool_true => return .gt,

            .int_u64 => return std.math.order(lhs.cast(Payload.Int_u64).?.int, 0),
            .int_i64 => return std.math.order(lhs.cast(Payload.Int_i64).?.int, 0),
            .int_big_positive => return lhs.cast(Payload.IntBigPositive).?.asBigInt().orderAgainstScalar(0),
            .int_big_negative => return lhs.cast(Payload.IntBigNegative).?.asBigInt().orderAgainstScalar(0),
        }
    }

    /// Asserts the value is comparable.
    pub fn order(lhs: Value, rhs: Value) std.math.Order {
        const lhs_tag = lhs.tag();
        const rhs_tag = lhs.tag();
        const lhs_is_zero = lhs_tag == .zero or lhs_tag == .the_one_possible_value;
        const rhs_is_zero = rhs_tag == .zero or rhs_tag == .the_one_possible_value;
        if (lhs_is_zero) return rhs.orderAgainstZero().invert();
        if (rhs_is_zero) return lhs.orderAgainstZero();

        // TODO floats

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
        // TODO non numerical comparisons
        return compare(a, .eq, b);
    }

    pub fn toBool(self: Value) bool {
        return switch (self.tag()) {
            .bool_true => true,
            .bool_false, .zero => false,
            else => unreachable,
        };
    }

    /// Asserts the value is a pointer and dereferences it.
    /// Returns error.AnalysisFail if the pointer points to a Decl that failed semantic analysis.
    pub fn pointerDeref(self: Value, allocator: *Allocator) error{ AnalysisFail, OutOfMemory }!Value {
        return switch (self.tag()) {
            .ty,
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
            .zero,
            .bool_true,
            .bool_false,
            .null_value,
            .function,
            .int_u64,
            .int_i64,
            .int_big_positive,
            .int_big_negative,
            .bytes,
            .undef,
            .repeated,
            => unreachable,

            .the_one_possible_value => Value.initTag(.the_one_possible_value),
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
            .zero,
            .the_one_possible_value,
            .bool_true,
            .bool_false,
            .null_value,
            .function,
            .int_u64,
            .int_i64,
            .int_big_positive,
            .int_big_negative,
            .undef,
            .elem_ptr,
            .ref_val,
            .decl_ref,
            => unreachable,

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

    /// Valid for all types. Asserts the value is not undefined.
    /// `.the_one_possible_value` is reported as not null.
    pub fn isNull(self: Value) bool {
        return switch (self.tag()) {
            .ty,
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
            .zero,
            .the_one_possible_value,
            .bool_true,
            .bool_false,
            .function,
            .int_u64,
            .int_i64,
            .int_big_positive,
            .int_big_negative,
            .ref_val,
            .decl_ref,
            .elem_ptr,
            .bytes,
            .repeated,
            => false,

            .undef => unreachable,
            .null_value => true,
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

        pub const Repeated = struct {
            base: Payload = Payload{ .tag = .ty },
            /// This value is repeated some number of times. The amount of times to repeat
            /// is stored externally.
            val: Value,
        };
    };

    /// Big enough to fit any non-BigInt value
    pub const BigIntSpace = struct {
        /// The +1 is headroom so that operations such as incrementing once or decrementing once
        /// are possible without using an allocator.
        limbs: [(@sizeOf(u64) / @sizeOf(std.math.big.Limb)) + 1]std.math.big.Limb,
    };
};
