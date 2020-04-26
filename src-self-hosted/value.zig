const std = @import("std");
const Type = @import("type.zig").Type;
const log2 = std.math.log2;
const assert = std.debug.assert;
const BigInt = std.math.big.Int;
const Target = std.Target;
const Allocator = std.mem.Allocator;

/// This is the raw data, with no bookkeeping, no memory awareness,
/// no de-duplication, and no type system awareness.
/// It's important for this struct to be small.
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
        isize_type,
        usize_type,
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
        fn_naked_noreturn_no_args_type,
        single_const_pointer_to_comptime_int_type,
        const_slice_u8_type,

        zero,
        void_value,
        noreturn_value,
        bool_true,
        bool_false, // See last_no_payload_tag below.
        // After this, the tag requires a payload.

        ty,
        int_u64,
        int_i64,
        int_big,
        function,
        ref,
        ref_val,
        bytes,

        pub const last_no_payload_tag = Tag.bool_false;
        pub const no_payload_count = @enumToInt(last_no_payload_tag) + 1;
    };

    pub fn initTag(comptime small_tag: Tag) Value {
        comptime assert(@enumToInt(small_tag) < Tag.no_payload_count);
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

    pub fn format(
        self: Value,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: var,
    ) !void {
        comptime assert(fmt.len == 0);
        var val = self;
        while (true) switch (val.tag()) {
            .u8_type => return out_stream.writeAll("u8"),
            .i8_type => return out_stream.writeAll("i8"),
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
            .fn_naked_noreturn_no_args_type => return out_stream.writeAll("fn() callconv(.Naked) noreturn"),
            .single_const_pointer_to_comptime_int_type => return out_stream.writeAll("*const comptime_int"),
            .const_slice_u8_type => return out_stream.writeAll("[]const u8"),

            .zero => return out_stream.writeAll("0"),
            .void_value => return out_stream.writeAll("{}"),
            .noreturn_value => return out_stream.writeAll("unreachable"),
            .bool_true => return out_stream.writeAll("true"),
            .bool_false => return out_stream.writeAll("false"),
            .ty => return val.cast(Payload.Ty).?.ty.format("", options, out_stream),
            .int_u64 => return std.fmt.formatIntValue(val.cast(Payload.Int_u64).?.int, "", options, out_stream),
            .int_i64 => return std.fmt.formatIntValue(val.cast(Payload.Int_i64).?.int, "", options, out_stream),
            .int_big => return out_stream.print("{}", .{val.cast(Payload.IntBig).?.big_int}),
            .function => return out_stream.writeAll("(function)"),
            .ref => return out_stream.writeAll("(ref)"),
            .ref_val => {
                try out_stream.writeAll("*const ");
                val = val.cast(Payload.RefVal).?.val;
                continue;
            },
            .bytes => return std.zig.renderStringLiteral(self.cast(Payload.Bytes).?.data, out_stream),
        };
    }

    /// Asserts that the value is representable as an array of bytes.
    /// Copies the value into a freshly allocated slice of memory, which is owned by the caller.
    pub fn toAllocatedBytes(self: Value, allocator: *Allocator) Allocator.Error![]u8 {
        if (self.cast(Payload.Bytes)) |bytes| {
            return std.mem.dupe(allocator, u8, bytes.data);
        }
        unreachable;
    }

    /// Asserts that the value is representable as a type.
    pub fn toType(self: Value) Type {
        return switch (self.tag()) {
            .ty => self.cast(Payload.Ty).?.ty,

            .u8_type => Type.initTag(.@"u8"),
            .i8_type => Type.initTag(.@"i8"),
            .isize_type => Type.initTag(.@"isize"),
            .usize_type => Type.initTag(.@"usize"),
            .c_short_type => Type.initTag(.@"c_short"),
            .c_ushort_type => Type.initTag(.@"c_ushort"),
            .c_int_type => Type.initTag(.@"c_int"),
            .c_uint_type => Type.initTag(.@"c_uint"),
            .c_long_type => Type.initTag(.@"c_long"),
            .c_ulong_type => Type.initTag(.@"c_ulong"),
            .c_longlong_type => Type.initTag(.@"c_longlong"),
            .c_ulonglong_type => Type.initTag(.@"c_ulonglong"),
            .c_longdouble_type => Type.initTag(.@"c_longdouble"),
            .f16_type => Type.initTag(.@"f16"),
            .f32_type => Type.initTag(.@"f32"),
            .f64_type => Type.initTag(.@"f64"),
            .f128_type => Type.initTag(.@"f128"),
            .c_void_type => Type.initTag(.@"c_void"),
            .bool_type => Type.initTag(.@"bool"),
            .void_type => Type.initTag(.@"void"),
            .type_type => Type.initTag(.@"type"),
            .anyerror_type => Type.initTag(.@"anyerror"),
            .comptime_int_type => Type.initTag(.@"comptime_int"),
            .comptime_float_type => Type.initTag(.@"comptime_float"),
            .noreturn_type => Type.initTag(.@"noreturn"),
            .fn_naked_noreturn_no_args_type => Type.initTag(.fn_naked_noreturn_no_args),
            .single_const_pointer_to_comptime_int_type => Type.initTag(.single_const_pointer_to_comptime_int),
            .const_slice_u8_type => Type.initTag(.const_slice_u8),

            .zero,
            .void_value,
            .noreturn_value,
            .bool_true,
            .bool_false,
            .int_u64,
            .int_i64,
            .int_big,
            .function,
            .ref,
            .ref_val,
            .bytes,
            => unreachable,
        };
    }

    /// Asserts the value is an integer.
    pub fn toBigInt(self: Value, allocator: *Allocator) Allocator.Error!BigInt {
        switch (self.tag()) {
            .ty,
            .u8_type,
            .i8_type,
            .isize_type,
            .usize_type,
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
            .fn_naked_noreturn_no_args_type,
            .single_const_pointer_to_comptime_int_type,
            .const_slice_u8_type,
            .void_value,
            .noreturn_value,
            .bool_true,
            .bool_false,
            .function,
            .ref,
            .ref_val,
            .bytes,
            => unreachable,

            .zero => return BigInt.initSet(allocator, 0),

            .int_u64 => return BigInt.initSet(allocator, self.cast(Payload.Int_u64).?.int),
            .int_i64 => return BigInt.initSet(allocator, self.cast(Payload.Int_i64).?.int),
            .int_big => return self.cast(Payload.IntBig).?.big_int,
        }
    }

    /// Asserts the value is an integer and it fits in a u64
    pub fn toUnsignedInt(self: Value) u64 {
        switch (self.tag()) {
            .ty,
            .u8_type,
            .i8_type,
            .isize_type,
            .usize_type,
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
            .fn_naked_noreturn_no_args_type,
            .single_const_pointer_to_comptime_int_type,
            .const_slice_u8_type,
            .void_value,
            .noreturn_value,
            .bool_true,
            .bool_false,
            .function,
            .ref,
            .ref_val,
            .bytes,
            => unreachable,

            .zero => return 0,

            .int_u64 => return self.cast(Payload.Int_u64).?.int,
            .int_i64 => return @intCast(u64, self.cast(Payload.Int_u64).?.int),
            .int_big => return self.cast(Payload.IntBig).?.big_int.to(u64) catch unreachable,
        }
    }

    /// Asserts the value is an integer, and the destination type is ComptimeInt or Int.
    pub fn intFitsInType(self: Value, ty: Type, target: Target) bool {
        switch (self.tag()) {
            .ty,
            .u8_type,
            .i8_type,
            .isize_type,
            .usize_type,
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
            .fn_naked_noreturn_no_args_type,
            .single_const_pointer_to_comptime_int_type,
            .const_slice_u8_type,
            .void_value,
            .noreturn_value,
            .bool_true,
            .bool_false,
            .function,
            .ref,
            .ref_val,
            .bytes,
            => unreachable,

            .zero => return true,

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
            .int_big => switch (ty.zigTypeTag()) {
                .Int => {
                    const info = ty.intInfo(target);
                    return self.cast(Payload.IntBig).?.big_int.fitsInTwosComp(info.signed, info.bits);
                },
                .ComptimeInt => return true,
                else => unreachable,
            },
        }
    }

    /// Asserts the value is a pointer and dereferences it.
    pub fn pointerDeref(self: Value) Value {
        switch (self.tag()) {
            .ty,
            .u8_type,
            .i8_type,
            .isize_type,
            .usize_type,
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
            .fn_naked_noreturn_no_args_type,
            .single_const_pointer_to_comptime_int_type,
            .const_slice_u8_type,
            .zero,
            .void_value,
            .noreturn_value,
            .bool_true,
            .bool_false,
            .function,
            .int_u64,
            .int_i64,
            .int_big,
            .bytes,
            => unreachable,

            .ref => return self.cast(Payload.Ref).?.cell.contents,
            .ref_val => return self.cast(Payload.RefVal).?.val,
        }
    }

    /// Asserts the value is a single-item pointer to an array, or an array,
    /// or an unknown-length pointer, and returns the element value at the index.
    pub fn elemValueAt(self: Value, allocator: *Allocator, index: usize) Allocator.Error!Value {
        switch (self.tag()) {
            .ty,
            .u8_type,
            .i8_type,
            .isize_type,
            .usize_type,
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
            .fn_naked_noreturn_no_args_type,
            .single_const_pointer_to_comptime_int_type,
            .const_slice_u8_type,
            .zero,
            .void_value,
            .noreturn_value,
            .bool_true,
            .bool_false,
            .function,
            .int_u64,
            .int_i64,
            .int_big,
            => unreachable,

            .ref => @panic("TODO figure out how MemoryCell works"),
            .ref_val => @panic("TODO figure out how MemoryCell works"),

            .bytes => {
                const int_payload = try allocator.create(Value.Payload.Int_u64);
                int_payload.* = .{ .int = self.cast(Payload.Bytes).?.data[index] };
                return Value.initPayload(&int_payload.base);
            },
        }
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

        pub const IntBig = struct {
            base: Payload = Payload{ .tag = .int_big },
            big_int: BigInt,
        };

        pub const Function = struct {
            base: Payload = Payload{ .tag = .function },
            /// Index into the `fns` array of the `ir.Module`
            index: usize,
        };

        pub const ArraySentinel0_u8_Type = struct {
            base: Payload = Payload{ .tag = .array_sentinel_0_u8_type },
            len: u64,
        };

        pub const SingleConstPtrType = struct {
            base: Payload = Payload{ .tag = .single_const_ptr_type },
            elem_type: *Type,
        };

        pub const Ref = struct {
            base: Payload = Payload{ .tag = .ref },
            cell: *MemoryCell,
        };

        pub const RefVal = struct {
            base: Payload = Payload{ .tag = .ref_val },
            val: Value,
        };

        pub const Bytes = struct {
            base: Payload = Payload{ .tag = .bytes },
            data: []const u8,
        };

        pub const Ty = struct {
            base: Payload = Payload{ .tag = .ty },
            ty: Type,
        };
    };
};

/// This is the heart of resource management of the Zig compiler. The Zig compiler uses
/// stop-the-world mark-and-sweep garbage collection during compilation to manage the resources
/// associated with evaluating compile-time code and semantic analysis. Each `MemoryCell` represents
/// a root.
pub const MemoryCell = struct {
    parent: Parent,
    contents: Value,

    pub const Parent = union(enum) {
        none,
        struct_field: struct {
            struct_base: *MemoryCell,
            field_index: usize,
        },
        array_elem: struct {
            array_base: *MemoryCell,
            elem_index: usize,
        },
        union_field: *MemoryCell,
        err_union_code: *MemoryCell,
        err_union_payload: *MemoryCell,
        optional_payload: *MemoryCell,
        optional_flag: *MemoryCell,
    };
};
