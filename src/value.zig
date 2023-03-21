const std = @import("std");
const builtin = @import("builtin");
const Type = @import("type.zig").Type;
const log2 = std.math.log2;
const assert = std.debug.assert;
const BigIntConst = std.math.big.int.Const;
const BigIntMutable = std.math.big.int.Mutable;
const Target = std.Target;
const Allocator = std.mem.Allocator;
const Module = @import("Module.zig");
const Air = @import("Air.zig");
const TypedValue = @import("TypedValue.zig");
const Sema = @import("Sema.zig");

/// This is the raw data, with no bookkeeping, no memory awareness,
/// no de-duplication, and no type system awareness.
/// It's important for this type to be small.
/// This union takes advantage of the fact that the first page of memory
/// is unmapped, giving us 4096 possible enum tags that have no payload.
pub const Value = extern union {
    /// If the tag value is less than Tag.no_payload_count, then no pointer
    /// dereference is needed.
    tag_if_small_enough: Tag,
    ptr_otherwise: *Payload,

    // Keep in sync with tools/stage2_pretty_printers_common.py
    pub const Tag = enum(usize) {
        // The first section of this enum are tags that require no payload.
        u1_type,
        u8_type,
        i8_type,
        u16_type,
        i16_type,
        u29_type,
        u32_type,
        i32_type,
        u64_type,
        i64_type,
        u128_type,
        i128_type,
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
        f80_type,
        f128_type,
        anyopaque_type,
        bool_type,
        void_type,
        type_type,
        anyerror_type,
        comptime_int_type,
        comptime_float_type,
        noreturn_type,
        anyframe_type,
        null_type,
        undefined_type,
        enum_literal_type,
        atomic_order_type,
        atomic_rmw_op_type,
        calling_convention_type,
        address_space_type,
        float_mode_type,
        reduce_op_type,
        modifier_type,
        prefetch_options_type,
        export_options_type,
        extern_options_type,
        type_info_type,
        manyptr_u8_type,
        manyptr_const_u8_type,
        manyptr_const_u8_sentinel_0_type,
        fn_noreturn_no_args_type,
        fn_void_no_args_type,
        fn_naked_noreturn_no_args_type,
        fn_ccc_void_no_args_type,
        single_const_pointer_to_comptime_int_type,
        const_slice_u8_type,
        const_slice_u8_sentinel_0_type,
        anyerror_void_error_union_type,
        generic_poison_type,

        undef,
        zero,
        one,
        void_value,
        unreachable_value,
        /// The only possible value for a particular type, which is stored externally.
        the_only_possible_value,
        null_value,
        bool_true,
        bool_false,
        generic_poison,

        empty_struct_value,
        empty_array, // See last_no_payload_tag below.
        // After this, the tag requires a payload.

        ty,
        int_type,
        int_u64,
        int_i64,
        int_big_positive,
        int_big_negative,
        function,
        extern_fn,
        variable,
        /// A wrapper for values which are comptime-known but should
        /// semantically be runtime-known.
        runtime_value,
        /// Represents a pointer to a Decl.
        /// When machine codegen backend sees this, it must set the Decl's `alive` field to true.
        decl_ref,
        /// Pointer to a Decl, but allows comptime code to mutate the Decl's Value.
        /// This Tag will never be seen by machine codegen backends. It is changed into a
        /// `decl_ref` when a comptime variable goes out of scope.
        decl_ref_mut,
        /// Behaves like `decl_ref_mut` but validates that the stored value matches the field value.
        comptime_field_ptr,
        /// Pointer to a specific element of an array, vector or slice.
        elem_ptr,
        /// Pointer to a specific field of a struct or union.
        field_ptr,
        /// A slice of u8 whose memory is managed externally.
        bytes,
        /// Similar to bytes however it stores an index relative to `Module.string_literal_bytes`.
        str_lit,
        /// This value is repeated some number of times. The amount of times to repeat
        /// is stored externally.
        repeated,
        /// An array with length 0 but it has a sentinel.
        empty_array_sentinel,
        /// Pointer and length as sub `Value` objects.
        slice,
        float_16,
        float_32,
        float_64,
        float_80,
        float_128,
        enum_literal,
        /// A specific enum tag, indicated by the field index (declaration order).
        enum_field_index,
        @"error",
        /// When the type is error union:
        /// * If the tag is `.@"error"`, the error union is an error.
        /// * If the tag is `.eu_payload`, the error union is a payload.
        /// * A nested error such as `anyerror!(anyerror!T)` in which the the outer error union
        ///   is non-error, but the inner error union is an error, is represented as
        ///   a tag of `.eu_payload`, with a sub-tag of `.@"error"`.
        eu_payload,
        /// A pointer to the payload of an error union, based on a pointer to an error union.
        eu_payload_ptr,
        /// When the type is optional:
        /// * If the tag is `.null_value`, the optional is null.
        /// * If the tag is `.opt_payload`, the optional is a payload.
        /// * A nested optional such as `??T` in which the the outer optional
        ///   is non-null, but the inner optional is null, is represented as
        ///   a tag of `.opt_payload`, with a sub-tag of `.null_value`.
        opt_payload,
        /// A pointer to the payload of an optional, based on a pointer to an optional.
        opt_payload_ptr,
        /// An instance of a struct, array, or vector.
        /// Each element/field stored as a `Value`.
        /// In the case of sentinel-terminated arrays, the sentinel value *is* stored,
        /// so the slice length will be one more than the type's array length.
        aggregate,
        /// An instance of a union.
        @"union",
        /// This is a special value that tracks a set of types that have been stored
        /// to an inferred allocation. It does not support any of the normal value queries.
        inferred_alloc,
        /// Used to coordinate alloc_inferred, store_to_inferred_ptr, and resolve_inferred_alloc
        /// instructions for comptime code.
        inferred_alloc_comptime,
        /// Used sometimes as the result of field_call_bind.  This value is always temporary,
        /// and refers directly to the air.  It will never be referenced by the air itself.
        /// TODO: This is probably a bad encoding, maybe put temp data in the sema instead.
        bound_fn,
        /// The ABI alignment of the payload type.
        lazy_align,
        /// The ABI size of the payload type.
        lazy_size,

        pub const last_no_payload_tag = Tag.empty_array;
        pub const no_payload_count = @enumToInt(last_no_payload_tag) + 1;

        pub fn Type(comptime t: Tag) type {
            return switch (t) {
                .u1_type,
                .u8_type,
                .i8_type,
                .u16_type,
                .i16_type,
                .u29_type,
                .u32_type,
                .i32_type,
                .u64_type,
                .i64_type,
                .u128_type,
                .i128_type,
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
                .f80_type,
                .f128_type,
                .anyopaque_type,
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
                .anyframe_type,
                .const_slice_u8_type,
                .const_slice_u8_sentinel_0_type,
                .anyerror_void_error_union_type,
                .generic_poison_type,
                .enum_literal_type,
                .undef,
                .zero,
                .one,
                .void_value,
                .unreachable_value,
                .the_only_possible_value,
                .empty_struct_value,
                .empty_array,
                .null_value,
                .bool_true,
                .bool_false,
                .manyptr_u8_type,
                .manyptr_const_u8_type,
                .manyptr_const_u8_sentinel_0_type,
                .atomic_order_type,
                .atomic_rmw_op_type,
                .calling_convention_type,
                .address_space_type,
                .float_mode_type,
                .reduce_op_type,
                .modifier_type,
                .prefetch_options_type,
                .export_options_type,
                .extern_options_type,
                .type_info_type,
                .generic_poison,
                => @compileError("Value Tag " ++ @tagName(t) ++ " has no payload"),

                .int_big_positive,
                .int_big_negative,
                => Payload.BigInt,

                .extern_fn => Payload.ExternFn,

                .decl_ref => Payload.Decl,

                .repeated,
                .eu_payload,
                .opt_payload,
                .empty_array_sentinel,
                .runtime_value,
                => Payload.SubValue,

                .eu_payload_ptr,
                .opt_payload_ptr,
                => Payload.PayloadPtr,

                .bytes,
                .enum_literal,
                => Payload.Bytes,

                .str_lit => Payload.StrLit,
                .slice => Payload.Slice,

                .enum_field_index => Payload.U32,

                .ty,
                .lazy_align,
                .lazy_size,
                => Payload.Ty,

                .int_type => Payload.IntType,
                .int_u64 => Payload.U64,
                .int_i64 => Payload.I64,
                .function => Payload.Function,
                .variable => Payload.Variable,
                .decl_ref_mut => Payload.DeclRefMut,
                .elem_ptr => Payload.ElemPtr,
                .field_ptr => Payload.FieldPtr,
                .float_16 => Payload.Float_16,
                .float_32 => Payload.Float_32,
                .float_64 => Payload.Float_64,
                .float_80 => Payload.Float_80,
                .float_128 => Payload.Float_128,
                .@"error" => Payload.Error,
                .inferred_alloc => Payload.InferredAlloc,
                .inferred_alloc_comptime => Payload.InferredAllocComptime,
                .aggregate => Payload.Aggregate,
                .@"union" => Payload.Union,
                .bound_fn => Payload.BoundFn,
                .comptime_field_ptr => Payload.ComptimeFieldPtr,
            };
        }

        pub fn create(comptime t: Tag, ally: Allocator, data: Data(t)) error{OutOfMemory}!Value {
            const ptr = try ally.create(t.Type());
            ptr.* = .{
                .base = .{ .tag = t },
                .data = data,
            };
            return Value{ .ptr_otherwise = &ptr.base };
        }

        pub fn Data(comptime t: Tag) type {
            return std.meta.fieldInfo(t.Type(), .data).type;
        }
    };

    pub fn initTag(small_tag: Tag) Value {
        assert(@enumToInt(small_tag) < Tag.no_payload_count);
        return .{ .tag_if_small_enough = small_tag };
    }

    pub fn initPayload(payload: *Payload) Value {
        assert(@enumToInt(payload.tag) >= Tag.no_payload_count);
        return .{ .ptr_otherwise = payload };
    }

    pub fn tag(self: Value) Tag {
        if (@enumToInt(self.tag_if_small_enough) < Tag.no_payload_count) {
            return self.tag_if_small_enough;
        } else {
            return self.ptr_otherwise.tag;
        }
    }

    /// Prefer `castTag` to this.
    pub fn cast(self: Value, comptime T: type) ?*T {
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

    pub fn castTag(self: Value, comptime t: Tag) ?*t.Type() {
        if (@enumToInt(self.tag_if_small_enough) < Tag.no_payload_count)
            return null;

        if (self.ptr_otherwise.tag == t)
            return @fieldParentPtr(t.Type(), "base", self.ptr_otherwise);

        return null;
    }

    /// It's intentional that this function is not passed a corresponding Type, so that
    /// a Value can be copied from a Sema to a Decl prior to resolving struct/union field types.
    pub fn copy(self: Value, arena: Allocator) error{OutOfMemory}!Value {
        if (@enumToInt(self.tag_if_small_enough) < Tag.no_payload_count) {
            return Value{ .tag_if_small_enough = self.tag_if_small_enough };
        } else switch (self.ptr_otherwise.tag) {
            .u1_type,
            .u8_type,
            .i8_type,
            .u16_type,
            .i16_type,
            .u29_type,
            .u32_type,
            .i32_type,
            .u64_type,
            .i64_type,
            .u128_type,
            .i128_type,
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
            .f80_type,
            .f128_type,
            .anyopaque_type,
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
            .anyframe_type,
            .const_slice_u8_type,
            .const_slice_u8_sentinel_0_type,
            .anyerror_void_error_union_type,
            .generic_poison_type,
            .enum_literal_type,
            .undef,
            .zero,
            .one,
            .void_value,
            .unreachable_value,
            .the_only_possible_value,
            .empty_array,
            .null_value,
            .bool_true,
            .bool_false,
            .empty_struct_value,
            .manyptr_u8_type,
            .manyptr_const_u8_type,
            .manyptr_const_u8_sentinel_0_type,
            .atomic_order_type,
            .atomic_rmw_op_type,
            .calling_convention_type,
            .address_space_type,
            .float_mode_type,
            .reduce_op_type,
            .modifier_type,
            .prefetch_options_type,
            .export_options_type,
            .extern_options_type,
            .type_info_type,
            .generic_poison,
            .bound_fn,
            => unreachable,

            .ty, .lazy_align, .lazy_size => {
                const payload = self.cast(Payload.Ty).?;
                const new_payload = try arena.create(Payload.Ty);
                new_payload.* = .{
                    .base = payload.base,
                    .data = try payload.data.copy(arena),
                };
                return Value{ .ptr_otherwise = &new_payload.base };
            },
            .int_type => return self.copyPayloadShallow(arena, Payload.IntType),
            .int_u64 => return self.copyPayloadShallow(arena, Payload.U64),
            .int_i64 => return self.copyPayloadShallow(arena, Payload.I64),
            .int_big_positive, .int_big_negative => {
                const old_payload = self.cast(Payload.BigInt).?;
                const new_payload = try arena.create(Payload.BigInt);
                new_payload.* = .{
                    .base = .{ .tag = self.ptr_otherwise.tag },
                    .data = try arena.dupe(std.math.big.Limb, old_payload.data),
                };
                return Value{ .ptr_otherwise = &new_payload.base };
            },
            .function => return self.copyPayloadShallow(arena, Payload.Function),
            .extern_fn => return self.copyPayloadShallow(arena, Payload.ExternFn),
            .variable => return self.copyPayloadShallow(arena, Payload.Variable),
            .decl_ref => return self.copyPayloadShallow(arena, Payload.Decl),
            .decl_ref_mut => return self.copyPayloadShallow(arena, Payload.DeclRefMut),
            .eu_payload_ptr,
            .opt_payload_ptr,
            => {
                const payload = self.cast(Payload.PayloadPtr).?;
                const new_payload = try arena.create(Payload.PayloadPtr);
                new_payload.* = .{
                    .base = payload.base,
                    .data = .{
                        .container_ptr = try payload.data.container_ptr.copy(arena),
                        .container_ty = try payload.data.container_ty.copy(arena),
                    },
                };
                return Value{ .ptr_otherwise = &new_payload.base };
            },
            .comptime_field_ptr => {
                const payload = self.cast(Payload.ComptimeFieldPtr).?;
                const new_payload = try arena.create(Payload.ComptimeFieldPtr);
                new_payload.* = .{
                    .base = payload.base,
                    .data = .{
                        .field_val = try payload.data.field_val.copy(arena),
                        .field_ty = try payload.data.field_ty.copy(arena),
                    },
                };
                return Value{ .ptr_otherwise = &new_payload.base };
            },
            .elem_ptr => {
                const payload = self.castTag(.elem_ptr).?;
                const new_payload = try arena.create(Payload.ElemPtr);
                new_payload.* = .{
                    .base = payload.base,
                    .data = .{
                        .array_ptr = try payload.data.array_ptr.copy(arena),
                        .elem_ty = try payload.data.elem_ty.copy(arena),
                        .index = payload.data.index,
                    },
                };
                return Value{ .ptr_otherwise = &new_payload.base };
            },
            .field_ptr => {
                const payload = self.castTag(.field_ptr).?;
                const new_payload = try arena.create(Payload.FieldPtr);
                new_payload.* = .{
                    .base = payload.base,
                    .data = .{
                        .container_ptr = try payload.data.container_ptr.copy(arena),
                        .container_ty = try payload.data.container_ty.copy(arena),
                        .field_index = payload.data.field_index,
                    },
                };
                return Value{ .ptr_otherwise = &new_payload.base };
            },
            .bytes => {
                const bytes = self.castTag(.bytes).?.data;
                const new_payload = try arena.create(Payload.Bytes);
                new_payload.* = .{
                    .base = .{ .tag = .bytes },
                    .data = try arena.dupe(u8, bytes),
                };
                return Value{ .ptr_otherwise = &new_payload.base };
            },
            .str_lit => return self.copyPayloadShallow(arena, Payload.StrLit),
            .repeated,
            .eu_payload,
            .opt_payload,
            .empty_array_sentinel,
            .runtime_value,
            => {
                const payload = self.cast(Payload.SubValue).?;
                const new_payload = try arena.create(Payload.SubValue);
                new_payload.* = .{
                    .base = payload.base,
                    .data = try payload.data.copy(arena),
                };
                return Value{ .ptr_otherwise = &new_payload.base };
            },
            .slice => {
                const payload = self.castTag(.slice).?;
                const new_payload = try arena.create(Payload.Slice);
                new_payload.* = .{
                    .base = payload.base,
                    .data = .{
                        .ptr = try payload.data.ptr.copy(arena),
                        .len = try payload.data.len.copy(arena),
                    },
                };
                return Value{ .ptr_otherwise = &new_payload.base };
            },
            .float_16 => return self.copyPayloadShallow(arena, Payload.Float_16),
            .float_32 => return self.copyPayloadShallow(arena, Payload.Float_32),
            .float_64 => return self.copyPayloadShallow(arena, Payload.Float_64),
            .float_80 => return self.copyPayloadShallow(arena, Payload.Float_80),
            .float_128 => return self.copyPayloadShallow(arena, Payload.Float_128),
            .enum_literal => {
                const payload = self.castTag(.enum_literal).?;
                const new_payload = try arena.create(Payload.Bytes);
                new_payload.* = .{
                    .base = payload.base,
                    .data = try arena.dupe(u8, payload.data),
                };
                return Value{ .ptr_otherwise = &new_payload.base };
            },
            .enum_field_index => return self.copyPayloadShallow(arena, Payload.U32),
            .@"error" => return self.copyPayloadShallow(arena, Payload.Error),

            .aggregate => {
                const payload = self.castTag(.aggregate).?;
                const new_payload = try arena.create(Payload.Aggregate);
                new_payload.* = .{
                    .base = payload.base,
                    .data = try arena.alloc(Value, payload.data.len),
                };
                for (new_payload.data, 0..) |*elem, i| {
                    elem.* = try payload.data[i].copy(arena);
                }
                return Value{ .ptr_otherwise = &new_payload.base };
            },

            .@"union" => {
                const tag_and_val = self.castTag(.@"union").?.data;
                const new_payload = try arena.create(Payload.Union);
                new_payload.* = .{
                    .base = .{ .tag = .@"union" },
                    .data = .{
                        .tag = try tag_and_val.tag.copy(arena),
                        .val = try tag_and_val.val.copy(arena),
                    },
                };
                return Value{ .ptr_otherwise = &new_payload.base };
            },

            .inferred_alloc => unreachable,
            .inferred_alloc_comptime => unreachable,
        }
    }

    fn copyPayloadShallow(self: Value, arena: Allocator, comptime T: type) error{OutOfMemory}!Value {
        const payload = self.cast(T).?;
        const new_payload = try arena.create(T);
        new_payload.* = payload.*;
        return Value{ .ptr_otherwise = &new_payload.base };
    }

    pub fn format(val: Value, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = val;
        _ = fmt;
        _ = options;
        _ = writer;
        @compileError("do not use format values directly; use either fmtDebug or fmtValue");
    }

    /// This is a debug function. In order to print values in a meaningful way
    /// we also need access to the type.
    pub fn dump(
        start_val: Value,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) !void {
        comptime assert(fmt.len == 0);
        var val = start_val;
        while (true) switch (val.tag()) {
            .u1_type => return out_stream.writeAll("u1"),
            .u8_type => return out_stream.writeAll("u8"),
            .i8_type => return out_stream.writeAll("i8"),
            .u16_type => return out_stream.writeAll("u16"),
            .u29_type => return out_stream.writeAll("u29"),
            .i16_type => return out_stream.writeAll("i16"),
            .u32_type => return out_stream.writeAll("u32"),
            .i32_type => return out_stream.writeAll("i32"),
            .u64_type => return out_stream.writeAll("u64"),
            .i64_type => return out_stream.writeAll("i64"),
            .u128_type => return out_stream.writeAll("u128"),
            .i128_type => return out_stream.writeAll("i128"),
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
            .f80_type => return out_stream.writeAll("f80"),
            .f128_type => return out_stream.writeAll("f128"),
            .anyopaque_type => return out_stream.writeAll("anyopaque"),
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
            .anyframe_type => return out_stream.writeAll("anyframe"),
            .const_slice_u8_type => return out_stream.writeAll("[]const u8"),
            .const_slice_u8_sentinel_0_type => return out_stream.writeAll("[:0]const u8"),
            .anyerror_void_error_union_type => return out_stream.writeAll("anyerror!void"),
            .generic_poison_type => return out_stream.writeAll("(generic poison type)"),
            .generic_poison => return out_stream.writeAll("(generic poison)"),
            .enum_literal_type => return out_stream.writeAll("@Type(.EnumLiteral)"),
            .manyptr_u8_type => return out_stream.writeAll("[*]u8"),
            .manyptr_const_u8_type => return out_stream.writeAll("[*]const u8"),
            .manyptr_const_u8_sentinel_0_type => return out_stream.writeAll("[*:0]const u8"),
            .atomic_order_type => return out_stream.writeAll("std.builtin.AtomicOrder"),
            .atomic_rmw_op_type => return out_stream.writeAll("std.builtin.AtomicRmwOp"),
            .calling_convention_type => return out_stream.writeAll("std.builtin.CallingConvention"),
            .address_space_type => return out_stream.writeAll("std.builtin.AddressSpace"),
            .float_mode_type => return out_stream.writeAll("std.builtin.FloatMode"),
            .reduce_op_type => return out_stream.writeAll("std.builtin.ReduceOp"),
            .modifier_type => return out_stream.writeAll("std.builtin.CallModifier"),
            .prefetch_options_type => return out_stream.writeAll("std.builtin.PrefetchOptions"),
            .export_options_type => return out_stream.writeAll("std.builtin.ExportOptions"),
            .extern_options_type => return out_stream.writeAll("std.builtin.ExternOptions"),
            .type_info_type => return out_stream.writeAll("std.builtin.Type"),

            .empty_struct_value => return out_stream.writeAll("struct {}{}"),
            .aggregate => {
                return out_stream.writeAll("(aggregate)");
            },
            .@"union" => {
                return out_stream.writeAll("(union value)");
            },
            .null_value => return out_stream.writeAll("null"),
            .undef => return out_stream.writeAll("undefined"),
            .zero => return out_stream.writeAll("0"),
            .one => return out_stream.writeAll("1"),
            .void_value => return out_stream.writeAll("{}"),
            .unreachable_value => return out_stream.writeAll("unreachable"),
            .the_only_possible_value => return out_stream.writeAll("(the only possible value)"),
            .bool_true => return out_stream.writeAll("true"),
            .bool_false => return out_stream.writeAll("false"),
            .ty => return val.castTag(.ty).?.data.dump("", options, out_stream),
            .lazy_align => {
                try out_stream.writeAll("@alignOf(");
                try val.castTag(.lazy_align).?.data.dump("", options, out_stream);
                return try out_stream.writeAll(")");
            },
            .lazy_size => {
                try out_stream.writeAll("@sizeOf(");
                try val.castTag(.lazy_size).?.data.dump("", options, out_stream);
                return try out_stream.writeAll(")");
            },
            .int_type => {
                const int_type = val.castTag(.int_type).?.data;
                return out_stream.print("{s}{d}", .{
                    if (int_type.signed) "s" else "u",
                    int_type.bits,
                });
            },
            .int_u64 => return std.fmt.formatIntValue(val.castTag(.int_u64).?.data, "", options, out_stream),
            .int_i64 => return std.fmt.formatIntValue(val.castTag(.int_i64).?.data, "", options, out_stream),
            .int_big_positive => return out_stream.print("{}", .{val.castTag(.int_big_positive).?.asBigInt()}),
            .int_big_negative => return out_stream.print("{}", .{val.castTag(.int_big_negative).?.asBigInt()}),
            .runtime_value => return out_stream.writeAll("[runtime value]"),
            .function => return out_stream.print("(function decl={d})", .{val.castTag(.function).?.data.owner_decl}),
            .extern_fn => return out_stream.writeAll("(extern function)"),
            .variable => return out_stream.writeAll("(variable)"),
            .decl_ref_mut => {
                const decl_index = val.castTag(.decl_ref_mut).?.data.decl_index;
                return out_stream.print("(decl_ref_mut {d})", .{decl_index});
            },
            .decl_ref => {
                const decl_index = val.castTag(.decl_ref).?.data;
                return out_stream.print("(decl_ref {d})", .{decl_index});
            },
            .comptime_field_ptr => {
                return out_stream.writeAll("(comptime_field_ptr)");
            },
            .elem_ptr => {
                const elem_ptr = val.castTag(.elem_ptr).?.data;
                try out_stream.print("&[{}] ", .{elem_ptr.index});
                val = elem_ptr.array_ptr;
            },
            .field_ptr => {
                const field_ptr = val.castTag(.field_ptr).?.data;
                try out_stream.print("fieldptr({d}) ", .{field_ptr.field_index});
                val = field_ptr.container_ptr;
            },
            .empty_array => return out_stream.writeAll(".{}"),
            .enum_literal => return out_stream.print(".{}", .{std.zig.fmtId(val.castTag(.enum_literal).?.data)}),
            .enum_field_index => return out_stream.print("(enum field {d})", .{val.castTag(.enum_field_index).?.data}),
            .bytes => return out_stream.print("\"{}\"", .{std.zig.fmtEscapes(val.castTag(.bytes).?.data)}),
            .str_lit => {
                const str_lit = val.castTag(.str_lit).?.data;
                return out_stream.print("(.str_lit index={d} len={d})", .{
                    str_lit.index, str_lit.len,
                });
            },
            .repeated => {
                try out_stream.writeAll("(repeated) ");
                val = val.castTag(.repeated).?.data;
            },
            .empty_array_sentinel => return out_stream.writeAll("(empty array with sentinel)"),
            .slice => return out_stream.writeAll("(slice)"),
            .float_16 => return out_stream.print("{}", .{val.castTag(.float_16).?.data}),
            .float_32 => return out_stream.print("{}", .{val.castTag(.float_32).?.data}),
            .float_64 => return out_stream.print("{}", .{val.castTag(.float_64).?.data}),
            .float_80 => return out_stream.print("{}", .{val.castTag(.float_80).?.data}),
            .float_128 => return out_stream.print("{}", .{val.castTag(.float_128).?.data}),
            .@"error" => return out_stream.print("error.{s}", .{val.castTag(.@"error").?.data.name}),
            .eu_payload => {
                try out_stream.writeAll("(eu_payload) ");
                val = val.castTag(.eu_payload).?.data;
            },
            .opt_payload => {
                try out_stream.writeAll("(opt_payload) ");
                val = val.castTag(.opt_payload).?.data;
            },
            .inferred_alloc => return out_stream.writeAll("(inferred allocation value)"),
            .inferred_alloc_comptime => return out_stream.writeAll("(inferred comptime allocation value)"),
            .eu_payload_ptr => {
                try out_stream.writeAll("(eu_payload_ptr)");
                val = val.castTag(.eu_payload_ptr).?.data.container_ptr;
            },
            .opt_payload_ptr => {
                try out_stream.writeAll("(opt_payload_ptr)");
                val = val.castTag(.opt_payload_ptr).?.data.container_ptr;
            },
            .bound_fn => {
                const bound_func = val.castTag(.bound_fn).?.data;
                return out_stream.print("(bound_fn %{}(%{})", .{ bound_func.func_inst, bound_func.arg0_inst });
            },
        };
    }

    pub fn fmtDebug(val: Value) std.fmt.Formatter(dump) {
        return .{ .data = val };
    }

    pub fn fmtValue(val: Value, ty: Type, mod: *Module) std.fmt.Formatter(TypedValue.format) {
        return .{ .data = .{
            .tv = .{ .ty = ty, .val = val },
            .mod = mod,
        } };
    }

    /// Asserts that the value is representable as an array of bytes.
    /// Copies the value into a freshly allocated slice of memory, which is owned by the caller.
    pub fn toAllocatedBytes(val: Value, ty: Type, allocator: Allocator, mod: *Module) ![]u8 {
        const target = mod.getTarget();
        switch (val.tag()) {
            .bytes => {
                const bytes = val.castTag(.bytes).?.data;
                const adjusted_len = bytes.len - @boolToInt(ty.sentinel() != null);
                const adjusted_bytes = bytes[0..adjusted_len];
                return allocator.dupe(u8, adjusted_bytes);
            },
            .str_lit => {
                const str_lit = val.castTag(.str_lit).?.data;
                const bytes = mod.string_literal_bytes.items[str_lit.index..][0..str_lit.len];
                return allocator.dupe(u8, bytes);
            },
            .enum_literal => return allocator.dupe(u8, val.castTag(.enum_literal).?.data),
            .repeated => {
                const byte = @intCast(u8, val.castTag(.repeated).?.data.toUnsignedInt(target));
                const result = try allocator.alloc(u8, @intCast(usize, ty.arrayLen()));
                std.mem.set(u8, result, byte);
                return result;
            },
            .decl_ref => {
                const decl_index = val.castTag(.decl_ref).?.data;
                const decl = mod.declPtr(decl_index);
                const decl_val = try decl.value();
                return decl_val.toAllocatedBytes(decl.ty, allocator, mod);
            },
            .the_only_possible_value => return &[_]u8{},
            .slice => {
                const slice = val.castTag(.slice).?.data;
                return arrayToAllocatedBytes(slice.ptr, slice.len.toUnsignedInt(target), allocator, mod);
            },
            else => return arrayToAllocatedBytes(val, ty.arrayLen(), allocator, mod),
        }
    }

    fn arrayToAllocatedBytes(val: Value, len: u64, allocator: Allocator, mod: *Module) ![]u8 {
        const result = try allocator.alloc(u8, @intCast(usize, len));
        var elem_value_buf: ElemValueBuffer = undefined;
        for (result, 0..) |*elem, i| {
            const elem_val = val.elemValueBuffer(mod, i, &elem_value_buf);
            elem.* = @intCast(u8, elem_val.toUnsignedInt(mod.getTarget()));
        }
        return result;
    }

    pub const ToTypeBuffer = Type.Payload.Bits;

    /// Asserts that the value is representable as a type.
    pub fn toType(self: Value, buffer: *ToTypeBuffer) Type {
        return switch (self.tag()) {
            .ty => self.castTag(.ty).?.data,
            .u1_type => Type.initTag(.u1),
            .u8_type => Type.initTag(.u8),
            .i8_type => Type.initTag(.i8),
            .u16_type => Type.initTag(.u16),
            .i16_type => Type.initTag(.i16),
            .u29_type => Type.initTag(.u29),
            .u32_type => Type.initTag(.u32),
            .i32_type => Type.initTag(.i32),
            .u64_type => Type.initTag(.u64),
            .i64_type => Type.initTag(.i64),
            .u128_type => Type.initTag(.u128),
            .i128_type => Type.initTag(.i128),
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
            .f80_type => Type.initTag(.f80),
            .f128_type => Type.initTag(.f128),
            .anyopaque_type => Type.initTag(.anyopaque),
            .bool_type => Type.initTag(.bool),
            .void_type => Type.initTag(.void),
            .type_type => Type.initTag(.type),
            .anyerror_type => Type.initTag(.anyerror),
            .comptime_int_type => Type.initTag(.comptime_int),
            .comptime_float_type => Type.initTag(.comptime_float),
            .noreturn_type => Type.initTag(.noreturn),
            .null_type => Type.initTag(.null),
            .undefined_type => Type.initTag(.undefined),
            .fn_noreturn_no_args_type => Type.initTag(.fn_noreturn_no_args),
            .fn_void_no_args_type => Type.initTag(.fn_void_no_args),
            .fn_naked_noreturn_no_args_type => Type.initTag(.fn_naked_noreturn_no_args),
            .fn_ccc_void_no_args_type => Type.initTag(.fn_ccc_void_no_args),
            .single_const_pointer_to_comptime_int_type => Type.initTag(.single_const_pointer_to_comptime_int),
            .anyframe_type => Type.initTag(.@"anyframe"),
            .const_slice_u8_type => Type.initTag(.const_slice_u8),
            .const_slice_u8_sentinel_0_type => Type.initTag(.const_slice_u8_sentinel_0),
            .anyerror_void_error_union_type => Type.initTag(.anyerror_void_error_union),
            .generic_poison_type => Type.initTag(.generic_poison),
            .enum_literal_type => Type.initTag(.enum_literal),
            .manyptr_u8_type => Type.initTag(.manyptr_u8),
            .manyptr_const_u8_type => Type.initTag(.manyptr_const_u8),
            .manyptr_const_u8_sentinel_0_type => Type.initTag(.manyptr_const_u8_sentinel_0),
            .atomic_order_type => Type.initTag(.atomic_order),
            .atomic_rmw_op_type => Type.initTag(.atomic_rmw_op),
            .calling_convention_type => Type.initTag(.calling_convention),
            .address_space_type => Type.initTag(.address_space),
            .float_mode_type => Type.initTag(.float_mode),
            .reduce_op_type => Type.initTag(.reduce_op),
            .modifier_type => Type.initTag(.modifier),
            .prefetch_options_type => Type.initTag(.prefetch_options),
            .export_options_type => Type.initTag(.export_options),
            .extern_options_type => Type.initTag(.extern_options),
            .type_info_type => Type.initTag(.type_info),

            .int_type => {
                const payload = self.castTag(.int_type).?.data;
                buffer.* = .{
                    .base = .{
                        .tag = if (payload.signed) .int_signed else .int_unsigned,
                    },
                    .data = payload.bits,
                };
                return Type.initPayload(&buffer.base);
            },

            else => unreachable,
        };
    }

    /// Asserts the type is an enum type.
    pub fn toEnum(val: Value, comptime E: type) E {
        switch (val.tag()) {
            .enum_field_index => {
                const field_index = val.castTag(.enum_field_index).?.data;
                return @intToEnum(E, field_index);
            },
            .the_only_possible_value => {
                const fields = std.meta.fields(E);
                assert(fields.len == 1);
                return @intToEnum(E, fields[0].value);
            },
            else => unreachable,
        }
    }

    pub fn enumToInt(val: Value, ty: Type, buffer: *Payload.U64) Value {
        const field_index = switch (val.tag()) {
            .enum_field_index => val.castTag(.enum_field_index).?.data,
            .the_only_possible_value => blk: {
                assert(ty.enumFieldCount() == 1);
                break :blk 0;
            },
            .enum_literal => i: {
                const name = val.castTag(.enum_literal).?.data;
                break :i ty.enumFieldIndex(name).?;
            },
            // Assume it is already an integer and return it directly.
            else => return val,
        };

        switch (ty.tag()) {
            .enum_full, .enum_nonexhaustive => {
                const enum_full = ty.cast(Type.Payload.EnumFull).?.data;
                if (enum_full.values.count() != 0) {
                    return enum_full.values.keys()[field_index];
                } else {
                    // Field index and integer values are the same.
                    buffer.* = .{
                        .base = .{ .tag = .int_u64 },
                        .data = field_index,
                    };
                    return Value.initPayload(&buffer.base);
                }
            },
            .enum_numbered => {
                const enum_obj = ty.castTag(.enum_numbered).?.data;
                if (enum_obj.values.count() != 0) {
                    return enum_obj.values.keys()[field_index];
                } else {
                    // Field index and integer values are the same.
                    buffer.* = .{
                        .base = .{ .tag = .int_u64 },
                        .data = field_index,
                    };
                    return Value.initPayload(&buffer.base);
                }
            },
            .enum_simple => {
                // Field index and integer values are the same.
                buffer.* = .{
                    .base = .{ .tag = .int_u64 },
                    .data = field_index,
                };
                return Value.initPayload(&buffer.base);
            },
            else => unreachable,
        }
    }

    pub fn tagName(val: Value, ty: Type, mod: *Module) []const u8 {
        if (ty.zigTypeTag() == .Union) return val.unionTag().tagName(ty.unionTagTypeHypothetical(), mod);

        const field_index = switch (val.tag()) {
            .enum_field_index => val.castTag(.enum_field_index).?.data,
            .the_only_possible_value => blk: {
                assert(ty.enumFieldCount() == 1);
                break :blk 0;
            },
            .enum_literal => return val.castTag(.enum_literal).?.data,
            else => field_index: {
                const values = switch (ty.tag()) {
                    .enum_full, .enum_nonexhaustive => ty.cast(Type.Payload.EnumFull).?.data.values,
                    .enum_numbered => ty.castTag(.enum_numbered).?.data.values,
                    .enum_simple => Module.EnumFull.ValueMap{},
                    else => unreachable,
                };
                if (values.entries.len == 0) {
                    // auto-numbered enum
                    break :field_index @intCast(u32, val.toUnsignedInt(mod.getTarget()));
                }
                var buffer: Type.Payload.Bits = undefined;
                const int_tag_ty = ty.intTagType(&buffer);
                break :field_index @intCast(u32, values.getIndexContext(val, .{ .ty = int_tag_ty, .mod = mod }).?);
            },
        };

        const fields = switch (ty.tag()) {
            .enum_full, .enum_nonexhaustive => ty.cast(Type.Payload.EnumFull).?.data.fields,
            .enum_numbered => ty.castTag(.enum_numbered).?.data.fields,
            .enum_simple => ty.castTag(.enum_simple).?.data.fields,
            else => unreachable,
        };
        return fields.keys()[field_index];
    }

    /// Asserts the value is an integer.
    pub fn toBigInt(val: Value, space: *BigIntSpace, target: Target) BigIntConst {
        return val.toBigIntAdvanced(space, target, null) catch unreachable;
    }

    /// Asserts the value is an integer.
    pub fn toBigIntAdvanced(
        val: Value,
        space: *BigIntSpace,
        target: Target,
        opt_sema: ?*Sema,
    ) Module.CompileError!BigIntConst {
        switch (val.tag()) {
            .null_value,
            .zero,
            .bool_false,
            .the_only_possible_value, // i0, u0
            => return BigIntMutable.init(&space.limbs, 0).toConst(),

            .one,
            .bool_true,
            => return BigIntMutable.init(&space.limbs, 1).toConst(),

            .enum_field_index => {
                const index = val.castTag(.enum_field_index).?.data;
                return BigIntMutable.init(&space.limbs, index).toConst();
            },
            .runtime_value => {
                const sub_val = val.castTag(.runtime_value).?.data;
                return sub_val.toBigIntAdvanced(space, target, opt_sema);
            },
            .int_u64 => return BigIntMutable.init(&space.limbs, val.castTag(.int_u64).?.data).toConst(),
            .int_i64 => return BigIntMutable.init(&space.limbs, val.castTag(.int_i64).?.data).toConst(),
            .int_big_positive => return val.castTag(.int_big_positive).?.asBigInt(),
            .int_big_negative => return val.castTag(.int_big_negative).?.asBigInt(),

            .undef => unreachable,

            .lazy_align => {
                const ty = val.castTag(.lazy_align).?.data;
                if (opt_sema) |sema| {
                    try sema.resolveTypeLayout(ty);
                }
                const x = ty.abiAlignment(target);
                return BigIntMutable.init(&space.limbs, x).toConst();
            },
            .lazy_size => {
                const ty = val.castTag(.lazy_size).?.data;
                if (opt_sema) |sema| {
                    try sema.resolveTypeLayout(ty);
                }
                const x = ty.abiSize(target);
                return BigIntMutable.init(&space.limbs, x).toConst();
            },

            .elem_ptr => {
                const elem_ptr = val.castTag(.elem_ptr).?.data;
                const array_addr = (try elem_ptr.array_ptr.getUnsignedIntAdvanced(target, opt_sema)).?;
                const elem_size = elem_ptr.elem_ty.abiSize(target);
                const new_addr = array_addr + elem_size * elem_ptr.index;
                return BigIntMutable.init(&space.limbs, new_addr).toConst();
            },

            else => unreachable,
        }
    }

    /// If the value fits in a u64, return it, otherwise null.
    /// Asserts not undefined.
    pub fn getUnsignedInt(val: Value, target: Target) ?u64 {
        return getUnsignedIntAdvanced(val, target, null) catch unreachable;
    }

    /// If the value fits in a u64, return it, otherwise null.
    /// Asserts not undefined.
    pub fn getUnsignedIntAdvanced(val: Value, target: Target, opt_sema: ?*Sema) !?u64 {
        switch (val.tag()) {
            .zero,
            .bool_false,
            .the_only_possible_value, // i0, u0
            => return 0,

            .one,
            .bool_true,
            => return 1,

            .int_u64 => return val.castTag(.int_u64).?.data,
            .int_i64 => return @intCast(u64, val.castTag(.int_i64).?.data),
            .int_big_positive => return val.castTag(.int_big_positive).?.asBigInt().to(u64) catch null,
            .int_big_negative => return val.castTag(.int_big_negative).?.asBigInt().to(u64) catch null,

            .undef => unreachable,

            .lazy_align => {
                const ty = val.castTag(.lazy_align).?.data;
                if (opt_sema) |sema| {
                    return (try ty.abiAlignmentAdvanced(target, .{ .sema = sema })).scalar;
                } else {
                    return ty.abiAlignment(target);
                }
            },
            .lazy_size => {
                const ty = val.castTag(.lazy_size).?.data;
                if (opt_sema) |sema| {
                    return (try ty.abiSizeAdvanced(target, .{ .sema = sema })).scalar;
                } else {
                    return ty.abiSize(target);
                }
            },

            else => return null,
        }
    }

    /// Asserts the value is an integer and it fits in a u64
    pub fn toUnsignedInt(val: Value, target: Target) u64 {
        return getUnsignedInt(val, target).?;
    }

    /// Asserts the value is an integer and it fits in a i64
    pub fn toSignedInt(val: Value, target: Target) i64 {
        switch (val.tag()) {
            .zero,
            .bool_false,
            .the_only_possible_value, // i0, u0
            => return 0,

            .one,
            .bool_true,
            => return 1,

            .int_u64 => return @intCast(i64, val.castTag(.int_u64).?.data),
            .int_i64 => return val.castTag(.int_i64).?.data,
            .int_big_positive => return val.castTag(.int_big_positive).?.asBigInt().to(i64) catch unreachable,
            .int_big_negative => return val.castTag(.int_big_negative).?.asBigInt().to(i64) catch unreachable,

            .lazy_align => {
                const ty = val.castTag(.lazy_align).?.data;
                return @intCast(i64, ty.abiAlignment(target));
            },
            .lazy_size => {
                const ty = val.castTag(.lazy_size).?.data;
                return @intCast(i64, ty.abiSize(target));
            },

            .undef => unreachable,
            else => unreachable,
        }
    }

    pub fn toBool(self: Value) bool {
        return switch (self.tag()) {
            .bool_true, .one => true,
            .bool_false, .zero => false,
            .int_u64 => switch (self.castTag(.int_u64).?.data) {
                0 => false,
                1 => true,
                else => unreachable,
            },
            .int_i64 => switch (self.castTag(.int_i64).?.data) {
                0 => false,
                1 => true,
                else => unreachable,
            },
            else => unreachable,
        };
    }

    fn isDeclRef(val: Value) bool {
        var check = val;
        while (true) switch (check.tag()) {
            .variable, .decl_ref, .decl_ref_mut, .comptime_field_ptr => return true,
            .field_ptr => check = check.castTag(.field_ptr).?.data.container_ptr,
            .elem_ptr => check = check.castTag(.elem_ptr).?.data.array_ptr,
            .eu_payload_ptr, .opt_payload_ptr => check = check.cast(Value.Payload.PayloadPtr).?.data.container_ptr,
            else => return false,
        };
    }

    /// Write a Value's contents to `buffer`.
    ///
    /// Asserts that buffer.len >= ty.abiSize(). The buffer is allowed to extend past
    /// the end of the value in memory.
    pub fn writeToMemory(val: Value, ty: Type, mod: *Module, buffer: []u8) error{ReinterpretDeclRef}!void {
        const target = mod.getTarget();
        const endian = target.cpu.arch.endian();
        if (val.isUndef()) {
            const size = @intCast(usize, ty.abiSize(target));
            std.mem.set(u8, buffer[0..size], 0xaa);
            return;
        }
        switch (ty.zigTypeTag()) {
            .Void => {},
            .Bool => {
                buffer[0] = @boolToInt(val.toBool());
            },
            .Int, .Enum => {
                const int_info = ty.intInfo(target);
                const bits = int_info.bits;
                const byte_count = (bits + 7) / 8;

                var enum_buffer: Payload.U64 = undefined;
                const int_val = val.enumToInt(ty, &enum_buffer);

                if (byte_count <= @sizeOf(u64)) {
                    const int: u64 = switch (int_val.tag()) {
                        .zero => 0,
                        .one => 1,
                        .int_u64 => int_val.castTag(.int_u64).?.data,
                        .int_i64 => @bitCast(u64, int_val.castTag(.int_i64).?.data),
                        else => unreachable,
                    };
                    for (buffer[0..byte_count], 0..) |_, i| switch (endian) {
                        .Little => buffer[i] = @truncate(u8, (int >> @intCast(u6, (8 * i)))),
                        .Big => buffer[byte_count - i - 1] = @truncate(u8, (int >> @intCast(u6, (8 * i)))),
                    };
                } else {
                    var bigint_buffer: BigIntSpace = undefined;
                    const bigint = int_val.toBigInt(&bigint_buffer, target);
                    bigint.writeTwosComplement(buffer[0..byte_count], endian);
                }
            },
            .Float => switch (ty.floatBits(target)) {
                16 => std.mem.writeInt(u16, buffer[0..2], @bitCast(u16, val.toFloat(f16)), endian),
                32 => std.mem.writeInt(u32, buffer[0..4], @bitCast(u32, val.toFloat(f32)), endian),
                64 => std.mem.writeInt(u64, buffer[0..8], @bitCast(u64, val.toFloat(f64)), endian),
                80 => std.mem.writeInt(u80, buffer[0..10], @bitCast(u80, val.toFloat(f80)), endian),
                128 => std.mem.writeInt(u128, buffer[0..16], @bitCast(u128, val.toFloat(f128)), endian),
                else => unreachable,
            },
            .Array => {
                const len = ty.arrayLen();
                const elem_ty = ty.childType();
                const elem_size = @intCast(usize, elem_ty.abiSize(target));
                var elem_i: usize = 0;
                var elem_value_buf: ElemValueBuffer = undefined;
                var buf_off: usize = 0;
                while (elem_i < len) : (elem_i += 1) {
                    const elem_val = val.elemValueBuffer(mod, elem_i, &elem_value_buf);
                    try elem_val.writeToMemory(elem_ty, mod, buffer[buf_off..]);
                    buf_off += elem_size;
                }
            },
            .Vector => {
                // We use byte_count instead of abi_size here, so that any padding bytes
                // follow the data bytes, on both big- and little-endian systems.
                const byte_count = (@intCast(usize, ty.bitSize(target)) + 7) / 8;
                return writeToPackedMemory(val, ty, mod, buffer[0..byte_count], 0);
            },
            .Struct => switch (ty.containerLayout()) {
                .Auto => unreachable, // Sema is supposed to have emitted a compile error already
                .Extern => {
                    const fields = ty.structFields().values();
                    const field_vals = val.castTag(.aggregate).?.data;
                    for (fields, 0..) |field, i| {
                        const off = @intCast(usize, ty.structFieldOffset(i, target));
                        try writeToMemory(field_vals[i], field.ty, mod, buffer[off..]);
                    }
                },
                .Packed => {
                    const byte_count = (@intCast(usize, ty.bitSize(target)) + 7) / 8;
                    return writeToPackedMemory(val, ty, mod, buffer[0..byte_count], 0);
                },
            },
            .ErrorSet => {
                // TODO revisit this when we have the concept of the error tag type
                const Int = u16;
                const int = mod.global_error_set.get(val.castTag(.@"error").?.data.name).?;
                std.mem.writeInt(Int, buffer[0..@sizeOf(Int)], @intCast(Int, int), endian);
            },
            .Union => switch (ty.containerLayout()) {
                .Auto => unreachable,
                .Extern => @panic("TODO implement writeToMemory for extern unions"),
                .Packed => {
                    const byte_count = (@intCast(usize, ty.bitSize(target)) + 7) / 8;
                    return writeToPackedMemory(val, ty, mod, buffer[0..byte_count], 0);
                },
            },
            .Pointer => {
                assert(!ty.isSlice()); // No well defined layout.
                if (val.isDeclRef()) return error.ReinterpretDeclRef;
                return val.writeToMemory(Type.usize, mod, buffer);
            },
            .Optional => {
                assert(ty.isPtrLikeOptional());
                var buf: Type.Payload.ElemType = undefined;
                const child = ty.optionalChild(&buf);
                const opt_val = val.optionalValue();
                if (opt_val) |some| {
                    return some.writeToMemory(child, mod, buffer);
                } else {
                    return writeToMemory(Value.zero, Type.usize, mod, buffer);
                }
            },
            else => @panic("TODO implement writeToMemory for more types"),
        }
    }

    /// Write a Value's contents to `buffer`.
    ///
    /// Both the start and the end of the provided buffer must be tight, since
    /// big-endian packed memory layouts start at the end of the buffer.
    pub fn writeToPackedMemory(val: Value, ty: Type, mod: *Module, buffer: []u8, bit_offset: usize) error{ReinterpretDeclRef}!void {
        const target = mod.getTarget();
        const endian = target.cpu.arch.endian();
        if (val.isUndef()) {
            const bit_size = @intCast(usize, ty.bitSize(target));
            std.mem.writeVarPackedInt(buffer, bit_offset, bit_size, @as(u1, 0), endian);
            return;
        }
        switch (ty.zigTypeTag()) {
            .Void => {},
            .Bool => {
                const byte_index = switch (endian) {
                    .Little => bit_offset / 8,
                    .Big => buffer.len - bit_offset / 8 - 1,
                };
                if (val.toBool()) {
                    buffer[byte_index] |= (@as(u8, 1) << @intCast(u3, bit_offset % 8));
                } else {
                    buffer[byte_index] &= ~(@as(u8, 1) << @intCast(u3, bit_offset % 8));
                }
            },
            .Int, .Enum => {
                const bits = ty.intInfo(target).bits;
                const abi_size = @intCast(usize, ty.abiSize(target));

                var enum_buffer: Payload.U64 = undefined;
                const int_val = val.enumToInt(ty, &enum_buffer);

                if (abi_size == 0) return;
                if (abi_size <= @sizeOf(u64)) {
                    const int: u64 = switch (int_val.tag()) {
                        .zero => 0,
                        .one => 1,
                        .int_u64 => int_val.castTag(.int_u64).?.data,
                        .int_i64 => @bitCast(u64, int_val.castTag(.int_i64).?.data),
                        else => unreachable,
                    };
                    std.mem.writeVarPackedInt(buffer, bit_offset, bits, int, endian);
                } else {
                    var bigint_buffer: BigIntSpace = undefined;
                    const bigint = int_val.toBigInt(&bigint_buffer, target);
                    bigint.writePackedTwosComplement(buffer, bit_offset, bits, endian);
                }
            },
            .Float => switch (ty.floatBits(target)) {
                16 => std.mem.writePackedInt(u16, buffer, bit_offset, @bitCast(u16, val.toFloat(f16)), endian),
                32 => std.mem.writePackedInt(u32, buffer, bit_offset, @bitCast(u32, val.toFloat(f32)), endian),
                64 => std.mem.writePackedInt(u64, buffer, bit_offset, @bitCast(u64, val.toFloat(f64)), endian),
                80 => std.mem.writePackedInt(u80, buffer, bit_offset, @bitCast(u80, val.toFloat(f80)), endian),
                128 => std.mem.writePackedInt(u128, buffer, bit_offset, @bitCast(u128, val.toFloat(f128)), endian),
                else => unreachable,
            },
            .Vector => {
                const elem_ty = ty.childType();
                const elem_bit_size = @intCast(u16, elem_ty.bitSize(target));
                const len = @intCast(usize, ty.arrayLen());

                var bits: u16 = 0;
                var elem_i: usize = 0;
                var elem_value_buf: ElemValueBuffer = undefined;
                while (elem_i < len) : (elem_i += 1) {
                    // On big-endian systems, LLVM reverses the element order of vectors by default
                    const tgt_elem_i = if (endian == .Big) len - elem_i - 1 else elem_i;
                    const elem_val = val.elemValueBuffer(mod, tgt_elem_i, &elem_value_buf);
                    try elem_val.writeToPackedMemory(elem_ty, mod, buffer, bit_offset + bits);
                    bits += elem_bit_size;
                }
            },
            .Struct => switch (ty.containerLayout()) {
                .Auto => unreachable, // Sema is supposed to have emitted a compile error already
                .Extern => unreachable, // Handled in non-packed writeToMemory
                .Packed => {
                    var bits: u16 = 0;
                    const fields = ty.structFields().values();
                    const field_vals = val.castTag(.aggregate).?.data;
                    for (fields, 0..) |field, i| {
                        const field_bits = @intCast(u16, field.ty.bitSize(target));
                        try field_vals[i].writeToPackedMemory(field.ty, mod, buffer, bit_offset + bits);
                        bits += field_bits;
                    }
                },
            },
            .Union => switch (ty.containerLayout()) {
                .Auto => unreachable, // Sema is supposed to have emitted a compile error already
                .Extern => unreachable, // Handled in non-packed writeToMemory
                .Packed => {
                    const field_index = ty.unionTagFieldIndex(val.unionTag(), mod);
                    const field_type = ty.unionFields().values()[field_index.?].ty;
                    const field_val = val.fieldValue(field_type, field_index.?);

                    return field_val.writeToPackedMemory(field_type, mod, buffer, bit_offset);
                },
            },
            .Pointer => {
                assert(!ty.isSlice()); // No well defined layout.
                if (val.isDeclRef()) return error.ReinterpretDeclRef;
                return val.writeToPackedMemory(Type.usize, mod, buffer, bit_offset);
            },
            .Optional => {
                assert(ty.isPtrLikeOptional());
                var buf: Type.Payload.ElemType = undefined;
                const child = ty.optionalChild(&buf);
                const opt_val = val.optionalValue();
                if (opt_val) |some| {
                    return some.writeToPackedMemory(child, mod, buffer, bit_offset);
                } else {
                    return writeToPackedMemory(Value.zero, Type.usize, mod, buffer, bit_offset);
                }
            },
            else => @panic("TODO implement writeToPackedMemory for more types"),
        }
    }

    /// Load a Value from the contents of `buffer`.
    ///
    /// Asserts that buffer.len >= ty.abiSize(). The buffer is allowed to extend past
    /// the end of the value in memory.
    pub fn readFromMemory(
        ty: Type,
        mod: *Module,
        buffer: []const u8,
        arena: Allocator,
    ) Allocator.Error!Value {
        const target = mod.getTarget();
        const endian = target.cpu.arch.endian();
        switch (ty.zigTypeTag()) {
            .Void => return Value.void,
            .Bool => {
                if (buffer[0] == 0) {
                    return Value.false;
                } else {
                    return Value.true;
                }
            },
            .Int, .Enum => {
                const int_info = ty.intInfo(target);
                const bits = int_info.bits;
                const byte_count = (bits + 7) / 8;
                if (bits == 0 or buffer.len == 0) return Value.zero;

                if (bits <= 64) switch (int_info.signedness) { // Fast path for integers <= u64
                    .signed => {
                        const val = std.mem.readVarInt(i64, buffer[0..byte_count], endian);
                        return Value.Tag.int_i64.create(arena, (val << @intCast(u6, 64 - bits)) >> @intCast(u6, 64 - bits));
                    },
                    .unsigned => {
                        const val = std.mem.readVarInt(u64, buffer[0..byte_count], endian);
                        return Value.Tag.int_u64.create(arena, (val << @intCast(u6, 64 - bits)) >> @intCast(u6, 64 - bits));
                    },
                } else { // Slow path, we have to construct a big-int
                    const Limb = std.math.big.Limb;
                    const limb_count = (byte_count + @sizeOf(Limb) - 1) / @sizeOf(Limb);
                    const limbs_buffer = try arena.alloc(Limb, limb_count);

                    var bigint = BigIntMutable.init(limbs_buffer, 0);
                    bigint.readTwosComplement(buffer[0..byte_count], bits, endian, int_info.signedness);
                    return fromBigInt(arena, bigint.toConst());
                }
            },
            .Float => switch (ty.floatBits(target)) {
                16 => return Value.Tag.float_16.create(arena, @bitCast(f16, std.mem.readInt(u16, buffer[0..2], endian))),
                32 => return Value.Tag.float_32.create(arena, @bitCast(f32, std.mem.readInt(u32, buffer[0..4], endian))),
                64 => return Value.Tag.float_64.create(arena, @bitCast(f64, std.mem.readInt(u64, buffer[0..8], endian))),
                80 => return Value.Tag.float_80.create(arena, @bitCast(f80, std.mem.readInt(u80, buffer[0..10], endian))),
                128 => return Value.Tag.float_128.create(arena, @bitCast(f128, std.mem.readInt(u128, buffer[0..16], endian))),
                else => unreachable,
            },
            .Array => {
                const elem_ty = ty.childType();
                const elem_size = elem_ty.abiSize(target);
                const elems = try arena.alloc(Value, @intCast(usize, ty.arrayLen()));
                var offset: usize = 0;
                for (elems) |*elem| {
                    elem.* = try readFromMemory(elem_ty, mod, buffer[offset..], arena);
                    offset += @intCast(usize, elem_size);
                }
                return Tag.aggregate.create(arena, elems);
            },
            .Vector => {
                // We use byte_count instead of abi_size here, so that any padding bytes
                // follow the data bytes, on both big- and little-endian systems.
                const byte_count = (@intCast(usize, ty.bitSize(target)) + 7) / 8;
                return readFromPackedMemory(ty, mod, buffer[0..byte_count], 0, arena);
            },
            .Struct => switch (ty.containerLayout()) {
                .Auto => unreachable, // Sema is supposed to have emitted a compile error already
                .Extern => {
                    const fields = ty.structFields().values();
                    const field_vals = try arena.alloc(Value, fields.len);
                    for (fields, 0..) |field, i| {
                        const off = @intCast(usize, ty.structFieldOffset(i, target));
                        const sz = @intCast(usize, ty.structFieldType(i).abiSize(target));
                        field_vals[i] = try readFromMemory(field.ty, mod, buffer[off..(off + sz)], arena);
                    }
                    return Tag.aggregate.create(arena, field_vals);
                },
                .Packed => {
                    const byte_count = (@intCast(usize, ty.bitSize(target)) + 7) / 8;
                    return readFromPackedMemory(ty, mod, buffer[0..byte_count], 0, arena);
                },
            },
            .ErrorSet => {
                // TODO revisit this when we have the concept of the error tag type
                const Int = u16;
                const int = std.mem.readInt(Int, buffer[0..@sizeOf(Int)], endian);

                const payload = try arena.create(Value.Payload.Error);
                payload.* = .{
                    .base = .{ .tag = .@"error" },
                    .data = .{ .name = mod.error_name_list.items[@intCast(usize, int)] },
                };
                return Value.initPayload(&payload.base);
            },
            .Pointer => {
                assert(!ty.isSlice()); // No well defined layout.
                return readFromMemory(Type.usize, mod, buffer, arena);
            },
            .Optional => {
                assert(ty.isPtrLikeOptional());
                var buf: Type.Payload.ElemType = undefined;
                const child = ty.optionalChild(&buf);
                return readFromMemory(child, mod, buffer, arena);
            },
            else => @panic("TODO implement readFromMemory for more types"),
        }
    }

    /// Load a Value from the contents of `buffer`.
    ///
    /// Both the start and the end of the provided buffer must be tight, since
    /// big-endian packed memory layouts start at the end of the buffer.
    pub fn readFromPackedMemory(
        ty: Type,
        mod: *Module,
        buffer: []const u8,
        bit_offset: usize,
        arena: Allocator,
    ) Allocator.Error!Value {
        const target = mod.getTarget();
        const endian = target.cpu.arch.endian();
        switch (ty.zigTypeTag()) {
            .Void => return Value.void,
            .Bool => {
                const byte = switch (endian) {
                    .Big => buffer[buffer.len - bit_offset / 8 - 1],
                    .Little => buffer[bit_offset / 8],
                };
                if (((byte >> @intCast(u3, bit_offset % 8)) & 1) == 0) {
                    return Value.false;
                } else {
                    return Value.true;
                }
            },
            .Int, .Enum => {
                if (buffer.len == 0) return Value.zero;
                const int_info = ty.intInfo(target);
                const abi_size = @intCast(usize, ty.abiSize(target));

                const bits = int_info.bits;
                if (bits == 0) return Value.zero;
                if (bits <= 64) switch (int_info.signedness) { // Fast path for integers <= u64
                    .signed => return Value.Tag.int_i64.create(arena, std.mem.readVarPackedInt(i64, buffer, bit_offset, bits, endian, .signed)),
                    .unsigned => return Value.Tag.int_u64.create(arena, std.mem.readVarPackedInt(u64, buffer, bit_offset, bits, endian, .unsigned)),
                } else { // Slow path, we have to construct a big-int
                    const Limb = std.math.big.Limb;
                    const limb_count = (abi_size + @sizeOf(Limb) - 1) / @sizeOf(Limb);
                    const limbs_buffer = try arena.alloc(Limb, limb_count);

                    var bigint = BigIntMutable.init(limbs_buffer, 0);
                    bigint.readPackedTwosComplement(buffer, bit_offset, bits, endian, int_info.signedness);
                    return fromBigInt(arena, bigint.toConst());
                }
            },
            .Float => switch (ty.floatBits(target)) {
                16 => return Value.Tag.float_16.create(arena, @bitCast(f16, std.mem.readPackedInt(u16, buffer, bit_offset, endian))),
                32 => return Value.Tag.float_32.create(arena, @bitCast(f32, std.mem.readPackedInt(u32, buffer, bit_offset, endian))),
                64 => return Value.Tag.float_64.create(arena, @bitCast(f64, std.mem.readPackedInt(u64, buffer, bit_offset, endian))),
                80 => return Value.Tag.float_80.create(arena, @bitCast(f80, std.mem.readPackedInt(u80, buffer, bit_offset, endian))),
                128 => return Value.Tag.float_128.create(arena, @bitCast(f128, std.mem.readPackedInt(u128, buffer, bit_offset, endian))),
                else => unreachable,
            },
            .Vector => {
                const elem_ty = ty.childType();
                const elems = try arena.alloc(Value, @intCast(usize, ty.arrayLen()));

                var bits: u16 = 0;
                const elem_bit_size = @intCast(u16, elem_ty.bitSize(target));
                for (elems, 0..) |_, i| {
                    // On big-endian systems, LLVM reverses the element order of vectors by default
                    const tgt_elem_i = if (endian == .Big) elems.len - i - 1 else i;
                    elems[tgt_elem_i] = try readFromPackedMemory(elem_ty, mod, buffer, bit_offset + bits, arena);
                    bits += elem_bit_size;
                }
                return Tag.aggregate.create(arena, elems);
            },
            .Struct => switch (ty.containerLayout()) {
                .Auto => unreachable, // Sema is supposed to have emitted a compile error already
                .Extern => unreachable, // Handled by non-packed readFromMemory
                .Packed => {
                    var bits: u16 = 0;
                    const fields = ty.structFields().values();
                    const field_vals = try arena.alloc(Value, fields.len);
                    for (fields, 0..) |field, i| {
                        const field_bits = @intCast(u16, field.ty.bitSize(target));
                        field_vals[i] = try readFromPackedMemory(field.ty, mod, buffer, bit_offset + bits, arena);
                        bits += field_bits;
                    }
                    return Tag.aggregate.create(arena, field_vals);
                },
            },
            .Pointer => {
                assert(!ty.isSlice()); // No well defined layout.
                return readFromPackedMemory(Type.usize, mod, buffer, bit_offset, arena);
            },
            .Optional => {
                assert(ty.isPtrLikeOptional());
                var buf: Type.Payload.ElemType = undefined;
                const child = ty.optionalChild(&buf);
                return readFromPackedMemory(child, mod, buffer, bit_offset, arena);
            },
            else => @panic("TODO implement readFromPackedMemory for more types"),
        }
    }

    /// Asserts that the value is a float or an integer.
    pub fn toFloat(val: Value, comptime T: type) T {
        return switch (val.tag()) {
            .float_16 => @floatCast(T, val.castTag(.float_16).?.data),
            .float_32 => @floatCast(T, val.castTag(.float_32).?.data),
            .float_64 => @floatCast(T, val.castTag(.float_64).?.data),
            .float_80 => @floatCast(T, val.castTag(.float_80).?.data),
            .float_128 => @floatCast(T, val.castTag(.float_128).?.data),

            .zero => 0,
            .one => 1,
            .int_u64 => {
                if (T == f80) {
                    @panic("TODO we can't lower this properly on non-x86 llvm backend yet");
                }
                return @intToFloat(T, val.castTag(.int_u64).?.data);
            },
            .int_i64 => {
                if (T == f80) {
                    @panic("TODO we can't lower this properly on non-x86 llvm backend yet");
                }
                return @intToFloat(T, val.castTag(.int_i64).?.data);
            },

            .int_big_positive => @floatCast(T, bigIntToFloat(val.castTag(.int_big_positive).?.data, true)),
            .int_big_negative => @floatCast(T, bigIntToFloat(val.castTag(.int_big_negative).?.data, false)),
            else => unreachable,
        };
    }

    /// TODO move this to std lib big int code
    fn bigIntToFloat(limbs: []const std.math.big.Limb, positive: bool) f128 {
        if (limbs.len == 0) return 0;

        const base = std.math.maxInt(std.math.big.Limb) + 1;
        var result: f128 = 0;
        var i: usize = limbs.len;
        while (i != 0) {
            i -= 1;
            const limb: f128 = @intToFloat(f128, limbs[i]);
            result = @mulAdd(f128, base, result, limb);
        }
        if (positive) {
            return result;
        } else {
            return -result;
        }
    }

    pub fn clz(val: Value, ty: Type, target: Target) u64 {
        const ty_bits = ty.intInfo(target).bits;
        switch (val.tag()) {
            .zero, .bool_false => return ty_bits,
            .one, .bool_true => return ty_bits - 1,

            .int_u64 => {
                const big = @clz(val.castTag(.int_u64).?.data);
                return big + ty_bits - 64;
            },
            .int_i64 => {
                @panic("TODO implement i64 Value clz");
            },
            .int_big_positive => {
                const bigint = val.castTag(.int_big_positive).?.asBigInt();
                return bigint.clz(ty_bits);
            },
            .int_big_negative => {
                @panic("TODO implement int_big_negative Value clz");
            },

            .the_only_possible_value => {
                assert(ty_bits == 0);
                return ty_bits;
            },

            .lazy_align, .lazy_size => {
                var bigint_buf: BigIntSpace = undefined;
                const bigint = val.toBigIntAdvanced(&bigint_buf, target, null) catch unreachable;
                return bigint.clz(ty_bits);
            },

            else => unreachable,
        }
    }

    pub fn ctz(val: Value, ty: Type, target: Target) u64 {
        const ty_bits = ty.intInfo(target).bits;
        switch (val.tag()) {
            .zero, .bool_false => return ty_bits,
            .one, .bool_true => return 0,

            .int_u64 => {
                const big = @ctz(val.castTag(.int_u64).?.data);
                return if (big == 64) ty_bits else big;
            },
            .int_i64 => {
                @panic("TODO implement i64 Value ctz");
            },
            .int_big_positive => {
                const bigint = val.castTag(.int_big_positive).?.asBigInt();
                return bigint.ctz();
            },
            .int_big_negative => {
                @panic("TODO implement int_big_negative Value ctz");
            },

            .the_only_possible_value => {
                assert(ty_bits == 0);
                return ty_bits;
            },

            .lazy_align, .lazy_size => {
                var bigint_buf: BigIntSpace = undefined;
                const bigint = val.toBigIntAdvanced(&bigint_buf, target, null) catch unreachable;
                return bigint.ctz();
            },

            else => unreachable,
        }
    }

    pub fn popCount(val: Value, ty: Type, target: Target) u64 {
        assert(!val.isUndef());
        switch (val.tag()) {
            .zero, .bool_false => return 0,
            .one, .bool_true => return 1,

            .int_u64 => return @popCount(val.castTag(.int_u64).?.data),

            else => {
                const info = ty.intInfo(target);

                var buffer: Value.BigIntSpace = undefined;
                const int = val.toBigInt(&buffer, target);
                return @intCast(u64, int.popCount(info.bits));
            },
        }
    }

    pub fn bitReverse(val: Value, ty: Type, target: Target, arena: Allocator) !Value {
        assert(!val.isUndef());

        const info = ty.intInfo(target);

        var buffer: Value.BigIntSpace = undefined;
        const operand_bigint = val.toBigInt(&buffer, target);

        const limbs = try arena.alloc(
            std.math.big.Limb,
            std.math.big.int.calcTwosCompLimbCount(info.bits),
        );
        var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
        result_bigint.bitReverse(operand_bigint, info.signedness, info.bits);

        return fromBigInt(arena, result_bigint.toConst());
    }

    pub fn byteSwap(val: Value, ty: Type, target: Target, arena: Allocator) !Value {
        assert(!val.isUndef());

        const info = ty.intInfo(target);

        // Bit count must be evenly divisible by 8
        assert(info.bits % 8 == 0);

        var buffer: Value.BigIntSpace = undefined;
        const operand_bigint = val.toBigInt(&buffer, target);

        const limbs = try arena.alloc(
            std.math.big.Limb,
            std.math.big.int.calcTwosCompLimbCount(info.bits),
        );
        var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
        result_bigint.byteSwap(operand_bigint, info.signedness, info.bits / 8);

        return fromBigInt(arena, result_bigint.toConst());
    }

    /// Asserts the value is an integer and not undefined.
    /// Returns the number of bits the value requires to represent stored in twos complement form.
    pub fn intBitCountTwosComp(self: Value, target: Target) usize {
        switch (self.tag()) {
            .zero,
            .bool_false,
            .the_only_possible_value,
            => return 0,

            .one,
            .bool_true,
            => return 1,

            .int_u64 => {
                const x = self.castTag(.int_u64).?.data;
                if (x == 0) return 0;
                return @intCast(usize, std.math.log2(x) + 1);
            },
            .int_big_positive => return self.castTag(.int_big_positive).?.asBigInt().bitCountTwosComp(),
            .int_big_negative => return self.castTag(.int_big_negative).?.asBigInt().bitCountTwosComp(),

            .decl_ref_mut,
            .comptime_field_ptr,
            .extern_fn,
            .decl_ref,
            .function,
            .variable,
            .eu_payload_ptr,
            .opt_payload_ptr,
            => return target.cpu.arch.ptrBitWidth(),

            else => {
                var buffer: BigIntSpace = undefined;
                return self.toBigInt(&buffer, target).bitCountTwosComp();
            },
        }
    }

    /// Converts an integer or a float to a float. May result in a loss of information.
    /// Caller can find out by equality checking the result against the operand.
    pub fn floatCast(self: Value, arena: Allocator, dest_ty: Type, target: Target) !Value {
        switch (dest_ty.floatBits(target)) {
            16 => return Value.Tag.float_16.create(arena, self.toFloat(f16)),
            32 => return Value.Tag.float_32.create(arena, self.toFloat(f32)),
            64 => return Value.Tag.float_64.create(arena, self.toFloat(f64)),
            80 => return Value.Tag.float_80.create(arena, self.toFloat(f80)),
            128 => return Value.Tag.float_128.create(arena, self.toFloat(f128)),
            else => unreachable,
        }
    }

    /// Asserts the value is a float
    pub fn floatHasFraction(self: Value) bool {
        return switch (self.tag()) {
            .zero,
            .one,
            => false,

            .float_16 => @rem(self.castTag(.float_16).?.data, 1) != 0,
            .float_32 => @rem(self.castTag(.float_32).?.data, 1) != 0,
            .float_64 => @rem(self.castTag(.float_64).?.data, 1) != 0,
            //.float_80 => @rem(self.castTag(.float_80).?.data, 1) != 0,
            .float_80 => @panic("TODO implement __remx in compiler-rt"),
            .float_128 => @rem(self.castTag(.float_128).?.data, 1) != 0,

            else => unreachable,
        };
    }

    pub fn orderAgainstZero(lhs: Value) std.math.Order {
        return orderAgainstZeroAdvanced(lhs, null) catch unreachable;
    }

    pub fn orderAgainstZeroAdvanced(
        lhs: Value,
        opt_sema: ?*Sema,
    ) Module.CompileError!std.math.Order {
        return switch (lhs.tag()) {
            .zero,
            .bool_false,
            .the_only_possible_value,
            => .eq,

            .one,
            .bool_true,
            .decl_ref,
            .decl_ref_mut,
            .comptime_field_ptr,
            .extern_fn,
            .function,
            .variable,
            => .gt,

            .enum_field_index => return std.math.order(lhs.castTag(.enum_field_index).?.data, 0),
            .runtime_value => {
                // This is needed to correctly handle hashing the value.
                // Checks in Sema should prevent direct comparisons from reaching here.
                const val = lhs.castTag(.runtime_value).?.data;
                return val.orderAgainstZeroAdvanced(opt_sema);
            },
            .int_u64 => std.math.order(lhs.castTag(.int_u64).?.data, 0),
            .int_i64 => std.math.order(lhs.castTag(.int_i64).?.data, 0),
            .int_big_positive => lhs.castTag(.int_big_positive).?.asBigInt().orderAgainstScalar(0),
            .int_big_negative => lhs.castTag(.int_big_negative).?.asBigInt().orderAgainstScalar(0),

            .lazy_align => {
                const ty = lhs.castTag(.lazy_align).?.data;
                const strat: Type.AbiAlignmentAdvancedStrat = if (opt_sema) |sema| .{ .sema = sema } else .eager;
                if (ty.hasRuntimeBitsAdvanced(false, strat) catch |err| switch (err) {
                    error.NeedLazy => unreachable,
                    else => |e| return e,
                }) {
                    return .gt;
                } else {
                    return .eq;
                }
            },
            .lazy_size => {
                const ty = lhs.castTag(.lazy_size).?.data;
                const strat: Type.AbiAlignmentAdvancedStrat = if (opt_sema) |sema| .{ .sema = sema } else .eager;
                if (ty.hasRuntimeBitsAdvanced(false, strat) catch |err| switch (err) {
                    error.NeedLazy => unreachable,
                    else => |e| return e,
                }) {
                    return .gt;
                } else {
                    return .eq;
                }
            },

            .float_16 => std.math.order(lhs.castTag(.float_16).?.data, 0),
            .float_32 => std.math.order(lhs.castTag(.float_32).?.data, 0),
            .float_64 => std.math.order(lhs.castTag(.float_64).?.data, 0),
            .float_80 => std.math.order(lhs.castTag(.float_80).?.data, 0),
            .float_128 => std.math.order(lhs.castTag(.float_128).?.data, 0),

            .elem_ptr => {
                const elem_ptr = lhs.castTag(.elem_ptr).?.data;
                switch (try elem_ptr.array_ptr.orderAgainstZeroAdvanced(opt_sema)) {
                    .lt => unreachable,
                    .gt => return .gt,
                    .eq => {
                        if (elem_ptr.index == 0) {
                            return .eq;
                        } else {
                            return .gt;
                        }
                    },
                }
            },

            else => unreachable,
        };
    }

    /// Asserts the value is comparable.
    pub fn order(lhs: Value, rhs: Value, target: Target) std.math.Order {
        return orderAdvanced(lhs, rhs, target, null) catch unreachable;
    }

    /// Asserts the value is comparable.
    /// If opt_sema is null then this function asserts things are resolved and cannot fail.
    pub fn orderAdvanced(lhs: Value, rhs: Value, target: Target, opt_sema: ?*Sema) !std.math.Order {
        const lhs_tag = lhs.tag();
        const rhs_tag = rhs.tag();
        const lhs_against_zero = try lhs.orderAgainstZeroAdvanced(opt_sema);
        const rhs_against_zero = try rhs.orderAgainstZeroAdvanced(opt_sema);
        switch (lhs_against_zero) {
            .lt => if (rhs_against_zero != .lt) return .lt,
            .eq => return rhs_against_zero.invert(),
            .gt => {},
        }
        switch (rhs_against_zero) {
            .lt => if (lhs_against_zero != .lt) return .gt,
            .eq => return lhs_against_zero,
            .gt => {},
        }

        const lhs_float = lhs.isFloat();
        const rhs_float = rhs.isFloat();
        if (lhs_float and rhs_float) {
            if (lhs_tag == rhs_tag) {
                return switch (lhs.tag()) {
                    .float_16 => return std.math.order(lhs.castTag(.float_16).?.data, rhs.castTag(.float_16).?.data),
                    .float_32 => return std.math.order(lhs.castTag(.float_32).?.data, rhs.castTag(.float_32).?.data),
                    .float_64 => return std.math.order(lhs.castTag(.float_64).?.data, rhs.castTag(.float_64).?.data),
                    .float_80 => return std.math.order(lhs.castTag(.float_80).?.data, rhs.castTag(.float_80).?.data),
                    .float_128 => return std.math.order(lhs.castTag(.float_128).?.data, rhs.castTag(.float_128).?.data),
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
        const lhs_bigint = try lhs.toBigIntAdvanced(&lhs_bigint_space, target, opt_sema);
        const rhs_bigint = try rhs.toBigIntAdvanced(&rhs_bigint_space, target, opt_sema);
        return lhs_bigint.order(rhs_bigint);
    }

    /// Asserts the value is comparable. Does not take a type parameter because it supports
    /// comparisons between heterogeneous types.
    pub fn compareHetero(lhs: Value, op: std.math.CompareOperator, rhs: Value, target: Target) bool {
        return compareHeteroAdvanced(lhs, op, rhs, target, null) catch unreachable;
    }

    pub fn compareHeteroAdvanced(
        lhs: Value,
        op: std.math.CompareOperator,
        rhs: Value,
        target: Target,
        opt_sema: ?*Sema,
    ) !bool {
        if (lhs.pointerDecl()) |lhs_decl| {
            if (rhs.pointerDecl()) |rhs_decl| {
                switch (op) {
                    .eq => return lhs_decl == rhs_decl,
                    .neq => return lhs_decl != rhs_decl,
                    else => {},
                }
            } else {
                switch (op) {
                    .eq => return false,
                    .neq => return true,
                    else => {},
                }
            }
        } else if (rhs.pointerDecl()) |_| {
            switch (op) {
                .eq => return false,
                .neq => return true,
                else => {},
            }
        }
        return (try orderAdvanced(lhs, rhs, target, opt_sema)).compare(op);
    }

    /// Asserts the values are comparable. Both operands have type `ty`.
    /// For vectors, returns true if comparison is true for ALL elements.
    pub fn compareAll(lhs: Value, op: std.math.CompareOperator, rhs: Value, ty: Type, mod: *Module) bool {
        if (ty.zigTypeTag() == .Vector) {
            var i: usize = 0;
            while (i < ty.vectorLen()) : (i += 1) {
                var lhs_buf: Value.ElemValueBuffer = undefined;
                var rhs_buf: Value.ElemValueBuffer = undefined;
                const lhs_elem = lhs.elemValueBuffer(mod, i, &lhs_buf);
                const rhs_elem = rhs.elemValueBuffer(mod, i, &rhs_buf);
                if (!compareScalar(lhs_elem, op, rhs_elem, ty.scalarType(), mod)) {
                    return false;
                }
            }
            return true;
        }
        return compareScalar(lhs, op, rhs, ty, mod);
    }

    /// Asserts the values are comparable. Both operands have type `ty`.
    pub fn compareScalar(
        lhs: Value,
        op: std.math.CompareOperator,
        rhs: Value,
        ty: Type,
        mod: *Module,
    ) bool {
        return switch (op) {
            .eq => lhs.eql(rhs, ty, mod),
            .neq => !lhs.eql(rhs, ty, mod),
            else => compareHetero(lhs, op, rhs, mod.getTarget()),
        };
    }

    /// Asserts the value is comparable.
    /// For vectors, returns true if comparison is true for ALL elements.
    ///
    /// Note that `!compareAllWithZero(.eq, ...) != compareAllWithZero(.neq, ...)`
    pub fn compareAllWithZero(lhs: Value, op: std.math.CompareOperator, mod: *Module) bool {
        return compareAllWithZeroAdvancedExtra(lhs, op, mod, null) catch unreachable;
    }

    pub fn compareAllWithZeroAdvanced(
        lhs: Value,
        op: std.math.CompareOperator,
        sema: *Sema,
    ) Module.CompileError!bool {
        return compareAllWithZeroAdvancedExtra(lhs, op, sema.mod, sema);
    }

    pub fn compareAllWithZeroAdvancedExtra(
        lhs: Value,
        op: std.math.CompareOperator,
        mod: *Module,
        opt_sema: ?*Sema,
    ) Module.CompileError!bool {
        if (lhs.isInf()) {
            switch (op) {
                .neq => return true,
                .eq => return false,
                .gt, .gte => return !lhs.isNegativeInf(),
                .lt, .lte => return lhs.isNegativeInf(),
            }
        }

        switch (lhs.tag()) {
            .repeated => return lhs.castTag(.repeated).?.data.compareAllWithZeroAdvancedExtra(op, mod, opt_sema),
            .aggregate => {
                for (lhs.castTag(.aggregate).?.data) |elem_val| {
                    if (!(try elem_val.compareAllWithZeroAdvancedExtra(op, mod, opt_sema))) return false;
                }
                return true;
            },
            .str_lit => {
                const str_lit = lhs.castTag(.str_lit).?.data;
                const bytes = mod.string_literal_bytes.items[str_lit.index..][0..str_lit.len];
                for (bytes) |byte| {
                    if (!std.math.compare(byte, op, 0)) return false;
                }
                return true;
            },
            .bytes => {
                const bytes = lhs.castTag(.bytes).?.data;
                for (bytes) |byte| {
                    if (!std.math.compare(byte, op, 0)) return false;
                }
                return true;
            },
            .float_16 => if (std.math.isNan(lhs.castTag(.float_16).?.data)) return op == .neq,
            .float_32 => if (std.math.isNan(lhs.castTag(.float_32).?.data)) return op == .neq,
            .float_64 => if (std.math.isNan(lhs.castTag(.float_64).?.data)) return op == .neq,
            .float_80 => if (std.math.isNan(lhs.castTag(.float_80).?.data)) return op == .neq,
            .float_128 => if (std.math.isNan(lhs.castTag(.float_128).?.data)) return op == .neq,
            else => {},
        }
        return (try orderAgainstZeroAdvanced(lhs, opt_sema)).compare(op);
    }

    pub fn eql(a: Value, b: Value, ty: Type, mod: *Module) bool {
        return eqlAdvanced(a, ty, b, ty, mod, null) catch unreachable;
    }

    /// This function is used by hash maps and so treats floating-point NaNs as equal
    /// to each other, and not equal to other floating-point values.
    /// Similarly, it treats `undef` as a distinct value from all other values.
    /// This function has to be able to support implicit coercion of `a` to `ty`. That is,
    /// `ty` will be an exactly correct Type for `b` but it may be a post-coerced Type
    /// for `a`. This function must act *as if* `a` has been coerced to `ty`. This complication
    /// is required in order to make generic function instantiation efficient - specifically
    /// the insertion into the monomorphized function table.
    /// If `null` is provided for `opt_sema` then it is guaranteed no error will be returned.
    pub fn eqlAdvanced(
        a: Value,
        a_ty: Type,
        b: Value,
        ty: Type,
        mod: *Module,
        opt_sema: ?*Sema,
    ) Module.CompileError!bool {
        const target = mod.getTarget();
        const a_tag = a.tag();
        const b_tag = b.tag();
        if (a_tag == b_tag) switch (a_tag) {
            .undef => return true,
            .void_value, .null_value, .the_only_possible_value, .empty_struct_value => return true,
            .enum_literal => {
                const a_name = a.castTag(.enum_literal).?.data;
                const b_name = b.castTag(.enum_literal).?.data;
                return std.mem.eql(u8, a_name, b_name);
            },
            .enum_field_index => {
                const a_field_index = a.castTag(.enum_field_index).?.data;
                const b_field_index = b.castTag(.enum_field_index).?.data;
                return a_field_index == b_field_index;
            },
            .opt_payload => {
                const a_payload = a.castTag(.opt_payload).?.data;
                const b_payload = b.castTag(.opt_payload).?.data;
                var buffer: Type.Payload.ElemType = undefined;
                const payload_ty = ty.optionalChild(&buffer);
                return eqlAdvanced(a_payload, payload_ty, b_payload, payload_ty, mod, opt_sema);
            },
            .slice => {
                const a_payload = a.castTag(.slice).?.data;
                const b_payload = b.castTag(.slice).?.data;
                if (!(try eqlAdvanced(a_payload.len, Type.usize, b_payload.len, Type.usize, mod, opt_sema))) {
                    return false;
                }

                var ptr_buf: Type.SlicePtrFieldTypeBuffer = undefined;
                const ptr_ty = ty.slicePtrFieldType(&ptr_buf);

                return eqlAdvanced(a_payload.ptr, ptr_ty, b_payload.ptr, ptr_ty, mod, opt_sema);
            },
            .elem_ptr => {
                const a_payload = a.castTag(.elem_ptr).?.data;
                const b_payload = b.castTag(.elem_ptr).?.data;
                if (a_payload.index != b_payload.index) return false;

                return eqlAdvanced(a_payload.array_ptr, ty, b_payload.array_ptr, ty, mod, opt_sema);
            },
            .field_ptr => {
                const a_payload = a.castTag(.field_ptr).?.data;
                const b_payload = b.castTag(.field_ptr).?.data;
                if (a_payload.field_index != b_payload.field_index) return false;

                return eqlAdvanced(a_payload.container_ptr, ty, b_payload.container_ptr, ty, mod, opt_sema);
            },
            .@"error" => {
                const a_name = a.castTag(.@"error").?.data.name;
                const b_name = b.castTag(.@"error").?.data.name;
                return std.mem.eql(u8, a_name, b_name);
            },
            .eu_payload => {
                const a_payload = a.castTag(.eu_payload).?.data;
                const b_payload = b.castTag(.eu_payload).?.data;
                const payload_ty = ty.errorUnionPayload();
                return eqlAdvanced(a_payload, payload_ty, b_payload, payload_ty, mod, opt_sema);
            },
            .eu_payload_ptr => {
                const a_payload = a.castTag(.eu_payload_ptr).?.data;
                const b_payload = b.castTag(.eu_payload_ptr).?.data;
                return eqlAdvanced(a_payload.container_ptr, ty, b_payload.container_ptr, ty, mod, opt_sema);
            },
            .opt_payload_ptr => {
                const a_payload = a.castTag(.opt_payload_ptr).?.data;
                const b_payload = b.castTag(.opt_payload_ptr).?.data;
                return eqlAdvanced(a_payload.container_ptr, ty, b_payload.container_ptr, ty, mod, opt_sema);
            },
            .function => {
                const a_payload = a.castTag(.function).?.data;
                const b_payload = b.castTag(.function).?.data;
                return a_payload == b_payload;
            },
            .aggregate => {
                const a_field_vals = a.castTag(.aggregate).?.data;
                const b_field_vals = b.castTag(.aggregate).?.data;
                assert(a_field_vals.len == b_field_vals.len);

                if (ty.isSimpleTupleOrAnonStruct()) {
                    const types = ty.tupleFields().types;
                    assert(types.len == a_field_vals.len);
                    for (types, 0..) |field_ty, i| {
                        if (!(try eqlAdvanced(a_field_vals[i], field_ty, b_field_vals[i], field_ty, mod, opt_sema))) {
                            return false;
                        }
                    }
                    return true;
                }

                if (ty.zigTypeTag() == .Struct) {
                    const fields = ty.structFields().values();
                    assert(fields.len == a_field_vals.len);
                    for (fields, 0..) |field, i| {
                        if (!(try eqlAdvanced(a_field_vals[i], field.ty, b_field_vals[i], field.ty, mod, opt_sema))) {
                            return false;
                        }
                    }
                    return true;
                }

                const elem_ty = ty.childType();
                for (a_field_vals, 0..) |a_elem, i| {
                    const b_elem = b_field_vals[i];

                    if (!(try eqlAdvanced(a_elem, elem_ty, b_elem, elem_ty, mod, opt_sema))) {
                        return false;
                    }
                }
                return true;
            },
            .@"union" => {
                const a_union = a.castTag(.@"union").?.data;
                const b_union = b.castTag(.@"union").?.data;
                switch (ty.containerLayout()) {
                    .Packed, .Extern => {
                        const tag_ty = ty.unionTagTypeHypothetical();
                        if (!(try eqlAdvanced(a_union.tag, tag_ty, b_union.tag, tag_ty, mod, opt_sema))) {
                            // In this case, we must disregard mismatching tags and compare
                            // based on the in-memory bytes of the payloads.
                            @panic("TODO comptime comparison of extern union values with mismatching tags");
                        }
                    },
                    .Auto => {
                        const tag_ty = ty.unionTagTypeHypothetical();
                        if (!(try eqlAdvanced(a_union.tag, tag_ty, b_union.tag, tag_ty, mod, opt_sema))) {
                            return false;
                        }
                    },
                }
                const active_field_ty = ty.unionFieldType(a_union.tag, mod);
                return eqlAdvanced(a_union.val, active_field_ty, b_union.val, active_field_ty, mod, opt_sema);
            },
            else => {},
        } else if (b_tag == .null_value or b_tag == .@"error") {
            return false;
        } else if (a_tag == .undef or b_tag == .undef) {
            return false;
        }

        if (a.pointerDecl()) |a_decl| {
            if (b.pointerDecl()) |b_decl| {
                return a_decl == b_decl;
            } else {
                return false;
            }
        } else if (b.pointerDecl()) |_| {
            return false;
        }

        switch (ty.zigTypeTag()) {
            .Type => {
                var buf_a: ToTypeBuffer = undefined;
                var buf_b: ToTypeBuffer = undefined;
                const a_type = a.toType(&buf_a);
                const b_type = b.toType(&buf_b);
                return a_type.eql(b_type, mod);
            },
            .Enum => {
                var buf_a: Payload.U64 = undefined;
                var buf_b: Payload.U64 = undefined;
                const a_val = a.enumToInt(ty, &buf_a);
                const b_val = b.enumToInt(ty, &buf_b);
                var buf_ty: Type.Payload.Bits = undefined;
                const int_ty = ty.intTagType(&buf_ty);
                return eqlAdvanced(a_val, int_ty, b_val, int_ty, mod, opt_sema);
            },
            .Array, .Vector => {
                const len = ty.arrayLen();
                const elem_ty = ty.childType();
                var i: usize = 0;
                var a_buf: ElemValueBuffer = undefined;
                var b_buf: ElemValueBuffer = undefined;
                while (i < len) : (i += 1) {
                    const a_elem = elemValueBuffer(a, mod, i, &a_buf);
                    const b_elem = elemValueBuffer(b, mod, i, &b_buf);
                    if (!(try eqlAdvanced(a_elem, elem_ty, b_elem, elem_ty, mod, opt_sema))) {
                        return false;
                    }
                }
                return true;
            },
            .Pointer => switch (ty.ptrSize()) {
                .Slice => {
                    const a_len = switch (a_ty.ptrSize()) {
                        .Slice => a.sliceLen(mod),
                        .One => a_ty.childType().arrayLen(),
                        else => unreachable,
                    };
                    if (a_len != b.sliceLen(mod)) {
                        return false;
                    }

                    var ptr_buf: Type.SlicePtrFieldTypeBuffer = undefined;
                    const ptr_ty = ty.slicePtrFieldType(&ptr_buf);
                    const a_ptr = switch (a_ty.ptrSize()) {
                        .Slice => a.slicePtr(),
                        .One => a,
                        else => unreachable,
                    };
                    return try eqlAdvanced(a_ptr, ptr_ty, b.slicePtr(), ptr_ty, mod, opt_sema);
                },
                .Many, .C, .One => {},
            },
            .Struct => {
                // A struct can be represented with one of:
                //   .empty_struct_value,
                //   .the_one_possible_value,
                //   .aggregate,
                // Note that we already checked above for matching tags, e.g. both .aggregate.
                return ty.onePossibleValue() != null;
            },
            .Union => {
                // Here we have to check for value equality, as-if `a` has been coerced to `ty`.
                if (ty.onePossibleValue() != null) {
                    return true;
                }
                if (a_ty.castTag(.anon_struct)) |payload| {
                    const tuple = payload.data;
                    if (tuple.values.len != 1) {
                        return false;
                    }
                    const field_name = tuple.names[0];
                    const union_obj = ty.cast(Type.Payload.Union).?.data;
                    const field_index = union_obj.fields.getIndex(field_name) orelse return false;
                    const tag_and_val = b.castTag(.@"union").?.data;
                    var field_tag_buf: Value.Payload.U32 = .{
                        .base = .{ .tag = .enum_field_index },
                        .data = @intCast(u32, field_index),
                    };
                    const field_tag = Value.initPayload(&field_tag_buf.base);
                    const tag_matches = tag_and_val.tag.eql(field_tag, union_obj.tag_ty, mod);
                    if (!tag_matches) return false;
                    return eqlAdvanced(tag_and_val.val, union_obj.tag_ty, tuple.values[0], tuple.types[0], mod, opt_sema);
                }
                return false;
            },
            .Float => {
                switch (ty.floatBits(target)) {
                    16 => return @bitCast(u16, a.toFloat(f16)) == @bitCast(u16, b.toFloat(f16)),
                    32 => return @bitCast(u32, a.toFloat(f32)) == @bitCast(u32, b.toFloat(f32)),
                    64 => return @bitCast(u64, a.toFloat(f64)) == @bitCast(u64, b.toFloat(f64)),
                    80 => return @bitCast(u80, a.toFloat(f80)) == @bitCast(u80, b.toFloat(f80)),
                    128 => return @bitCast(u128, a.toFloat(f128)) == @bitCast(u128, b.toFloat(f128)),
                    else => unreachable,
                }
            },
            .ComptimeFloat => {
                const a_float = a.toFloat(f128);
                const b_float = b.toFloat(f128);

                const a_nan = std.math.isNan(a_float);
                const b_nan = std.math.isNan(b_float);
                if (a_nan != b_nan) return false;
                if (std.math.signbit(a_float) != std.math.signbit(b_float)) return false;
                if (a_nan) return true;
                return a_float == b_float;
            },
            .Optional => if (a_tag != .null_value and b_tag == .opt_payload) {
                var sub_pl: Payload.SubValue = .{
                    .base = .{ .tag = b.tag() },
                    .data = a,
                };
                const sub_val = Value.initPayload(&sub_pl.base);
                return eqlAdvanced(sub_val, ty, b, ty, mod, opt_sema);
            },
            .ErrorUnion => if (a_tag != .@"error" and b_tag == .eu_payload) {
                var sub_pl: Payload.SubValue = .{
                    .base = .{ .tag = b.tag() },
                    .data = a,
                };
                const sub_val = Value.initPayload(&sub_pl.base);
                return eqlAdvanced(sub_val, ty, b, ty, mod, opt_sema);
            },
            else => {},
        }
        if (a_tag == .null_value or a_tag == .@"error") return false;
        return (try orderAdvanced(a, b, target, opt_sema)).compare(.eq);
    }

    /// This function is used by hash maps and so treats floating-point NaNs as equal
    /// to each other, and not equal to other floating-point values.
    pub fn hash(val: Value, ty: Type, hasher: *std.hash.Wyhash, mod: *Module) void {
        const zig_ty_tag = ty.zigTypeTag();
        std.hash.autoHash(hasher, zig_ty_tag);
        if (val.isUndef()) return;
        // The value is runtime-known and shouldn't affect the hash.
        if (val.tag() == .runtime_value) return;

        switch (zig_ty_tag) {
            .Opaque => unreachable, // Cannot hash opaque types

            .Void,
            .NoReturn,
            .Undefined,
            .Null,
            => {},

            .Type => {
                var buf: ToTypeBuffer = undefined;
                return val.toType(&buf).hashWithHasher(hasher, mod);
            },
            .Float => {
                // For hash/eql purposes, we treat floats as their IEEE integer representation.
                switch (ty.floatBits(mod.getTarget())) {
                    16 => std.hash.autoHash(hasher, @bitCast(u16, val.toFloat(f16))),
                    32 => std.hash.autoHash(hasher, @bitCast(u32, val.toFloat(f32))),
                    64 => std.hash.autoHash(hasher, @bitCast(u64, val.toFloat(f64))),
                    80 => std.hash.autoHash(hasher, @bitCast(u80, val.toFloat(f80))),
                    128 => std.hash.autoHash(hasher, @bitCast(u128, val.toFloat(f128))),
                    else => unreachable,
                }
            },
            .ComptimeFloat => {
                const float = val.toFloat(f128);
                const is_nan = std.math.isNan(float);
                std.hash.autoHash(hasher, is_nan);
                if (!is_nan) {
                    std.hash.autoHash(hasher, @bitCast(u128, float));
                } else {
                    std.hash.autoHash(hasher, std.math.signbit(float));
                }
            },
            .Bool, .Int, .ComptimeInt, .Pointer => switch (val.tag()) {
                .slice => {
                    const slice = val.castTag(.slice).?.data;
                    var ptr_buf: Type.SlicePtrFieldTypeBuffer = undefined;
                    const ptr_ty = ty.slicePtrFieldType(&ptr_buf);
                    hash(slice.ptr, ptr_ty, hasher, mod);
                    hash(slice.len, Type.usize, hasher, mod);
                },

                else => return hashPtr(val, hasher, mod.getTarget()),
            },
            .Array, .Vector => {
                const len = ty.arrayLen();
                const elem_ty = ty.childType();
                var index: usize = 0;
                var elem_value_buf: ElemValueBuffer = undefined;
                while (index < len) : (index += 1) {
                    const elem_val = val.elemValueBuffer(mod, index, &elem_value_buf);
                    elem_val.hash(elem_ty, hasher, mod);
                }
            },
            .Struct => {
                switch (val.tag()) {
                    .empty_struct_value => {},
                    .aggregate => {
                        const field_values = val.castTag(.aggregate).?.data;
                        for (field_values, 0..) |field_val, i| {
                            const field_ty = ty.structFieldType(i);
                            field_val.hash(field_ty, hasher, mod);
                        }
                    },
                    else => unreachable,
                }
            },
            .Optional => {
                if (val.castTag(.opt_payload)) |payload| {
                    std.hash.autoHash(hasher, true); // non-null
                    const sub_val = payload.data;
                    var buffer: Type.Payload.ElemType = undefined;
                    const sub_ty = ty.optionalChild(&buffer);
                    sub_val.hash(sub_ty, hasher, mod);
                } else {
                    std.hash.autoHash(hasher, false); // null
                }
            },
            .ErrorUnion => {
                if (val.tag() == .@"error") {
                    std.hash.autoHash(hasher, false); // error
                    const sub_ty = ty.errorUnionSet();
                    val.hash(sub_ty, hasher, mod);
                    return;
                }

                if (val.castTag(.eu_payload)) |payload| {
                    std.hash.autoHash(hasher, true); // payload
                    const sub_ty = ty.errorUnionPayload();
                    payload.data.hash(sub_ty, hasher, mod);
                    return;
                } else unreachable;
            },
            .ErrorSet => {
                // just hash the literal error value. this is the most stable
                // thing between compiler invocations. we can't use the error
                // int cause (1) its not stable and (2) we don't have access to mod.
                hasher.update(val.getError().?);
            },
            .Enum => {
                var enum_space: Payload.U64 = undefined;
                const int_val = val.enumToInt(ty, &enum_space);
                hashInt(int_val, hasher, mod.getTarget());
            },
            .Union => {
                const union_obj = val.cast(Payload.Union).?.data;
                if (ty.unionTagType()) |tag_ty| {
                    union_obj.tag.hash(tag_ty, hasher, mod);
                }
                const active_field_ty = ty.unionFieldType(union_obj.tag, mod);
                union_obj.val.hash(active_field_ty, hasher, mod);
            },
            .Fn => {
                // Note that this hashes the *Fn/*ExternFn rather than the *Decl.
                // This is to differentiate function bodies from function pointers.
                // This is currently redundant since we already hash the zig type tag
                // at the top of this function.
                if (val.castTag(.function)) |func| {
                    std.hash.autoHash(hasher, func.data);
                } else if (val.castTag(.extern_fn)) |func| {
                    std.hash.autoHash(hasher, func.data);
                } else unreachable;
            },
            .Frame => {
                @panic("TODO implement hashing frame values");
            },
            .AnyFrame => {
                @panic("TODO implement hashing anyframe values");
            },
            .EnumLiteral => {
                const bytes = val.castTag(.enum_literal).?.data;
                hasher.update(bytes);
            },
        }
    }

    /// This is a more conservative hash function that produces equal hashes for values
    /// that can coerce into each other.
    /// This function is used by hash maps and so treats floating-point NaNs as equal
    /// to each other, and not equal to other floating-point values.
    pub fn hashUncoerced(val: Value, ty: Type, hasher: *std.hash.Wyhash, mod: *Module) void {
        if (val.isUndef()) return;
        // The value is runtime-known and shouldn't affect the hash.
        if (val.tag() == .runtime_value) return;

        switch (ty.zigTypeTag()) {
            .Opaque => unreachable, // Cannot hash opaque types
            .Void,
            .NoReturn,
            .Undefined,
            .Null,
            .Struct, // It sure would be nice to do something clever with structs.
            => |zig_type_tag| std.hash.autoHash(hasher, zig_type_tag),
            .Type => {
                var buf: ToTypeBuffer = undefined;
                val.toType(&buf).hashWithHasher(hasher, mod);
            },
            .Float, .ComptimeFloat => std.hash.autoHash(hasher, @bitCast(u128, val.toFloat(f128))),
            .Bool, .Int, .ComptimeInt, .Pointer, .Fn => switch (val.tag()) {
                .slice => {
                    const slice = val.castTag(.slice).?.data;
                    var ptr_buf: Type.SlicePtrFieldTypeBuffer = undefined;
                    const ptr_ty = ty.slicePtrFieldType(&ptr_buf);
                    slice.ptr.hashUncoerced(ptr_ty, hasher, mod);
                },
                else => val.hashPtr(hasher, mod.getTarget()),
            },
            .Array, .Vector => {
                const len = ty.arrayLen();
                const elem_ty = ty.childType();
                var index: usize = 0;
                var elem_value_buf: ElemValueBuffer = undefined;
                while (index < len) : (index += 1) {
                    const elem_val = val.elemValueBuffer(mod, index, &elem_value_buf);
                    elem_val.hashUncoerced(elem_ty, hasher, mod);
                }
            },
            .Optional => if (val.castTag(.opt_payload)) |payload| {
                var buf: Type.Payload.ElemType = undefined;
                const child_ty = ty.optionalChild(&buf);
                payload.data.hashUncoerced(child_ty, hasher, mod);
            } else std.hash.autoHash(hasher, std.builtin.TypeId.Null),
            .ErrorSet, .ErrorUnion => if (val.getError()) |err| hasher.update(err) else {
                const pl_ty = ty.errorUnionPayload();
                val.castTag(.eu_payload).?.data.hashUncoerced(pl_ty, hasher, mod);
            },
            .Enum, .EnumLiteral, .Union => {
                hasher.update(val.tagName(ty, mod));
                if (val.cast(Payload.Union)) |union_obj| {
                    const active_field_ty = ty.unionFieldType(union_obj.data.tag, mod);
                    union_obj.data.val.hashUncoerced(active_field_ty, hasher, mod);
                } else std.hash.autoHash(hasher, std.builtin.TypeId.Void);
            },
            .Frame => @panic("TODO implement hashing frame values"),
            .AnyFrame => @panic("TODO implement hashing anyframe values"),
        }
    }

    pub const ArrayHashContext = struct {
        ty: Type,
        mod: *Module,

        pub fn hash(self: @This(), val: Value) u32 {
            const other_context: HashContext = .{ .ty = self.ty, .mod = self.mod };
            return @truncate(u32, other_context.hash(val));
        }
        pub fn eql(self: @This(), a: Value, b: Value, b_index: usize) bool {
            _ = b_index;
            return a.eql(b, self.ty, self.mod);
        }
    };

    pub const HashContext = struct {
        ty: Type,
        mod: *Module,

        pub fn hash(self: @This(), val: Value) u64 {
            var hasher = std.hash.Wyhash.init(0);
            val.hash(self.ty, &hasher, self.mod);
            return hasher.final();
        }

        pub fn eql(self: @This(), a: Value, b: Value) bool {
            return a.eql(b, self.ty, self.mod);
        }
    };

    pub fn isComptimeMutablePtr(val: Value) bool {
        return switch (val.tag()) {
            .decl_ref_mut, .comptime_field_ptr => true,
            .elem_ptr => isComptimeMutablePtr(val.castTag(.elem_ptr).?.data.array_ptr),
            .field_ptr => isComptimeMutablePtr(val.castTag(.field_ptr).?.data.container_ptr),
            .eu_payload_ptr => isComptimeMutablePtr(val.castTag(.eu_payload_ptr).?.data.container_ptr),
            .opt_payload_ptr => isComptimeMutablePtr(val.castTag(.opt_payload_ptr).?.data.container_ptr),

            else => false,
        };
    }

    pub fn canMutateComptimeVarState(val: Value) bool {
        if (val.isComptimeMutablePtr()) return true;
        switch (val.tag()) {
            .repeated => return val.castTag(.repeated).?.data.canMutateComptimeVarState(),
            .eu_payload => return val.castTag(.eu_payload).?.data.canMutateComptimeVarState(),
            .eu_payload_ptr => return val.castTag(.eu_payload_ptr).?.data.container_ptr.canMutateComptimeVarState(),
            .opt_payload => return val.castTag(.opt_payload).?.data.canMutateComptimeVarState(),
            .opt_payload_ptr => return val.castTag(.opt_payload_ptr).?.data.container_ptr.canMutateComptimeVarState(),
            .aggregate => {
                const fields = val.castTag(.aggregate).?.data;
                for (fields) |field| {
                    if (field.canMutateComptimeVarState()) return true;
                }
                return false;
            },
            .@"union" => return val.cast(Payload.Union).?.data.val.canMutateComptimeVarState(),
            .slice => return val.castTag(.slice).?.data.ptr.canMutateComptimeVarState(),
            else => return false,
        }
    }

    /// Gets the decl referenced by this pointer.  If the pointer does not point
    /// to a decl, or if it points to some part of a decl (like field_ptr or element_ptr),
    /// this function returns null.
    pub fn pointerDecl(val: Value) ?Module.Decl.Index {
        return switch (val.tag()) {
            .decl_ref_mut => val.castTag(.decl_ref_mut).?.data.decl_index,
            .extern_fn => val.castTag(.extern_fn).?.data.owner_decl,
            .function => val.castTag(.function).?.data.owner_decl,
            .variable => val.castTag(.variable).?.data.owner_decl,
            .decl_ref => val.cast(Payload.Decl).?.data,
            else => null,
        };
    }

    fn hashInt(int_val: Value, hasher: *std.hash.Wyhash, target: Target) void {
        var buffer: BigIntSpace = undefined;
        const big = int_val.toBigInt(&buffer, target);
        std.hash.autoHash(hasher, big.positive);
        for (big.limbs) |limb| {
            std.hash.autoHash(hasher, limb);
        }
    }

    fn hashPtr(ptr_val: Value, hasher: *std.hash.Wyhash, target: Target) void {
        switch (ptr_val.tag()) {
            .decl_ref,
            .decl_ref_mut,
            .extern_fn,
            .function,
            .variable,
            => {
                const decl: Module.Decl.Index = ptr_val.pointerDecl().?;
                std.hash.autoHash(hasher, decl);
            },
            .comptime_field_ptr => {
                std.hash.autoHash(hasher, Value.Tag.comptime_field_ptr);
            },

            .elem_ptr => {
                const elem_ptr = ptr_val.castTag(.elem_ptr).?.data;
                hashPtr(elem_ptr.array_ptr, hasher, target);
                std.hash.autoHash(hasher, Value.Tag.elem_ptr);
                std.hash.autoHash(hasher, elem_ptr.index);
            },
            .field_ptr => {
                const field_ptr = ptr_val.castTag(.field_ptr).?.data;
                std.hash.autoHash(hasher, Value.Tag.field_ptr);
                hashPtr(field_ptr.container_ptr, hasher, target);
                std.hash.autoHash(hasher, field_ptr.field_index);
            },
            .eu_payload_ptr => {
                const err_union_ptr = ptr_val.castTag(.eu_payload_ptr).?.data;
                std.hash.autoHash(hasher, Value.Tag.eu_payload_ptr);
                hashPtr(err_union_ptr.container_ptr, hasher, target);
            },
            .opt_payload_ptr => {
                const opt_ptr = ptr_val.castTag(.opt_payload_ptr).?.data;
                std.hash.autoHash(hasher, Value.Tag.opt_payload_ptr);
                hashPtr(opt_ptr.container_ptr, hasher, target);
            },

            .zero,
            .one,
            .null_value,
            .int_u64,
            .int_i64,
            .int_big_positive,
            .int_big_negative,
            .bool_false,
            .bool_true,
            .the_only_possible_value,
            .lazy_align,
            .lazy_size,
            => return hashInt(ptr_val, hasher, target),

            else => unreachable,
        }
    }

    pub fn slicePtr(val: Value) Value {
        return switch (val.tag()) {
            .slice => val.castTag(.slice).?.data.ptr,
            // TODO this should require being a slice tag, and not allow decl_ref, field_ptr, etc.
            .decl_ref, .decl_ref_mut, .field_ptr, .elem_ptr, .comptime_field_ptr => val,
            else => unreachable,
        };
    }

    pub fn sliceLen(val: Value, mod: *Module) u64 {
        return switch (val.tag()) {
            .slice => val.castTag(.slice).?.data.len.toUnsignedInt(mod.getTarget()),
            .decl_ref => {
                const decl_index = val.castTag(.decl_ref).?.data;
                const decl = mod.declPtr(decl_index);
                if (decl.ty.zigTypeTag() == .Array) {
                    return decl.ty.arrayLen();
                } else {
                    return 1;
                }
            },
            .decl_ref_mut => {
                const decl_index = val.castTag(.decl_ref_mut).?.data.decl_index;
                const decl = mod.declPtr(decl_index);
                if (decl.ty.zigTypeTag() == .Array) {
                    return decl.ty.arrayLen();
                } else {
                    return 1;
                }
            },
            .comptime_field_ptr => {
                const payload = val.castTag(.comptime_field_ptr).?.data;
                if (payload.field_ty.zigTypeTag() == .Array) {
                    return payload.field_ty.arrayLen();
                } else {
                    return 1;
                }
            },
            else => unreachable,
        };
    }

    /// Asserts the value is a single-item pointer to an array, or an array,
    /// or an unknown-length pointer, and returns the element value at the index.
    pub fn elemValue(val: Value, mod: *Module, arena: Allocator, index: usize) !Value {
        return elemValueAdvanced(val, mod, index, arena, undefined);
    }

    pub const ElemValueBuffer = Payload.U64;

    pub fn elemValueBuffer(val: Value, mod: *Module, index: usize, buffer: *ElemValueBuffer) Value {
        return elemValueAdvanced(val, mod, index, null, buffer) catch unreachable;
    }

    pub fn elemValueAdvanced(
        val: Value,
        mod: *Module,
        index: usize,
        arena: ?Allocator,
        buffer: *ElemValueBuffer,
    ) error{OutOfMemory}!Value {
        switch (val.tag()) {
            // This is the case of accessing an element of an undef array.
            .undef => return Value.undef,
            .empty_array => unreachable, // out of bounds array index
            .empty_struct_value => unreachable, // out of bounds array index

            .empty_array_sentinel => {
                assert(index == 0); // The only valid index for an empty array with sentinel.
                return val.castTag(.empty_array_sentinel).?.data;
            },

            .bytes => {
                const byte = val.castTag(.bytes).?.data[index];
                if (arena) |a| {
                    return Tag.int_u64.create(a, byte);
                } else {
                    buffer.* = .{
                        .base = .{ .tag = .int_u64 },
                        .data = byte,
                    };
                    return initPayload(&buffer.base);
                }
            },
            .str_lit => {
                const str_lit = val.castTag(.str_lit).?.data;
                const bytes = mod.string_literal_bytes.items[str_lit.index..][0..str_lit.len];
                const byte = bytes[index];
                if (arena) |a| {
                    return Tag.int_u64.create(a, byte);
                } else {
                    buffer.* = .{
                        .base = .{ .tag = .int_u64 },
                        .data = byte,
                    };
                    return initPayload(&buffer.base);
                }
            },

            // No matter the index; all the elements are the same!
            .repeated => return val.castTag(.repeated).?.data,

            .aggregate => return val.castTag(.aggregate).?.data[index],
            .slice => return val.castTag(.slice).?.data.ptr.elemValueAdvanced(mod, index, arena, buffer),

            .decl_ref => return mod.declPtr(val.castTag(.decl_ref).?.data).val.elemValueAdvanced(mod, index, arena, buffer),
            .decl_ref_mut => return mod.declPtr(val.castTag(.decl_ref_mut).?.data.decl_index).val.elemValueAdvanced(mod, index, arena, buffer),
            .comptime_field_ptr => return val.castTag(.comptime_field_ptr).?.data.field_val.elemValueAdvanced(mod, index, arena, buffer),
            .elem_ptr => {
                const data = val.castTag(.elem_ptr).?.data;
                return data.array_ptr.elemValueAdvanced(mod, index + data.index, arena, buffer);
            },

            // The child type of arrays which have only one possible value need
            // to have only one possible value itself.
            .the_only_possible_value => return val,

            .opt_payload_ptr => return val.castTag(.opt_payload_ptr).?.data.container_ptr.elemValueAdvanced(mod, index, arena, buffer),
            .eu_payload_ptr => return val.castTag(.eu_payload_ptr).?.data.container_ptr.elemValueAdvanced(mod, index, arena, buffer),

            .opt_payload => return val.castTag(.opt_payload).?.data.elemValueAdvanced(mod, index, arena, buffer),
            .eu_payload => return val.castTag(.eu_payload).?.data.elemValueAdvanced(mod, index, arena, buffer),

            // These values will implicitly be treated as `repeated`.
            .zero,
            .one,
            .bool_false,
            .bool_true,
            .int_i64,
            .int_u64,
            => return val,

            else => unreachable,
        }
    }

    /// Returns true if a Value is backed by a variable
    pub fn isVariable(
        val: Value,
        mod: *Module,
    ) bool {
        return switch (val.tag()) {
            .slice => val.castTag(.slice).?.data.ptr.isVariable(mod),
            .comptime_field_ptr => val.castTag(.comptime_field_ptr).?.data.field_val.isVariable(mod),
            .elem_ptr => val.castTag(.elem_ptr).?.data.array_ptr.isVariable(mod),
            .field_ptr => val.castTag(.field_ptr).?.data.container_ptr.isVariable(mod),
            .eu_payload_ptr => val.castTag(.eu_payload_ptr).?.data.container_ptr.isVariable(mod),
            .opt_payload_ptr => val.castTag(.opt_payload_ptr).?.data.container_ptr.isVariable(mod),
            .decl_ref => {
                const decl = mod.declPtr(val.castTag(.decl_ref).?.data);
                assert(decl.has_tv);
                return decl.val.isVariable(mod);
            },
            .decl_ref_mut => {
                const decl = mod.declPtr(val.castTag(.decl_ref_mut).?.data.decl_index);
                assert(decl.has_tv);
                return decl.val.isVariable(mod);
            },

            .variable => true,
            else => false,
        };
    }

    pub fn isPtrToThreadLocal(val: Value, mod: *Module) bool {
        return switch (val.tag()) {
            .variable => false,
            else => val.isPtrToThreadLocalInner(mod),
        };
    }

    fn isPtrToThreadLocalInner(val: Value, mod: *Module) bool {
        return switch (val.tag()) {
            .slice => val.castTag(.slice).?.data.ptr.isPtrToThreadLocalInner(mod),
            .comptime_field_ptr => val.castTag(.comptime_field_ptr).?.data.field_val.isPtrToThreadLocalInner(mod),
            .elem_ptr => val.castTag(.elem_ptr).?.data.array_ptr.isPtrToThreadLocalInner(mod),
            .field_ptr => val.castTag(.field_ptr).?.data.container_ptr.isPtrToThreadLocalInner(mod),
            .eu_payload_ptr => val.castTag(.eu_payload_ptr).?.data.container_ptr.isPtrToThreadLocalInner(mod),
            .opt_payload_ptr => val.castTag(.opt_payload_ptr).?.data.container_ptr.isPtrToThreadLocalInner(mod),
            .decl_ref => mod.declPtr(val.castTag(.decl_ref).?.data).val.isPtrToThreadLocalInner(mod),
            .decl_ref_mut => mod.declPtr(val.castTag(.decl_ref_mut).?.data.decl_index).val.isPtrToThreadLocalInner(mod),

            .variable => val.castTag(.variable).?.data.is_threadlocal,
            else => false,
        };
    }

    // Asserts that the provided start/end are in-bounds.
    pub fn sliceArray(
        val: Value,
        mod: *Module,
        arena: Allocator,
        start: usize,
        end: usize,
    ) error{OutOfMemory}!Value {
        return switch (val.tag()) {
            .empty_array_sentinel => if (start == 0 and end == 1) val else Value.initTag(.empty_array),
            .bytes => Tag.bytes.create(arena, val.castTag(.bytes).?.data[start..end]),
            .str_lit => {
                const str_lit = val.castTag(.str_lit).?.data;
                return Tag.str_lit.create(arena, .{
                    .index = @intCast(u32, str_lit.index + start),
                    .len = @intCast(u32, end - start),
                });
            },
            .aggregate => Tag.aggregate.create(arena, val.castTag(.aggregate).?.data[start..end]),
            .slice => sliceArray(val.castTag(.slice).?.data.ptr, mod, arena, start, end),

            .decl_ref => sliceArray(mod.declPtr(val.castTag(.decl_ref).?.data).val, mod, arena, start, end),
            .decl_ref_mut => sliceArray(mod.declPtr(val.castTag(.decl_ref_mut).?.data.decl_index).val, mod, arena, start, end),
            .comptime_field_ptr => sliceArray(val.castTag(.comptime_field_ptr).?.data.field_val, mod, arena, start, end),
            .elem_ptr => blk: {
                const elem_ptr = val.castTag(.elem_ptr).?.data;
                break :blk sliceArray(elem_ptr.array_ptr, mod, arena, start + elem_ptr.index, end + elem_ptr.index);
            },

            .repeated,
            .the_only_possible_value,
            => val,

            else => unreachable,
        };
    }

    pub fn fieldValue(val: Value, ty: Type, index: usize) Value {
        switch (val.tag()) {
            .aggregate => {
                const field_values = val.castTag(.aggregate).?.data;
                return field_values[index];
            },
            .@"union" => {
                const payload = val.castTag(.@"union").?.data;
                // TODO assert the tag is correct
                return payload.val;
            },

            .the_only_possible_value => return ty.onePossibleValue().?,

            .empty_struct_value => {
                if (ty.isSimpleTupleOrAnonStruct()) {
                    const tuple = ty.tupleFields();
                    return tuple.values[index];
                }
                if (ty.structFieldValueComptime(index)) |some| {
                    return some;
                }
                unreachable;
            },
            .undef => return Value.undef,

            else => unreachable,
        }
    }

    pub fn unionTag(val: Value) Value {
        switch (val.tag()) {
            .undef, .enum_field_index => return val,
            .@"union" => return val.castTag(.@"union").?.data.tag,
            else => unreachable,
        }
    }

    /// Returns a pointer to the element value at the index.
    pub fn elemPtr(
        val: Value,
        ty: Type,
        arena: Allocator,
        index: usize,
        mod: *Module,
    ) Allocator.Error!Value {
        const elem_ty = ty.elemType2();
        const ptr_val = switch (val.tag()) {
            .slice => val.castTag(.slice).?.data.ptr,
            else => val,
        };

        if (ptr_val.tag() == .elem_ptr) {
            const elem_ptr = ptr_val.castTag(.elem_ptr).?.data;
            if (elem_ptr.elem_ty.eql(elem_ty, mod)) {
                return Tag.elem_ptr.create(arena, .{
                    .array_ptr = elem_ptr.array_ptr,
                    .elem_ty = elem_ptr.elem_ty,
                    .index = elem_ptr.index + index,
                });
            }
        }
        return Tag.elem_ptr.create(arena, .{
            .array_ptr = ptr_val,
            .elem_ty = elem_ty,
            .index = index,
        });
    }

    pub fn isUndef(self: Value) bool {
        return self.tag() == .undef;
    }

    /// TODO: check for cases such as array that is not marked undef but all the element
    /// values are marked undef, or struct that is not marked undef but all fields are marked
    /// undef, etc.
    pub fn isUndefDeep(self: Value) bool {
        return self.isUndef();
    }

    /// Returns true if any value contained in `self` is undefined.
    /// TODO: check for cases such as array that is not marked undef but all the element
    /// values are marked undef, or struct that is not marked undef but all fields are marked
    /// undef, etc.
    pub fn anyUndef(self: Value, mod: *Module) bool {
        switch (self.tag()) {
            .slice => {
                const payload = self.castTag(.slice).?;
                const len = payload.data.len.toUnsignedInt(mod.getTarget());

                var elem_value_buf: ElemValueBuffer = undefined;
                var i: usize = 0;
                while (i < len) : (i += 1) {
                    const elem_val = payload.data.ptr.elemValueBuffer(mod, i, &elem_value_buf);
                    if (elem_val.anyUndef(mod)) return true;
                }
            },

            .aggregate => {
                const payload = self.castTag(.aggregate).?;
                for (payload.data) |val| {
                    if (val.anyUndef(mod)) return true;
                }
            },

            .undef => return true,
            else => {},
        }

        return false;
    }

    /// Asserts the value is not undefined and not unreachable.
    /// Integer value 0 is considered null because of C pointers.
    pub fn isNull(self: Value) bool {
        return switch (self.tag()) {
            .null_value => true,
            .opt_payload => false,

            // If it's not one of those two tags then it must be a C pointer value,
            // in which case the value 0 is null and other values are non-null.

            .zero,
            .bool_false,
            .the_only_possible_value,
            => true,

            .one,
            .bool_true,
            => false,

            .int_u64,
            .int_i64,
            .int_big_positive,
            .int_big_negative,
            => self.orderAgainstZero().compare(.eq),

            .undef => unreachable,
            .unreachable_value => unreachable,
            .inferred_alloc => unreachable,
            .inferred_alloc_comptime => unreachable,

            else => false,
        };
    }

    /// Valid only for error (union) types. Asserts the value is not undefined and not
    /// unreachable. For error unions, prefer `errorUnionIsPayload` to find out whether
    /// something is an error or not because it works without having to figure out the
    /// string.
    pub fn getError(self: Value) ?[]const u8 {
        return switch (self.tag()) {
            .@"error" => self.castTag(.@"error").?.data.name,
            .int_u64 => @panic("TODO"),
            .int_i64 => @panic("TODO"),
            .int_big_positive => @panic("TODO"),
            .int_big_negative => @panic("TODO"),
            .one => @panic("TODO"),
            .undef => unreachable,
            .unreachable_value => unreachable,
            .inferred_alloc => unreachable,
            .inferred_alloc_comptime => unreachable,

            else => null,
        };
    }

    /// Assumes the type is an error union. Returns true if and only if the value is
    /// the error union payload, not an error.
    pub fn errorUnionIsPayload(val: Value) bool {
        return switch (val.tag()) {
            .eu_payload => true,
            else => false,

            .undef => unreachable,
            .inferred_alloc => unreachable,
            .inferred_alloc_comptime => unreachable,
        };
    }

    /// Value of the optional, null if optional has no payload.
    pub fn optionalValue(val: Value) ?Value {
        if (val.isNull()) return null;

        // Valid for optional representation to be the direct value
        // and not use opt_payload.
        return if (val.castTag(.opt_payload)) |p| p.data else val;
    }

    /// Valid for all types. Asserts the value is not undefined.
    pub fn isFloat(self: Value) bool {
        return switch (self.tag()) {
            .undef => unreachable,
            .inferred_alloc => unreachable,
            .inferred_alloc_comptime => unreachable,

            .float_16,
            .float_32,
            .float_64,
            .float_80,
            .float_128,
            => true,
            else => false,
        };
    }

    pub fn intToFloat(val: Value, arena: Allocator, int_ty: Type, float_ty: Type, mod: *Module) !Value {
        return intToFloatAdvanced(val, arena, int_ty, float_ty, mod, null) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => unreachable,
        };
    }

    pub fn intToFloatAdvanced(val: Value, arena: Allocator, int_ty: Type, float_ty: Type, mod: *Module, opt_sema: ?*Sema) !Value {
        const target = mod.getTarget();
        if (int_ty.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, int_ty.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var buf: Value.ElemValueBuffer = undefined;
                const elem_val = val.elemValueBuffer(mod, i, &buf);
                scalar.* = try intToFloatScalar(elem_val, arena, float_ty.scalarType(), target, opt_sema);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return intToFloatScalar(val, arena, float_ty, target, opt_sema);
    }

    pub fn intToFloatScalar(val: Value, arena: Allocator, float_ty: Type, target: Target, opt_sema: ?*Sema) !Value {
        switch (val.tag()) {
            .undef, .zero, .one => return val,
            .the_only_possible_value => return Value.initTag(.zero), // for i0, u0
            .int_u64 => {
                return intToFloatInner(val.castTag(.int_u64).?.data, arena, float_ty, target);
            },
            .int_i64 => {
                return intToFloatInner(val.castTag(.int_i64).?.data, arena, float_ty, target);
            },
            .int_big_positive => {
                const limbs = val.castTag(.int_big_positive).?.data;
                const float = bigIntToFloat(limbs, true);
                return floatToValue(float, arena, float_ty, target);
            },
            .int_big_negative => {
                const limbs = val.castTag(.int_big_negative).?.data;
                const float = bigIntToFloat(limbs, false);
                return floatToValue(float, arena, float_ty, target);
            },
            .lazy_align => {
                const ty = val.castTag(.lazy_align).?.data;
                if (opt_sema) |sema| {
                    return intToFloatInner((try ty.abiAlignmentAdvanced(target, .{ .sema = sema })).scalar, arena, float_ty, target);
                } else {
                    return intToFloatInner(ty.abiAlignment(target), arena, float_ty, target);
                }
            },
            .lazy_size => {
                const ty = val.castTag(.lazy_size).?.data;
                if (opt_sema) |sema| {
                    return intToFloatInner((try ty.abiSizeAdvanced(target, .{ .sema = sema })).scalar, arena, float_ty, target);
                } else {
                    return intToFloatInner(ty.abiSize(target), arena, float_ty, target);
                }
            },
            else => unreachable,
        }
    }

    fn intToFloatInner(x: anytype, arena: Allocator, dest_ty: Type, target: Target) !Value {
        switch (dest_ty.floatBits(target)) {
            16 => return Value.Tag.float_16.create(arena, @intToFloat(f16, x)),
            32 => return Value.Tag.float_32.create(arena, @intToFloat(f32, x)),
            64 => return Value.Tag.float_64.create(arena, @intToFloat(f64, x)),
            80 => return Value.Tag.float_80.create(arena, @intToFloat(f80, x)),
            128 => return Value.Tag.float_128.create(arena, @intToFloat(f128, x)),
            else => unreachable,
        }
    }

    pub fn floatToValue(float: f128, arena: Allocator, dest_ty: Type, target: Target) !Value {
        switch (dest_ty.floatBits(target)) {
            16 => return Value.Tag.float_16.create(arena, @floatCast(f16, float)),
            32 => return Value.Tag.float_32.create(arena, @floatCast(f32, float)),
            64 => return Value.Tag.float_64.create(arena, @floatCast(f64, float)),
            80 => return Value.Tag.float_80.create(arena, @floatCast(f80, float)),
            128 => return Value.Tag.float_128.create(arena, float),
            else => unreachable,
        }
    }

    fn calcLimbLenFloat(scalar: anytype) usize {
        if (scalar == 0) {
            return 1;
        }

        const w_value = @fabs(scalar);
        return @divFloor(@floatToInt(std.math.big.Limb, std.math.log2(w_value)), @typeInfo(std.math.big.Limb).Int.bits) + 1;
    }

    pub const OverflowArithmeticResult = struct {
        overflow_bit: Value,
        wrapped_result: Value,
    };

    pub fn fromBigInt(arena: Allocator, big_int: BigIntConst) !Value {
        if (big_int.positive) {
            if (big_int.to(u64)) |x| {
                return Value.Tag.int_u64.create(arena, x);
            } else |_| {
                return Value.Tag.int_big_positive.create(arena, big_int.limbs);
            }
        } else {
            if (big_int.to(i64)) |x| {
                return Value.Tag.int_i64.create(arena, x);
            } else |_| {
                return Value.Tag.int_big_negative.create(arena, big_int.limbs);
            }
        }
    }

    /// Supports (vectors of) integers only; asserts neither operand is undefined.
    pub fn intAddSat(
        lhs: Value,
        rhs: Value,
        ty: Type,
        arena: Allocator,
        mod: *Module,
    ) !Value {
        const target = mod.getTarget();
        if (ty.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, ty.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var lhs_buf: Value.ElemValueBuffer = undefined;
                var rhs_buf: Value.ElemValueBuffer = undefined;
                const lhs_elem = lhs.elemValueBuffer(mod, i, &lhs_buf);
                const rhs_elem = rhs.elemValueBuffer(mod, i, &rhs_buf);
                scalar.* = try intAddSatScalar(lhs_elem, rhs_elem, ty.scalarType(), arena, target);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return intAddSatScalar(lhs, rhs, ty, arena, target);
    }

    /// Supports integers only; asserts neither operand is undefined.
    pub fn intAddSatScalar(
        lhs: Value,
        rhs: Value,
        ty: Type,
        arena: Allocator,
        target: Target,
    ) !Value {
        assert(!lhs.isUndef());
        assert(!rhs.isUndef());

        const info = ty.intInfo(target);

        var lhs_space: Value.BigIntSpace = undefined;
        var rhs_space: Value.BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_space, target);
        const rhs_bigint = rhs.toBigInt(&rhs_space, target);
        const limbs = try arena.alloc(
            std.math.big.Limb,
            std.math.big.int.calcTwosCompLimbCount(info.bits),
        );
        var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
        result_bigint.addSat(lhs_bigint, rhs_bigint, info.signedness, info.bits);
        return fromBigInt(arena, result_bigint.toConst());
    }

    /// Supports (vectors of) integers only; asserts neither operand is undefined.
    pub fn intSubSat(
        lhs: Value,
        rhs: Value,
        ty: Type,
        arena: Allocator,
        mod: *Module,
    ) !Value {
        const target = mod.getTarget();
        if (ty.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, ty.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var lhs_buf: Value.ElemValueBuffer = undefined;
                var rhs_buf: Value.ElemValueBuffer = undefined;
                const lhs_elem = lhs.elemValueBuffer(mod, i, &lhs_buf);
                const rhs_elem = rhs.elemValueBuffer(mod, i, &rhs_buf);
                scalar.* = try intSubSatScalar(lhs_elem, rhs_elem, ty.scalarType(), arena, target);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return intSubSatScalar(lhs, rhs, ty, arena, target);
    }

    /// Supports integers only; asserts neither operand is undefined.
    pub fn intSubSatScalar(
        lhs: Value,
        rhs: Value,
        ty: Type,
        arena: Allocator,
        target: Target,
    ) !Value {
        assert(!lhs.isUndef());
        assert(!rhs.isUndef());

        const info = ty.intInfo(target);

        var lhs_space: Value.BigIntSpace = undefined;
        var rhs_space: Value.BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_space, target);
        const rhs_bigint = rhs.toBigInt(&rhs_space, target);
        const limbs = try arena.alloc(
            std.math.big.Limb,
            std.math.big.int.calcTwosCompLimbCount(info.bits),
        );
        var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
        result_bigint.subSat(lhs_bigint, rhs_bigint, info.signedness, info.bits);
        return fromBigInt(arena, result_bigint.toConst());
    }

    pub fn intMulWithOverflow(
        lhs: Value,
        rhs: Value,
        ty: Type,
        arena: Allocator,
        mod: *Module,
    ) !OverflowArithmeticResult {
        const target = mod.getTarget();
        if (ty.zigTypeTag() == .Vector) {
            const overflowed_data = try arena.alloc(Value, ty.vectorLen());
            const result_data = try arena.alloc(Value, ty.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var lhs_buf: Value.ElemValueBuffer = undefined;
                var rhs_buf: Value.ElemValueBuffer = undefined;
                const lhs_elem = lhs.elemValueBuffer(mod, i, &lhs_buf);
                const rhs_elem = rhs.elemValueBuffer(mod, i, &rhs_buf);
                const of_math_result = try intMulWithOverflowScalar(lhs_elem, rhs_elem, ty.scalarType(), arena, target);
                overflowed_data[i] = of_math_result.overflow_bit;
                scalar.* = of_math_result.wrapped_result;
            }
            return OverflowArithmeticResult{
                .overflow_bit = try Value.Tag.aggregate.create(arena, overflowed_data),
                .wrapped_result = try Value.Tag.aggregate.create(arena, result_data),
            };
        }
        return intMulWithOverflowScalar(lhs, rhs, ty, arena, target);
    }

    pub fn intMulWithOverflowScalar(
        lhs: Value,
        rhs: Value,
        ty: Type,
        arena: Allocator,
        target: Target,
    ) !OverflowArithmeticResult {
        const info = ty.intInfo(target);

        var lhs_space: Value.BigIntSpace = undefined;
        var rhs_space: Value.BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_space, target);
        const rhs_bigint = rhs.toBigInt(&rhs_space, target);
        const limbs = try arena.alloc(
            std.math.big.Limb,
            lhs_bigint.limbs.len + rhs_bigint.limbs.len,
        );
        var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
        var limbs_buffer = try arena.alloc(
            std.math.big.Limb,
            std.math.big.int.calcMulLimbsBufferLen(lhs_bigint.limbs.len, rhs_bigint.limbs.len, 1),
        );
        result_bigint.mul(lhs_bigint, rhs_bigint, limbs_buffer, arena);

        const overflowed = !result_bigint.toConst().fitsInTwosComp(info.signedness, info.bits);
        if (overflowed) {
            result_bigint.truncate(result_bigint.toConst(), info.signedness, info.bits);
        }

        return OverflowArithmeticResult{
            .overflow_bit = boolToInt(overflowed),
            .wrapped_result = try fromBigInt(arena, result_bigint.toConst()),
        };
    }

    /// Supports both (vectors of) floats and ints; handles undefined scalars.
    pub fn numberMulWrap(
        lhs: Value,
        rhs: Value,
        ty: Type,
        arena: Allocator,
        mod: *Module,
    ) !Value {
        if (ty.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, ty.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var lhs_buf: Value.ElemValueBuffer = undefined;
                var rhs_buf: Value.ElemValueBuffer = undefined;
                const lhs_elem = lhs.elemValueBuffer(mod, i, &lhs_buf);
                const rhs_elem = rhs.elemValueBuffer(mod, i, &rhs_buf);
                scalar.* = try numberMulWrapScalar(lhs_elem, rhs_elem, ty.scalarType(), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return numberMulWrapScalar(lhs, rhs, ty, arena, mod);
    }

    /// Supports both floats and ints; handles undefined.
    pub fn numberMulWrapScalar(
        lhs: Value,
        rhs: Value,
        ty: Type,
        arena: Allocator,
        mod: *Module,
    ) !Value {
        if (lhs.isUndef() or rhs.isUndef()) return Value.initTag(.undef);

        if (ty.zigTypeTag() == .ComptimeInt) {
            return intMul(lhs, rhs, ty, arena, mod);
        }

        if (ty.isAnyFloat()) {
            return floatMul(lhs, rhs, ty, arena, mod);
        }

        const overflow_result = try intMulWithOverflow(lhs, rhs, ty, arena, mod);
        return overflow_result.wrapped_result;
    }

    /// Supports (vectors of) integers only; asserts neither operand is undefined.
    pub fn intMulSat(
        lhs: Value,
        rhs: Value,
        ty: Type,
        arena: Allocator,
        mod: *Module,
    ) !Value {
        const target = mod.getTarget();
        if (ty.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, ty.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var lhs_buf: Value.ElemValueBuffer = undefined;
                var rhs_buf: Value.ElemValueBuffer = undefined;
                const lhs_elem = lhs.elemValueBuffer(mod, i, &lhs_buf);
                const rhs_elem = rhs.elemValueBuffer(mod, i, &rhs_buf);
                scalar.* = try intMulSatScalar(lhs_elem, rhs_elem, ty.scalarType(), arena, target);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return intMulSatScalar(lhs, rhs, ty, arena, target);
    }

    /// Supports (vectors of) integers only; asserts neither operand is undefined.
    pub fn intMulSatScalar(
        lhs: Value,
        rhs: Value,
        ty: Type,
        arena: Allocator,
        target: Target,
    ) !Value {
        assert(!lhs.isUndef());
        assert(!rhs.isUndef());

        const info = ty.intInfo(target);

        var lhs_space: Value.BigIntSpace = undefined;
        var rhs_space: Value.BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_space, target);
        const rhs_bigint = rhs.toBigInt(&rhs_space, target);
        const limbs = try arena.alloc(
            std.math.big.Limb,
            std.math.max(
                // For the saturate
                std.math.big.int.calcTwosCompLimbCount(info.bits),
                lhs_bigint.limbs.len + rhs_bigint.limbs.len,
            ),
        );
        var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
        var limbs_buffer = try arena.alloc(
            std.math.big.Limb,
            std.math.big.int.calcMulLimbsBufferLen(lhs_bigint.limbs.len, rhs_bigint.limbs.len, 1),
        );
        result_bigint.mul(lhs_bigint, rhs_bigint, limbs_buffer, arena);
        result_bigint.saturate(result_bigint.toConst(), info.signedness, info.bits);
        return fromBigInt(arena, result_bigint.toConst());
    }

    /// Supports both floats and ints; handles undefined.
    pub fn numberMax(lhs: Value, rhs: Value, target: Target) Value {
        if (lhs.isUndef() or rhs.isUndef()) return undef;
        if (lhs.isNan()) return rhs;
        if (rhs.isNan()) return lhs;

        return switch (order(lhs, rhs, target)) {
            .lt => rhs,
            .gt, .eq => lhs,
        };
    }

    /// Supports both floats and ints; handles undefined.
    pub fn numberMin(lhs: Value, rhs: Value, target: Target) Value {
        if (lhs.isUndef() or rhs.isUndef()) return undef;
        if (lhs.isNan()) return rhs;
        if (rhs.isNan()) return lhs;

        return switch (order(lhs, rhs, target)) {
            .lt => lhs,
            .gt, .eq => rhs,
        };
    }

    /// operands must be (vectors of) integers; handles undefined scalars.
    pub fn bitwiseNot(val: Value, ty: Type, arena: Allocator, mod: *Module) !Value {
        const target = mod.getTarget();
        if (ty.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, ty.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var buf: Value.ElemValueBuffer = undefined;
                const elem_val = val.elemValueBuffer(mod, i, &buf);
                scalar.* = try bitwiseNotScalar(elem_val, ty.scalarType(), arena, target);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return bitwiseNotScalar(val, ty, arena, target);
    }

    /// operands must be integers; handles undefined.
    pub fn bitwiseNotScalar(val: Value, ty: Type, arena: Allocator, target: Target) !Value {
        if (val.isUndef()) return Value.initTag(.undef);

        const info = ty.intInfo(target);

        if (info.bits == 0) {
            return val;
        }

        // TODO is this a performance issue? maybe we should try the operation without
        // resorting to BigInt first.
        var val_space: Value.BigIntSpace = undefined;
        const val_bigint = val.toBigInt(&val_space, target);
        const limbs = try arena.alloc(
            std.math.big.Limb,
            std.math.big.int.calcTwosCompLimbCount(info.bits),
        );

        var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
        result_bigint.bitNotWrap(val_bigint, info.signedness, info.bits);
        return fromBigInt(arena, result_bigint.toConst());
    }

    /// operands must be (vectors of) integers; handles undefined scalars.
    pub fn bitwiseAnd(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
        const target = mod.getTarget();
        if (ty.zigTypeTag() == .Vector) {
            const result_data = try allocator.alloc(Value, ty.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var lhs_buf: Value.ElemValueBuffer = undefined;
                var rhs_buf: Value.ElemValueBuffer = undefined;
                const lhs_elem = lhs.elemValueBuffer(mod, i, &lhs_buf);
                const rhs_elem = rhs.elemValueBuffer(mod, i, &rhs_buf);
                scalar.* = try bitwiseAndScalar(lhs_elem, rhs_elem, allocator, target);
            }
            return Value.Tag.aggregate.create(allocator, result_data);
        }
        return bitwiseAndScalar(lhs, rhs, allocator, target);
    }

    /// operands must be integers; handles undefined.
    pub fn bitwiseAndScalar(lhs: Value, rhs: Value, arena: Allocator, target: Target) !Value {
        if (lhs.isUndef() or rhs.isUndef()) return Value.initTag(.undef);

        // TODO is this a performance issue? maybe we should try the operation without
        // resorting to BigInt first.
        var lhs_space: Value.BigIntSpace = undefined;
        var rhs_space: Value.BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_space, target);
        const rhs_bigint = rhs.toBigInt(&rhs_space, target);
        const limbs = try arena.alloc(
            std.math.big.Limb,
            // + 1 for negatives
            std.math.max(lhs_bigint.limbs.len, rhs_bigint.limbs.len) + 1,
        );
        var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
        result_bigint.bitAnd(lhs_bigint, rhs_bigint);
        return fromBigInt(arena, result_bigint.toConst());
    }

    /// operands must be (vectors of) integers; handles undefined scalars.
    pub fn bitwiseNand(lhs: Value, rhs: Value, ty: Type, arena: Allocator, mod: *Module) !Value {
        if (ty.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, ty.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var lhs_buf: Value.ElemValueBuffer = undefined;
                var rhs_buf: Value.ElemValueBuffer = undefined;
                const lhs_elem = lhs.elemValueBuffer(mod, i, &lhs_buf);
                const rhs_elem = rhs.elemValueBuffer(mod, i, &rhs_buf);
                scalar.* = try bitwiseNandScalar(lhs_elem, rhs_elem, ty.scalarType(), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return bitwiseNandScalar(lhs, rhs, ty, arena, mod);
    }

    /// operands must be integers; handles undefined.
    pub fn bitwiseNandScalar(lhs: Value, rhs: Value, ty: Type, arena: Allocator, mod: *Module) !Value {
        if (lhs.isUndef() or rhs.isUndef()) return Value.initTag(.undef);

        const anded = try bitwiseAnd(lhs, rhs, ty, arena, mod);

        const all_ones = if (ty.isSignedInt())
            try Value.Tag.int_i64.create(arena, -1)
        else
            try ty.maxInt(arena, mod.getTarget());

        return bitwiseXor(anded, all_ones, ty, arena, mod);
    }

    /// operands must be (vectors of) integers; handles undefined scalars.
    pub fn bitwiseOr(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
        const target = mod.getTarget();
        if (ty.zigTypeTag() == .Vector) {
            const result_data = try allocator.alloc(Value, ty.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var lhs_buf: Value.ElemValueBuffer = undefined;
                var rhs_buf: Value.ElemValueBuffer = undefined;
                const lhs_elem = lhs.elemValueBuffer(mod, i, &lhs_buf);
                const rhs_elem = rhs.elemValueBuffer(mod, i, &rhs_buf);
                scalar.* = try bitwiseOrScalar(lhs_elem, rhs_elem, allocator, target);
            }
            return Value.Tag.aggregate.create(allocator, result_data);
        }
        return bitwiseOrScalar(lhs, rhs, allocator, target);
    }

    /// operands must be integers; handles undefined.
    pub fn bitwiseOrScalar(lhs: Value, rhs: Value, arena: Allocator, target: Target) !Value {
        if (lhs.isUndef() or rhs.isUndef()) return Value.initTag(.undef);

        // TODO is this a performance issue? maybe we should try the operation without
        // resorting to BigInt first.
        var lhs_space: Value.BigIntSpace = undefined;
        var rhs_space: Value.BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_space, target);
        const rhs_bigint = rhs.toBigInt(&rhs_space, target);
        const limbs = try arena.alloc(
            std.math.big.Limb,
            std.math.max(lhs_bigint.limbs.len, rhs_bigint.limbs.len),
        );
        var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
        result_bigint.bitOr(lhs_bigint, rhs_bigint);
        return fromBigInt(arena, result_bigint.toConst());
    }

    /// operands must be (vectors of) integers; handles undefined scalars.
    pub fn bitwiseXor(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
        const target = mod.getTarget();
        if (ty.zigTypeTag() == .Vector) {
            const result_data = try allocator.alloc(Value, ty.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var lhs_buf: Value.ElemValueBuffer = undefined;
                var rhs_buf: Value.ElemValueBuffer = undefined;
                const lhs_elem = lhs.elemValueBuffer(mod, i, &lhs_buf);
                const rhs_elem = rhs.elemValueBuffer(mod, i, &rhs_buf);
                scalar.* = try bitwiseXorScalar(lhs_elem, rhs_elem, allocator, target);
            }
            return Value.Tag.aggregate.create(allocator, result_data);
        }
        return bitwiseXorScalar(lhs, rhs, allocator, target);
    }

    /// operands must be integers; handles undefined.
    pub fn bitwiseXorScalar(lhs: Value, rhs: Value, arena: Allocator, target: Target) !Value {
        if (lhs.isUndef() or rhs.isUndef()) return Value.initTag(.undef);

        // TODO is this a performance issue? maybe we should try the operation without
        // resorting to BigInt first.
        var lhs_space: Value.BigIntSpace = undefined;
        var rhs_space: Value.BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_space, target);
        const rhs_bigint = rhs.toBigInt(&rhs_space, target);
        const limbs = try arena.alloc(
            std.math.big.Limb,
            // + 1 for negatives
            std.math.max(lhs_bigint.limbs.len, rhs_bigint.limbs.len) + 1,
        );
        var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
        result_bigint.bitXor(lhs_bigint, rhs_bigint);
        return fromBigInt(arena, result_bigint.toConst());
    }

    pub fn intDiv(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
        const target = mod.getTarget();
        if (ty.zigTypeTag() == .Vector) {
            const result_data = try allocator.alloc(Value, ty.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var lhs_buf: Value.ElemValueBuffer = undefined;
                var rhs_buf: Value.ElemValueBuffer = undefined;
                const lhs_elem = lhs.elemValueBuffer(mod, i, &lhs_buf);
                const rhs_elem = rhs.elemValueBuffer(mod, i, &rhs_buf);
                scalar.* = try intDivScalar(lhs_elem, rhs_elem, allocator, target);
            }
            return Value.Tag.aggregate.create(allocator, result_data);
        }
        return intDivScalar(lhs, rhs, allocator, target);
    }

    pub fn intDivScalar(lhs: Value, rhs: Value, allocator: Allocator, target: Target) !Value {
        // TODO is this a performance issue? maybe we should try the operation without
        // resorting to BigInt first.
        var lhs_space: Value.BigIntSpace = undefined;
        var rhs_space: Value.BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_space, target);
        const rhs_bigint = rhs.toBigInt(&rhs_space, target);
        const limbs_q = try allocator.alloc(
            std.math.big.Limb,
            lhs_bigint.limbs.len,
        );
        const limbs_r = try allocator.alloc(
            std.math.big.Limb,
            rhs_bigint.limbs.len,
        );
        const limbs_buffer = try allocator.alloc(
            std.math.big.Limb,
            std.math.big.int.calcDivLimbsBufferLen(lhs_bigint.limbs.len, rhs_bigint.limbs.len),
        );
        var result_q = BigIntMutable{ .limbs = limbs_q, .positive = undefined, .len = undefined };
        var result_r = BigIntMutable{ .limbs = limbs_r, .positive = undefined, .len = undefined };
        result_q.divTrunc(&result_r, lhs_bigint, rhs_bigint, limbs_buffer);
        return fromBigInt(allocator, result_q.toConst());
    }

    pub fn intDivFloor(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
        const target = mod.getTarget();
        if (ty.zigTypeTag() == .Vector) {
            const result_data = try allocator.alloc(Value, ty.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var lhs_buf: Value.ElemValueBuffer = undefined;
                var rhs_buf: Value.ElemValueBuffer = undefined;
                const lhs_elem = lhs.elemValueBuffer(mod, i, &lhs_buf);
                const rhs_elem = rhs.elemValueBuffer(mod, i, &rhs_buf);
                scalar.* = try intDivFloorScalar(lhs_elem, rhs_elem, allocator, target);
            }
            return Value.Tag.aggregate.create(allocator, result_data);
        }
        return intDivFloorScalar(lhs, rhs, allocator, target);
    }

    pub fn intDivFloorScalar(lhs: Value, rhs: Value, allocator: Allocator, target: Target) !Value {
        // TODO is this a performance issue? maybe we should try the operation without
        // resorting to BigInt first.
        var lhs_space: Value.BigIntSpace = undefined;
        var rhs_space: Value.BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_space, target);
        const rhs_bigint = rhs.toBigInt(&rhs_space, target);
        const limbs_q = try allocator.alloc(
            std.math.big.Limb,
            lhs_bigint.limbs.len,
        );
        const limbs_r = try allocator.alloc(
            std.math.big.Limb,
            rhs_bigint.limbs.len,
        );
        const limbs_buffer = try allocator.alloc(
            std.math.big.Limb,
            std.math.big.int.calcDivLimbsBufferLen(lhs_bigint.limbs.len, rhs_bigint.limbs.len),
        );
        var result_q = BigIntMutable{ .limbs = limbs_q, .positive = undefined, .len = undefined };
        var result_r = BigIntMutable{ .limbs = limbs_r, .positive = undefined, .len = undefined };
        result_q.divFloor(&result_r, lhs_bigint, rhs_bigint, limbs_buffer);
        return fromBigInt(allocator, result_q.toConst());
    }

    pub fn intMod(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
        const target = mod.getTarget();
        if (ty.zigTypeTag() == .Vector) {
            const result_data = try allocator.alloc(Value, ty.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var lhs_buf: Value.ElemValueBuffer = undefined;
                var rhs_buf: Value.ElemValueBuffer = undefined;
                const lhs_elem = lhs.elemValueBuffer(mod, i, &lhs_buf);
                const rhs_elem = rhs.elemValueBuffer(mod, i, &rhs_buf);
                scalar.* = try intModScalar(lhs_elem, rhs_elem, allocator, target);
            }
            return Value.Tag.aggregate.create(allocator, result_data);
        }
        return intModScalar(lhs, rhs, allocator, target);
    }

    pub fn intModScalar(lhs: Value, rhs: Value, allocator: Allocator, target: Target) !Value {
        // TODO is this a performance issue? maybe we should try the operation without
        // resorting to BigInt first.
        var lhs_space: Value.BigIntSpace = undefined;
        var rhs_space: Value.BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_space, target);
        const rhs_bigint = rhs.toBigInt(&rhs_space, target);
        const limbs_q = try allocator.alloc(
            std.math.big.Limb,
            lhs_bigint.limbs.len,
        );
        const limbs_r = try allocator.alloc(
            std.math.big.Limb,
            rhs_bigint.limbs.len,
        );
        const limbs_buffer = try allocator.alloc(
            std.math.big.Limb,
            std.math.big.int.calcDivLimbsBufferLen(lhs_bigint.limbs.len, rhs_bigint.limbs.len),
        );
        var result_q = BigIntMutable{ .limbs = limbs_q, .positive = undefined, .len = undefined };
        var result_r = BigIntMutable{ .limbs = limbs_r, .positive = undefined, .len = undefined };
        result_q.divFloor(&result_r, lhs_bigint, rhs_bigint, limbs_buffer);
        return fromBigInt(allocator, result_r.toConst());
    }

    /// Returns true if the value is a floating point type and is NaN. Returns false otherwise.
    pub fn isNan(val: Value) bool {
        return switch (val.tag()) {
            .float_16 => std.math.isNan(val.castTag(.float_16).?.data),
            .float_32 => std.math.isNan(val.castTag(.float_32).?.data),
            .float_64 => std.math.isNan(val.castTag(.float_64).?.data),
            .float_80 => std.math.isNan(val.castTag(.float_80).?.data),
            .float_128 => std.math.isNan(val.castTag(.float_128).?.data),
            else => false,
        };
    }

    /// Returns true if the value is a floating point type and is infinite. Returns false otherwise.
    pub fn isInf(val: Value) bool {
        return switch (val.tag()) {
            .float_16 => std.math.isInf(val.castTag(.float_16).?.data),
            .float_32 => std.math.isInf(val.castTag(.float_32).?.data),
            .float_64 => std.math.isInf(val.castTag(.float_64).?.data),
            .float_80 => std.math.isInf(val.castTag(.float_80).?.data),
            .float_128 => std.math.isInf(val.castTag(.float_128).?.data),
            else => false,
        };
    }

    pub fn isNegativeInf(val: Value) bool {
        return switch (val.tag()) {
            .float_16 => std.math.isNegativeInf(val.castTag(.float_16).?.data),
            .float_32 => std.math.isNegativeInf(val.castTag(.float_32).?.data),
            .float_64 => std.math.isNegativeInf(val.castTag(.float_64).?.data),
            .float_80 => std.math.isNegativeInf(val.castTag(.float_80).?.data),
            .float_128 => std.math.isNegativeInf(val.castTag(.float_128).?.data),
            else => false,
        };
    }

    pub fn floatRem(lhs: Value, rhs: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        const target = mod.getTarget();
        if (float_type.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var lhs_buf: Value.ElemValueBuffer = undefined;
                var rhs_buf: Value.ElemValueBuffer = undefined;
                const lhs_elem = lhs.elemValueBuffer(mod, i, &lhs_buf);
                const rhs_elem = rhs.elemValueBuffer(mod, i, &rhs_buf);
                scalar.* = try floatRemScalar(lhs_elem, rhs_elem, float_type.scalarType(), arena, target);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return floatRemScalar(lhs, rhs, float_type, arena, target);
    }

    pub fn floatRemScalar(lhs: Value, rhs: Value, float_type: Type, arena: Allocator, target: Target) !Value {
        switch (float_type.floatBits(target)) {
            16 => {
                const lhs_val = lhs.toFloat(f16);
                const rhs_val = rhs.toFloat(f16);
                return Value.Tag.float_16.create(arena, @rem(lhs_val, rhs_val));
            },
            32 => {
                const lhs_val = lhs.toFloat(f32);
                const rhs_val = rhs.toFloat(f32);
                return Value.Tag.float_32.create(arena, @rem(lhs_val, rhs_val));
            },
            64 => {
                const lhs_val = lhs.toFloat(f64);
                const rhs_val = rhs.toFloat(f64);
                return Value.Tag.float_64.create(arena, @rem(lhs_val, rhs_val));
            },
            80 => {
                const lhs_val = lhs.toFloat(f80);
                const rhs_val = rhs.toFloat(f80);
                return Value.Tag.float_80.create(arena, @rem(lhs_val, rhs_val));
            },
            128 => {
                const lhs_val = lhs.toFloat(f128);
                const rhs_val = rhs.toFloat(f128);
                return Value.Tag.float_128.create(arena, @rem(lhs_val, rhs_val));
            },
            else => unreachable,
        }
    }

    pub fn floatMod(lhs: Value, rhs: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        const target = mod.getTarget();
        if (float_type.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var lhs_buf: Value.ElemValueBuffer = undefined;
                var rhs_buf: Value.ElemValueBuffer = undefined;
                const lhs_elem = lhs.elemValueBuffer(mod, i, &lhs_buf);
                const rhs_elem = rhs.elemValueBuffer(mod, i, &rhs_buf);
                scalar.* = try floatModScalar(lhs_elem, rhs_elem, float_type.scalarType(), arena, target);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return floatModScalar(lhs, rhs, float_type, arena, target);
    }

    pub fn floatModScalar(lhs: Value, rhs: Value, float_type: Type, arena: Allocator, target: Target) !Value {
        switch (float_type.floatBits(target)) {
            16 => {
                const lhs_val = lhs.toFloat(f16);
                const rhs_val = rhs.toFloat(f16);
                return Value.Tag.float_16.create(arena, @mod(lhs_val, rhs_val));
            },
            32 => {
                const lhs_val = lhs.toFloat(f32);
                const rhs_val = rhs.toFloat(f32);
                return Value.Tag.float_32.create(arena, @mod(lhs_val, rhs_val));
            },
            64 => {
                const lhs_val = lhs.toFloat(f64);
                const rhs_val = rhs.toFloat(f64);
                return Value.Tag.float_64.create(arena, @mod(lhs_val, rhs_val));
            },
            80 => {
                const lhs_val = lhs.toFloat(f80);
                const rhs_val = rhs.toFloat(f80);
                return Value.Tag.float_80.create(arena, @mod(lhs_val, rhs_val));
            },
            128 => {
                const lhs_val = lhs.toFloat(f128);
                const rhs_val = rhs.toFloat(f128);
                return Value.Tag.float_128.create(arena, @mod(lhs_val, rhs_val));
            },
            else => unreachable,
        }
    }

    pub fn intMul(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
        const target = mod.getTarget();
        if (ty.zigTypeTag() == .Vector) {
            const result_data = try allocator.alloc(Value, ty.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var lhs_buf: Value.ElemValueBuffer = undefined;
                var rhs_buf: Value.ElemValueBuffer = undefined;
                const lhs_elem = lhs.elemValueBuffer(mod, i, &lhs_buf);
                const rhs_elem = rhs.elemValueBuffer(mod, i, &rhs_buf);
                scalar.* = try intMulScalar(lhs_elem, rhs_elem, allocator, target);
            }
            return Value.Tag.aggregate.create(allocator, result_data);
        }
        return intMulScalar(lhs, rhs, allocator, target);
    }

    pub fn intMulScalar(lhs: Value, rhs: Value, allocator: Allocator, target: Target) !Value {
        // TODO is this a performance issue? maybe we should try the operation without
        // resorting to BigInt first.
        var lhs_space: Value.BigIntSpace = undefined;
        var rhs_space: Value.BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_space, target);
        const rhs_bigint = rhs.toBigInt(&rhs_space, target);
        const limbs = try allocator.alloc(
            std.math.big.Limb,
            lhs_bigint.limbs.len + rhs_bigint.limbs.len,
        );
        var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
        var limbs_buffer = try allocator.alloc(
            std.math.big.Limb,
            std.math.big.int.calcMulLimbsBufferLen(lhs_bigint.limbs.len, rhs_bigint.limbs.len, 1),
        );
        defer allocator.free(limbs_buffer);
        result_bigint.mul(lhs_bigint, rhs_bigint, limbs_buffer, allocator);
        return fromBigInt(allocator, result_bigint.toConst());
    }

    pub fn intTrunc(val: Value, ty: Type, allocator: Allocator, signedness: std.builtin.Signedness, bits: u16, mod: *Module) !Value {
        const target = mod.getTarget();
        if (ty.zigTypeTag() == .Vector) {
            const result_data = try allocator.alloc(Value, ty.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var buf: Value.ElemValueBuffer = undefined;
                const elem_val = val.elemValueBuffer(mod, i, &buf);
                scalar.* = try intTruncScalar(elem_val, allocator, signedness, bits, target);
            }
            return Value.Tag.aggregate.create(allocator, result_data);
        }
        return intTruncScalar(val, allocator, signedness, bits, target);
    }

    /// This variant may vectorize on `bits`. Asserts that `bits` is a (vector of) `u16`.
    pub fn intTruncBitsAsValue(
        val: Value,
        ty: Type,
        allocator: Allocator,
        signedness: std.builtin.Signedness,
        bits: Value,
        mod: *Module,
    ) !Value {
        const target = mod.getTarget();
        if (ty.zigTypeTag() == .Vector) {
            const result_data = try allocator.alloc(Value, ty.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var buf: Value.ElemValueBuffer = undefined;
                const elem_val = val.elemValueBuffer(mod, i, &buf);
                var bits_buf: Value.ElemValueBuffer = undefined;
                const bits_elem = bits.elemValueBuffer(mod, i, &bits_buf);
                scalar.* = try intTruncScalar(elem_val, allocator, signedness, @intCast(u16, bits_elem.toUnsignedInt(target)), target);
            }
            return Value.Tag.aggregate.create(allocator, result_data);
        }
        return intTruncScalar(val, allocator, signedness, @intCast(u16, bits.toUnsignedInt(target)), target);
    }

    pub fn intTruncScalar(val: Value, allocator: Allocator, signedness: std.builtin.Signedness, bits: u16, target: Target) !Value {
        if (bits == 0) return Value.zero;

        var val_space: Value.BigIntSpace = undefined;
        const val_bigint = val.toBigInt(&val_space, target);

        const limbs = try allocator.alloc(
            std.math.big.Limb,
            std.math.big.int.calcTwosCompLimbCount(bits),
        );
        var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };

        result_bigint.truncate(val_bigint, signedness, bits);
        return fromBigInt(allocator, result_bigint.toConst());
    }

    pub fn shl(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
        const target = mod.getTarget();
        if (ty.zigTypeTag() == .Vector) {
            const result_data = try allocator.alloc(Value, ty.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var lhs_buf: Value.ElemValueBuffer = undefined;
                var rhs_buf: Value.ElemValueBuffer = undefined;
                const lhs_elem = lhs.elemValueBuffer(mod, i, &lhs_buf);
                const rhs_elem = rhs.elemValueBuffer(mod, i, &rhs_buf);
                scalar.* = try shlScalar(lhs_elem, rhs_elem, allocator, target);
            }
            return Value.Tag.aggregate.create(allocator, result_data);
        }
        return shlScalar(lhs, rhs, allocator, target);
    }

    pub fn shlScalar(lhs: Value, rhs: Value, allocator: Allocator, target: Target) !Value {
        // TODO is this a performance issue? maybe we should try the operation without
        // resorting to BigInt first.
        var lhs_space: Value.BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_space, target);
        const shift = @intCast(usize, rhs.toUnsignedInt(target));
        const limbs = try allocator.alloc(
            std.math.big.Limb,
            lhs_bigint.limbs.len + (shift / (@sizeOf(std.math.big.Limb) * 8)) + 1,
        );
        var result_bigint = BigIntMutable{
            .limbs = limbs,
            .positive = undefined,
            .len = undefined,
        };
        result_bigint.shiftLeft(lhs_bigint, shift);
        return fromBigInt(allocator, result_bigint.toConst());
    }

    pub fn shlWithOverflow(
        lhs: Value,
        rhs: Value,
        ty: Type,
        allocator: Allocator,
        mod: *Module,
    ) !OverflowArithmeticResult {
        const target = mod.getTarget();
        if (ty.zigTypeTag() == .Vector) {
            const overflowed_data = try allocator.alloc(Value, ty.vectorLen());
            const result_data = try allocator.alloc(Value, ty.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var lhs_buf: Value.ElemValueBuffer = undefined;
                var rhs_buf: Value.ElemValueBuffer = undefined;
                const lhs_elem = lhs.elemValueBuffer(mod, i, &lhs_buf);
                const rhs_elem = rhs.elemValueBuffer(mod, i, &rhs_buf);
                const of_math_result = try shlWithOverflowScalar(lhs_elem, rhs_elem, ty.scalarType(), allocator, target);
                overflowed_data[i] = of_math_result.overflow_bit;
                scalar.* = of_math_result.wrapped_result;
            }
            return OverflowArithmeticResult{
                .overflow_bit = try Value.Tag.aggregate.create(allocator, overflowed_data),
                .wrapped_result = try Value.Tag.aggregate.create(allocator, result_data),
            };
        }
        return shlWithOverflowScalar(lhs, rhs, ty, allocator, target);
    }

    pub fn shlWithOverflowScalar(
        lhs: Value,
        rhs: Value,
        ty: Type,
        allocator: Allocator,
        target: Target,
    ) !OverflowArithmeticResult {
        const info = ty.intInfo(target);
        var lhs_space: Value.BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_space, target);
        const shift = @intCast(usize, rhs.toUnsignedInt(target));
        const limbs = try allocator.alloc(
            std.math.big.Limb,
            lhs_bigint.limbs.len + (shift / (@sizeOf(std.math.big.Limb) * 8)) + 1,
        );
        var result_bigint = BigIntMutable{
            .limbs = limbs,
            .positive = undefined,
            .len = undefined,
        };
        result_bigint.shiftLeft(lhs_bigint, shift);
        const overflowed = !result_bigint.toConst().fitsInTwosComp(info.signedness, info.bits);
        if (overflowed) {
            result_bigint.truncate(result_bigint.toConst(), info.signedness, info.bits);
        }
        return OverflowArithmeticResult{
            .overflow_bit = boolToInt(overflowed),
            .wrapped_result = try fromBigInt(allocator, result_bigint.toConst()),
        };
    }

    pub fn shlSat(
        lhs: Value,
        rhs: Value,
        ty: Type,
        arena: Allocator,
        mod: *Module,
    ) !Value {
        const target = mod.getTarget();
        if (ty.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, ty.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var lhs_buf: Value.ElemValueBuffer = undefined;
                var rhs_buf: Value.ElemValueBuffer = undefined;
                const lhs_elem = lhs.elemValueBuffer(mod, i, &lhs_buf);
                const rhs_elem = rhs.elemValueBuffer(mod, i, &rhs_buf);
                scalar.* = try shlSatScalar(lhs_elem, rhs_elem, ty.scalarType(), arena, target);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return shlSatScalar(lhs, rhs, ty, arena, target);
    }

    pub fn shlSatScalar(
        lhs: Value,
        rhs: Value,
        ty: Type,
        arena: Allocator,
        target: Target,
    ) !Value {
        // TODO is this a performance issue? maybe we should try the operation without
        // resorting to BigInt first.
        const info = ty.intInfo(target);

        var lhs_space: Value.BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_space, target);
        const shift = @intCast(usize, rhs.toUnsignedInt(target));
        const limbs = try arena.alloc(
            std.math.big.Limb,
            std.math.big.int.calcTwosCompLimbCount(info.bits) + 1,
        );
        var result_bigint = BigIntMutable{
            .limbs = limbs,
            .positive = undefined,
            .len = undefined,
        };
        result_bigint.shiftLeftSat(lhs_bigint, shift, info.signedness, info.bits);
        return fromBigInt(arena, result_bigint.toConst());
    }

    pub fn shlTrunc(
        lhs: Value,
        rhs: Value,
        ty: Type,
        arena: Allocator,
        mod: *Module,
    ) !Value {
        if (ty.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, ty.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var lhs_buf: Value.ElemValueBuffer = undefined;
                var rhs_buf: Value.ElemValueBuffer = undefined;
                const lhs_elem = lhs.elemValueBuffer(mod, i, &lhs_buf);
                const rhs_elem = rhs.elemValueBuffer(mod, i, &rhs_buf);
                scalar.* = try shlTruncScalar(lhs_elem, rhs_elem, ty.scalarType(), arena, mod);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return shlTruncScalar(lhs, rhs, ty, arena, mod);
    }

    pub fn shlTruncScalar(
        lhs: Value,
        rhs: Value,
        ty: Type,
        arena: Allocator,
        mod: *Module,
    ) !Value {
        const shifted = try lhs.shl(rhs, ty, arena, mod);
        const int_info = ty.intInfo(mod.getTarget());
        const truncated = try shifted.intTrunc(ty, arena, int_info.signedness, int_info.bits, mod);
        return truncated;
    }

    pub fn shr(lhs: Value, rhs: Value, ty: Type, allocator: Allocator, mod: *Module) !Value {
        const target = mod.getTarget();
        if (ty.zigTypeTag() == .Vector) {
            const result_data = try allocator.alloc(Value, ty.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var lhs_buf: Value.ElemValueBuffer = undefined;
                var rhs_buf: Value.ElemValueBuffer = undefined;
                const lhs_elem = lhs.elemValueBuffer(mod, i, &lhs_buf);
                const rhs_elem = rhs.elemValueBuffer(mod, i, &rhs_buf);
                scalar.* = try shrScalar(lhs_elem, rhs_elem, allocator, target);
            }
            return Value.Tag.aggregate.create(allocator, result_data);
        }
        return shrScalar(lhs, rhs, allocator, target);
    }

    pub fn shrScalar(lhs: Value, rhs: Value, allocator: Allocator, target: Target) !Value {
        // TODO is this a performance issue? maybe we should try the operation without
        // resorting to BigInt first.
        var lhs_space: Value.BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_space, target);
        const shift = @intCast(usize, rhs.toUnsignedInt(target));

        const result_limbs = lhs_bigint.limbs.len -| (shift / (@sizeOf(std.math.big.Limb) * 8));
        if (result_limbs == 0) {
            // The shift is enough to remove all the bits from the number, which means the
            // result is 0 or -1 depending on the sign.
            if (lhs_bigint.positive) {
                return Value.zero;
            } else {
                return Value.negative_one;
            }
        }

        const limbs = try allocator.alloc(
            std.math.big.Limb,
            result_limbs,
        );
        var result_bigint = BigIntMutable{
            .limbs = limbs,
            .positive = undefined,
            .len = undefined,
        };
        result_bigint.shiftRight(lhs_bigint, shift);
        return fromBigInt(allocator, result_bigint.toConst());
    }

    pub fn floatNeg(
        val: Value,
        float_type: Type,
        arena: Allocator,
        mod: *Module,
    ) !Value {
        const target = mod.getTarget();
        if (float_type.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var buf: Value.ElemValueBuffer = undefined;
                const elem_val = val.elemValueBuffer(mod, i, &buf);
                scalar.* = try floatNegScalar(elem_val, float_type.scalarType(), arena, target);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return floatNegScalar(val, float_type, arena, target);
    }

    pub fn floatNegScalar(
        val: Value,
        float_type: Type,
        arena: Allocator,
        target: Target,
    ) !Value {
        switch (float_type.floatBits(target)) {
            16 => return Value.Tag.float_16.create(arena, -val.toFloat(f16)),
            32 => return Value.Tag.float_32.create(arena, -val.toFloat(f32)),
            64 => return Value.Tag.float_64.create(arena, -val.toFloat(f64)),
            80 => return Value.Tag.float_80.create(arena, -val.toFloat(f80)),
            128 => return Value.Tag.float_128.create(arena, -val.toFloat(f128)),
            else => unreachable,
        }
    }

    pub fn floatDiv(
        lhs: Value,
        rhs: Value,
        float_type: Type,
        arena: Allocator,
        mod: *Module,
    ) !Value {
        const target = mod.getTarget();
        if (float_type.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var lhs_buf: Value.ElemValueBuffer = undefined;
                var rhs_buf: Value.ElemValueBuffer = undefined;
                const lhs_elem = lhs.elemValueBuffer(mod, i, &lhs_buf);
                const rhs_elem = rhs.elemValueBuffer(mod, i, &rhs_buf);
                scalar.* = try floatDivScalar(lhs_elem, rhs_elem, float_type.scalarType(), arena, target);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return floatDivScalar(lhs, rhs, float_type, arena, target);
    }

    pub fn floatDivScalar(
        lhs: Value,
        rhs: Value,
        float_type: Type,
        arena: Allocator,
        target: Target,
    ) !Value {
        switch (float_type.floatBits(target)) {
            16 => {
                const lhs_val = lhs.toFloat(f16);
                const rhs_val = rhs.toFloat(f16);
                return Value.Tag.float_16.create(arena, lhs_val / rhs_val);
            },
            32 => {
                const lhs_val = lhs.toFloat(f32);
                const rhs_val = rhs.toFloat(f32);
                return Value.Tag.float_32.create(arena, lhs_val / rhs_val);
            },
            64 => {
                const lhs_val = lhs.toFloat(f64);
                const rhs_val = rhs.toFloat(f64);
                return Value.Tag.float_64.create(arena, lhs_val / rhs_val);
            },
            80 => {
                const lhs_val = lhs.toFloat(f80);
                const rhs_val = rhs.toFloat(f80);
                return Value.Tag.float_80.create(arena, lhs_val / rhs_val);
            },
            128 => {
                const lhs_val = lhs.toFloat(f128);
                const rhs_val = rhs.toFloat(f128);
                return Value.Tag.float_128.create(arena, lhs_val / rhs_val);
            },
            else => unreachable,
        }
    }

    pub fn floatDivFloor(
        lhs: Value,
        rhs: Value,
        float_type: Type,
        arena: Allocator,
        mod: *Module,
    ) !Value {
        const target = mod.getTarget();
        if (float_type.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var lhs_buf: Value.ElemValueBuffer = undefined;
                var rhs_buf: Value.ElemValueBuffer = undefined;
                const lhs_elem = lhs.elemValueBuffer(mod, i, &lhs_buf);
                const rhs_elem = rhs.elemValueBuffer(mod, i, &rhs_buf);
                scalar.* = try floatDivFloorScalar(lhs_elem, rhs_elem, float_type.scalarType(), arena, target);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return floatDivFloorScalar(lhs, rhs, float_type, arena, target);
    }

    pub fn floatDivFloorScalar(
        lhs: Value,
        rhs: Value,
        float_type: Type,
        arena: Allocator,
        target: Target,
    ) !Value {
        switch (float_type.floatBits(target)) {
            16 => {
                const lhs_val = lhs.toFloat(f16);
                const rhs_val = rhs.toFloat(f16);
                return Value.Tag.float_16.create(arena, @divFloor(lhs_val, rhs_val));
            },
            32 => {
                const lhs_val = lhs.toFloat(f32);
                const rhs_val = rhs.toFloat(f32);
                return Value.Tag.float_32.create(arena, @divFloor(lhs_val, rhs_val));
            },
            64 => {
                const lhs_val = lhs.toFloat(f64);
                const rhs_val = rhs.toFloat(f64);
                return Value.Tag.float_64.create(arena, @divFloor(lhs_val, rhs_val));
            },
            80 => {
                const lhs_val = lhs.toFloat(f80);
                const rhs_val = rhs.toFloat(f80);
                return Value.Tag.float_80.create(arena, @divFloor(lhs_val, rhs_val));
            },
            128 => {
                const lhs_val = lhs.toFloat(f128);
                const rhs_val = rhs.toFloat(f128);
                return Value.Tag.float_128.create(arena, @divFloor(lhs_val, rhs_val));
            },
            else => unreachable,
        }
    }

    pub fn floatDivTrunc(
        lhs: Value,
        rhs: Value,
        float_type: Type,
        arena: Allocator,
        mod: *Module,
    ) !Value {
        const target = mod.getTarget();
        if (float_type.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var lhs_buf: Value.ElemValueBuffer = undefined;
                var rhs_buf: Value.ElemValueBuffer = undefined;
                const lhs_elem = lhs.elemValueBuffer(mod, i, &lhs_buf);
                const rhs_elem = rhs.elemValueBuffer(mod, i, &rhs_buf);
                scalar.* = try floatDivTruncScalar(lhs_elem, rhs_elem, float_type.scalarType(), arena, target);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return floatDivTruncScalar(lhs, rhs, float_type, arena, target);
    }

    pub fn floatDivTruncScalar(
        lhs: Value,
        rhs: Value,
        float_type: Type,
        arena: Allocator,
        target: Target,
    ) !Value {
        switch (float_type.floatBits(target)) {
            16 => {
                const lhs_val = lhs.toFloat(f16);
                const rhs_val = rhs.toFloat(f16);
                return Value.Tag.float_16.create(arena, @divTrunc(lhs_val, rhs_val));
            },
            32 => {
                const lhs_val = lhs.toFloat(f32);
                const rhs_val = rhs.toFloat(f32);
                return Value.Tag.float_32.create(arena, @divTrunc(lhs_val, rhs_val));
            },
            64 => {
                const lhs_val = lhs.toFloat(f64);
                const rhs_val = rhs.toFloat(f64);
                return Value.Tag.float_64.create(arena, @divTrunc(lhs_val, rhs_val));
            },
            80 => {
                const lhs_val = lhs.toFloat(f80);
                const rhs_val = rhs.toFloat(f80);
                return Value.Tag.float_80.create(arena, @divTrunc(lhs_val, rhs_val));
            },
            128 => {
                const lhs_val = lhs.toFloat(f128);
                const rhs_val = rhs.toFloat(f128);
                return Value.Tag.float_128.create(arena, @divTrunc(lhs_val, rhs_val));
            },
            else => unreachable,
        }
    }

    pub fn floatMul(
        lhs: Value,
        rhs: Value,
        float_type: Type,
        arena: Allocator,
        mod: *Module,
    ) !Value {
        const target = mod.getTarget();
        if (float_type.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var lhs_buf: Value.ElemValueBuffer = undefined;
                var rhs_buf: Value.ElemValueBuffer = undefined;
                const lhs_elem = lhs.elemValueBuffer(mod, i, &lhs_buf);
                const rhs_elem = rhs.elemValueBuffer(mod, i, &rhs_buf);
                scalar.* = try floatMulScalar(lhs_elem, rhs_elem, float_type.scalarType(), arena, target);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return floatMulScalar(lhs, rhs, float_type, arena, target);
    }

    pub fn floatMulScalar(
        lhs: Value,
        rhs: Value,
        float_type: Type,
        arena: Allocator,
        target: Target,
    ) !Value {
        switch (float_type.floatBits(target)) {
            16 => {
                const lhs_val = lhs.toFloat(f16);
                const rhs_val = rhs.toFloat(f16);
                return Value.Tag.float_16.create(arena, lhs_val * rhs_val);
            },
            32 => {
                const lhs_val = lhs.toFloat(f32);
                const rhs_val = rhs.toFloat(f32);
                return Value.Tag.float_32.create(arena, lhs_val * rhs_val);
            },
            64 => {
                const lhs_val = lhs.toFloat(f64);
                const rhs_val = rhs.toFloat(f64);
                return Value.Tag.float_64.create(arena, lhs_val * rhs_val);
            },
            80 => {
                const lhs_val = lhs.toFloat(f80);
                const rhs_val = rhs.toFloat(f80);
                return Value.Tag.float_80.create(arena, lhs_val * rhs_val);
            },
            128 => {
                const lhs_val = lhs.toFloat(f128);
                const rhs_val = rhs.toFloat(f128);
                return Value.Tag.float_128.create(arena, lhs_val * rhs_val);
            },
            else => unreachable,
        }
    }

    pub fn sqrt(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        const target = mod.getTarget();
        if (float_type.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var buf: Value.ElemValueBuffer = undefined;
                const elem_val = val.elemValueBuffer(mod, i, &buf);
                scalar.* = try sqrtScalar(elem_val, float_type.scalarType(), arena, target);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return sqrtScalar(val, float_type, arena, target);
    }

    pub fn sqrtScalar(val: Value, float_type: Type, arena: Allocator, target: Target) Allocator.Error!Value {
        switch (float_type.floatBits(target)) {
            16 => {
                const f = val.toFloat(f16);
                return Value.Tag.float_16.create(arena, @sqrt(f));
            },
            32 => {
                const f = val.toFloat(f32);
                return Value.Tag.float_32.create(arena, @sqrt(f));
            },
            64 => {
                const f = val.toFloat(f64);
                return Value.Tag.float_64.create(arena, @sqrt(f));
            },
            80 => {
                const f = val.toFloat(f80);
                return Value.Tag.float_80.create(arena, @sqrt(f));
            },
            128 => {
                const f = val.toFloat(f128);
                return Value.Tag.float_128.create(arena, @sqrt(f));
            },
            else => unreachable,
        }
    }

    pub fn sin(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        const target = mod.getTarget();
        if (float_type.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var buf: Value.ElemValueBuffer = undefined;
                const elem_val = val.elemValueBuffer(mod, i, &buf);
                scalar.* = try sinScalar(elem_val, float_type.scalarType(), arena, target);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return sinScalar(val, float_type, arena, target);
    }

    pub fn sinScalar(val: Value, float_type: Type, arena: Allocator, target: Target) Allocator.Error!Value {
        switch (float_type.floatBits(target)) {
            16 => {
                const f = val.toFloat(f16);
                return Value.Tag.float_16.create(arena, @sin(f));
            },
            32 => {
                const f = val.toFloat(f32);
                return Value.Tag.float_32.create(arena, @sin(f));
            },
            64 => {
                const f = val.toFloat(f64);
                return Value.Tag.float_64.create(arena, @sin(f));
            },
            80 => {
                const f = val.toFloat(f80);
                return Value.Tag.float_80.create(arena, @sin(f));
            },
            128 => {
                const f = val.toFloat(f128);
                return Value.Tag.float_128.create(arena, @sin(f));
            },
            else => unreachable,
        }
    }

    pub fn cos(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        const target = mod.getTarget();
        if (float_type.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var buf: Value.ElemValueBuffer = undefined;
                const elem_val = val.elemValueBuffer(mod, i, &buf);
                scalar.* = try cosScalar(elem_val, float_type.scalarType(), arena, target);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return cosScalar(val, float_type, arena, target);
    }

    pub fn cosScalar(val: Value, float_type: Type, arena: Allocator, target: Target) Allocator.Error!Value {
        switch (float_type.floatBits(target)) {
            16 => {
                const f = val.toFloat(f16);
                return Value.Tag.float_16.create(arena, @cos(f));
            },
            32 => {
                const f = val.toFloat(f32);
                return Value.Tag.float_32.create(arena, @cos(f));
            },
            64 => {
                const f = val.toFloat(f64);
                return Value.Tag.float_64.create(arena, @cos(f));
            },
            80 => {
                const f = val.toFloat(f80);
                return Value.Tag.float_80.create(arena, @cos(f));
            },
            128 => {
                const f = val.toFloat(f128);
                return Value.Tag.float_128.create(arena, @cos(f));
            },
            else => unreachable,
        }
    }

    pub fn tan(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        const target = mod.getTarget();
        if (float_type.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var buf: Value.ElemValueBuffer = undefined;
                const elem_val = val.elemValueBuffer(mod, i, &buf);
                scalar.* = try tanScalar(elem_val, float_type.scalarType(), arena, target);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return tanScalar(val, float_type, arena, target);
    }

    pub fn tanScalar(val: Value, float_type: Type, arena: Allocator, target: Target) Allocator.Error!Value {
        switch (float_type.floatBits(target)) {
            16 => {
                const f = val.toFloat(f16);
                return Value.Tag.float_16.create(arena, @tan(f));
            },
            32 => {
                const f = val.toFloat(f32);
                return Value.Tag.float_32.create(arena, @tan(f));
            },
            64 => {
                const f = val.toFloat(f64);
                return Value.Tag.float_64.create(arena, @tan(f));
            },
            80 => {
                const f = val.toFloat(f80);
                return Value.Tag.float_80.create(arena, @tan(f));
            },
            128 => {
                const f = val.toFloat(f128);
                return Value.Tag.float_128.create(arena, @tan(f));
            },
            else => unreachable,
        }
    }

    pub fn exp(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        const target = mod.getTarget();
        if (float_type.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var buf: Value.ElemValueBuffer = undefined;
                const elem_val = val.elemValueBuffer(mod, i, &buf);
                scalar.* = try expScalar(elem_val, float_type.scalarType(), arena, target);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return expScalar(val, float_type, arena, target);
    }

    pub fn expScalar(val: Value, float_type: Type, arena: Allocator, target: Target) Allocator.Error!Value {
        switch (float_type.floatBits(target)) {
            16 => {
                const f = val.toFloat(f16);
                return Value.Tag.float_16.create(arena, @exp(f));
            },
            32 => {
                const f = val.toFloat(f32);
                return Value.Tag.float_32.create(arena, @exp(f));
            },
            64 => {
                const f = val.toFloat(f64);
                return Value.Tag.float_64.create(arena, @exp(f));
            },
            80 => {
                const f = val.toFloat(f80);
                return Value.Tag.float_80.create(arena, @exp(f));
            },
            128 => {
                const f = val.toFloat(f128);
                return Value.Tag.float_128.create(arena, @exp(f));
            },
            else => unreachable,
        }
    }

    pub fn exp2(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        const target = mod.getTarget();
        if (float_type.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var buf: Value.ElemValueBuffer = undefined;
                const elem_val = val.elemValueBuffer(mod, i, &buf);
                scalar.* = try exp2Scalar(elem_val, float_type.scalarType(), arena, target);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return exp2Scalar(val, float_type, arena, target);
    }

    pub fn exp2Scalar(val: Value, float_type: Type, arena: Allocator, target: Target) Allocator.Error!Value {
        switch (float_type.floatBits(target)) {
            16 => {
                const f = val.toFloat(f16);
                return Value.Tag.float_16.create(arena, @exp2(f));
            },
            32 => {
                const f = val.toFloat(f32);
                return Value.Tag.float_32.create(arena, @exp2(f));
            },
            64 => {
                const f = val.toFloat(f64);
                return Value.Tag.float_64.create(arena, @exp2(f));
            },
            80 => {
                const f = val.toFloat(f80);
                return Value.Tag.float_80.create(arena, @exp2(f));
            },
            128 => {
                const f = val.toFloat(f128);
                return Value.Tag.float_128.create(arena, @exp2(f));
            },
            else => unreachable,
        }
    }

    pub fn log(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        const target = mod.getTarget();
        if (float_type.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var buf: Value.ElemValueBuffer = undefined;
                const elem_val = val.elemValueBuffer(mod, i, &buf);
                scalar.* = try logScalar(elem_val, float_type.scalarType(), arena, target);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return logScalar(val, float_type, arena, target);
    }

    pub fn logScalar(val: Value, float_type: Type, arena: Allocator, target: Target) Allocator.Error!Value {
        switch (float_type.floatBits(target)) {
            16 => {
                const f = val.toFloat(f16);
                return Value.Tag.float_16.create(arena, @log(f));
            },
            32 => {
                const f = val.toFloat(f32);
                return Value.Tag.float_32.create(arena, @log(f));
            },
            64 => {
                const f = val.toFloat(f64);
                return Value.Tag.float_64.create(arena, @log(f));
            },
            80 => {
                const f = val.toFloat(f80);
                return Value.Tag.float_80.create(arena, @log(f));
            },
            128 => {
                const f = val.toFloat(f128);
                return Value.Tag.float_128.create(arena, @log(f));
            },
            else => unreachable,
        }
    }

    pub fn log2(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        const target = mod.getTarget();
        if (float_type.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var buf: Value.ElemValueBuffer = undefined;
                const elem_val = val.elemValueBuffer(mod, i, &buf);
                scalar.* = try log2Scalar(elem_val, float_type.scalarType(), arena, target);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return log2Scalar(val, float_type, arena, target);
    }

    pub fn log2Scalar(val: Value, float_type: Type, arena: Allocator, target: Target) Allocator.Error!Value {
        switch (float_type.floatBits(target)) {
            16 => {
                const f = val.toFloat(f16);
                return Value.Tag.float_16.create(arena, @log2(f));
            },
            32 => {
                const f = val.toFloat(f32);
                return Value.Tag.float_32.create(arena, @log2(f));
            },
            64 => {
                const f = val.toFloat(f64);
                return Value.Tag.float_64.create(arena, @log2(f));
            },
            80 => {
                const f = val.toFloat(f80);
                return Value.Tag.float_80.create(arena, @log2(f));
            },
            128 => {
                const f = val.toFloat(f128);
                return Value.Tag.float_128.create(arena, @log2(f));
            },
            else => unreachable,
        }
    }

    pub fn log10(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        const target = mod.getTarget();
        if (float_type.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var buf: Value.ElemValueBuffer = undefined;
                const elem_val = val.elemValueBuffer(mod, i, &buf);
                scalar.* = try log10Scalar(elem_val, float_type.scalarType(), arena, target);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return log10Scalar(val, float_type, arena, target);
    }

    pub fn log10Scalar(val: Value, float_type: Type, arena: Allocator, target: Target) Allocator.Error!Value {
        switch (float_type.floatBits(target)) {
            16 => {
                const f = val.toFloat(f16);
                return Value.Tag.float_16.create(arena, @log10(f));
            },
            32 => {
                const f = val.toFloat(f32);
                return Value.Tag.float_32.create(arena, @log10(f));
            },
            64 => {
                const f = val.toFloat(f64);
                return Value.Tag.float_64.create(arena, @log10(f));
            },
            80 => {
                const f = val.toFloat(f80);
                return Value.Tag.float_80.create(arena, @log10(f));
            },
            128 => {
                const f = val.toFloat(f128);
                return Value.Tag.float_128.create(arena, @log10(f));
            },
            else => unreachable,
        }
    }

    pub fn fabs(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        const target = mod.getTarget();
        if (float_type.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var buf: Value.ElemValueBuffer = undefined;
                const elem_val = val.elemValueBuffer(mod, i, &buf);
                scalar.* = try fabsScalar(elem_val, float_type.scalarType(), arena, target);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return fabsScalar(val, float_type, arena, target);
    }

    pub fn fabsScalar(val: Value, float_type: Type, arena: Allocator, target: Target) Allocator.Error!Value {
        switch (float_type.floatBits(target)) {
            16 => {
                const f = val.toFloat(f16);
                return Value.Tag.float_16.create(arena, @fabs(f));
            },
            32 => {
                const f = val.toFloat(f32);
                return Value.Tag.float_32.create(arena, @fabs(f));
            },
            64 => {
                const f = val.toFloat(f64);
                return Value.Tag.float_64.create(arena, @fabs(f));
            },
            80 => {
                const f = val.toFloat(f80);
                return Value.Tag.float_80.create(arena, @fabs(f));
            },
            128 => {
                const f = val.toFloat(f128);
                return Value.Tag.float_128.create(arena, @fabs(f));
            },
            else => unreachable,
        }
    }

    pub fn floor(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        const target = mod.getTarget();
        if (float_type.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var buf: Value.ElemValueBuffer = undefined;
                const elem_val = val.elemValueBuffer(mod, i, &buf);
                scalar.* = try floorScalar(elem_val, float_type.scalarType(), arena, target);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return floorScalar(val, float_type, arena, target);
    }

    pub fn floorScalar(val: Value, float_type: Type, arena: Allocator, target: Target) Allocator.Error!Value {
        switch (float_type.floatBits(target)) {
            16 => {
                const f = val.toFloat(f16);
                return Value.Tag.float_16.create(arena, @floor(f));
            },
            32 => {
                const f = val.toFloat(f32);
                return Value.Tag.float_32.create(arena, @floor(f));
            },
            64 => {
                const f = val.toFloat(f64);
                return Value.Tag.float_64.create(arena, @floor(f));
            },
            80 => {
                const f = val.toFloat(f80);
                return Value.Tag.float_80.create(arena, @floor(f));
            },
            128 => {
                const f = val.toFloat(f128);
                return Value.Tag.float_128.create(arena, @floor(f));
            },
            else => unreachable,
        }
    }

    pub fn ceil(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        const target = mod.getTarget();
        if (float_type.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var buf: Value.ElemValueBuffer = undefined;
                const elem_val = val.elemValueBuffer(mod, i, &buf);
                scalar.* = try ceilScalar(elem_val, float_type.scalarType(), arena, target);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return ceilScalar(val, float_type, arena, target);
    }

    pub fn ceilScalar(val: Value, float_type: Type, arena: Allocator, target: Target) Allocator.Error!Value {
        switch (float_type.floatBits(target)) {
            16 => {
                const f = val.toFloat(f16);
                return Value.Tag.float_16.create(arena, @ceil(f));
            },
            32 => {
                const f = val.toFloat(f32);
                return Value.Tag.float_32.create(arena, @ceil(f));
            },
            64 => {
                const f = val.toFloat(f64);
                return Value.Tag.float_64.create(arena, @ceil(f));
            },
            80 => {
                const f = val.toFloat(f80);
                return Value.Tag.float_80.create(arena, @ceil(f));
            },
            128 => {
                const f = val.toFloat(f128);
                return Value.Tag.float_128.create(arena, @ceil(f));
            },
            else => unreachable,
        }
    }

    pub fn round(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        const target = mod.getTarget();
        if (float_type.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var buf: Value.ElemValueBuffer = undefined;
                const elem_val = val.elemValueBuffer(mod, i, &buf);
                scalar.* = try roundScalar(elem_val, float_type.scalarType(), arena, target);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return roundScalar(val, float_type, arena, target);
    }

    pub fn roundScalar(val: Value, float_type: Type, arena: Allocator, target: Target) Allocator.Error!Value {
        switch (float_type.floatBits(target)) {
            16 => {
                const f = val.toFloat(f16);
                return Value.Tag.float_16.create(arena, @round(f));
            },
            32 => {
                const f = val.toFloat(f32);
                return Value.Tag.float_32.create(arena, @round(f));
            },
            64 => {
                const f = val.toFloat(f64);
                return Value.Tag.float_64.create(arena, @round(f));
            },
            80 => {
                const f = val.toFloat(f80);
                return Value.Tag.float_80.create(arena, @round(f));
            },
            128 => {
                const f = val.toFloat(f128);
                return Value.Tag.float_128.create(arena, @round(f));
            },
            else => unreachable,
        }
    }

    pub fn trunc(val: Value, float_type: Type, arena: Allocator, mod: *Module) !Value {
        const target = mod.getTarget();
        if (float_type.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var buf: Value.ElemValueBuffer = undefined;
                const elem_val = val.elemValueBuffer(mod, i, &buf);
                scalar.* = try truncScalar(elem_val, float_type.scalarType(), arena, target);
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return truncScalar(val, float_type, arena, target);
    }

    pub fn truncScalar(val: Value, float_type: Type, arena: Allocator, target: Target) Allocator.Error!Value {
        switch (float_type.floatBits(target)) {
            16 => {
                const f = val.toFloat(f16);
                return Value.Tag.float_16.create(arena, @trunc(f));
            },
            32 => {
                const f = val.toFloat(f32);
                return Value.Tag.float_32.create(arena, @trunc(f));
            },
            64 => {
                const f = val.toFloat(f64);
                return Value.Tag.float_64.create(arena, @trunc(f));
            },
            80 => {
                const f = val.toFloat(f80);
                return Value.Tag.float_80.create(arena, @trunc(f));
            },
            128 => {
                const f = val.toFloat(f128);
                return Value.Tag.float_128.create(arena, @trunc(f));
            },
            else => unreachable,
        }
    }

    pub fn mulAdd(
        float_type: Type,
        mulend1: Value,
        mulend2: Value,
        addend: Value,
        arena: Allocator,
        mod: *Module,
    ) !Value {
        const target = mod.getTarget();
        if (float_type.zigTypeTag() == .Vector) {
            const result_data = try arena.alloc(Value, float_type.vectorLen());
            for (result_data, 0..) |*scalar, i| {
                var mulend1_buf: Value.ElemValueBuffer = undefined;
                const mulend1_elem = mulend1.elemValueBuffer(mod, i, &mulend1_buf);
                var mulend2_buf: Value.ElemValueBuffer = undefined;
                const mulend2_elem = mulend2.elemValueBuffer(mod, i, &mulend2_buf);
                var addend_buf: Value.ElemValueBuffer = undefined;
                const addend_elem = addend.elemValueBuffer(mod, i, &addend_buf);
                scalar.* = try mulAddScalar(
                    float_type.scalarType(),
                    mulend1_elem,
                    mulend2_elem,
                    addend_elem,
                    arena,
                    target,
                );
            }
            return Value.Tag.aggregate.create(arena, result_data);
        }
        return mulAddScalar(float_type, mulend1, mulend2, addend, arena, target);
    }

    pub fn mulAddScalar(
        float_type: Type,
        mulend1: Value,
        mulend2: Value,
        addend: Value,
        arena: Allocator,
        target: Target,
    ) Allocator.Error!Value {
        switch (float_type.floatBits(target)) {
            16 => {
                const m1 = mulend1.toFloat(f16);
                const m2 = mulend2.toFloat(f16);
                const a = addend.toFloat(f16);
                return Value.Tag.float_16.create(arena, @mulAdd(f16, m1, m2, a));
            },
            32 => {
                const m1 = mulend1.toFloat(f32);
                const m2 = mulend2.toFloat(f32);
                const a = addend.toFloat(f32);
                return Value.Tag.float_32.create(arena, @mulAdd(f32, m1, m2, a));
            },
            64 => {
                const m1 = mulend1.toFloat(f64);
                const m2 = mulend2.toFloat(f64);
                const a = addend.toFloat(f64);
                return Value.Tag.float_64.create(arena, @mulAdd(f64, m1, m2, a));
            },
            80 => {
                const m1 = mulend1.toFloat(f80);
                const m2 = mulend2.toFloat(f80);
                const a = addend.toFloat(f80);
                return Value.Tag.float_80.create(arena, @mulAdd(f80, m1, m2, a));
            },
            128 => {
                const m1 = mulend1.toFloat(f128);
                const m2 = mulend2.toFloat(f128);
                const a = addend.toFloat(f128);
                return Value.Tag.float_128.create(arena, @mulAdd(f128, m1, m2, a));
            },
            else => unreachable,
        }
    }

    /// This type is not copyable since it may contain pointers to its inner data.
    pub const Payload = struct {
        tag: Tag,

        pub const U32 = struct {
            base: Payload,
            data: u32,
        };

        pub const U64 = struct {
            base: Payload,
            data: u64,
        };

        pub const I64 = struct {
            base: Payload,
            data: i64,
        };

        pub const BigInt = struct {
            base: Payload,
            data: []const std.math.big.Limb,

            pub fn asBigInt(self: BigInt) BigIntConst {
                const positive = switch (self.base.tag) {
                    .int_big_positive => true,
                    .int_big_negative => false,
                    else => unreachable,
                };
                return BigIntConst{ .limbs = self.data, .positive = positive };
            }
        };

        pub const Function = struct {
            base: Payload,
            data: *Module.Fn,
        };

        pub const ExternFn = struct {
            base: Payload,
            data: *Module.ExternFn,
        };

        pub const Decl = struct {
            base: Payload,
            data: Module.Decl.Index,
        };

        pub const Variable = struct {
            base: Payload,
            data: *Module.Var,
        };

        pub const SubValue = struct {
            base: Payload,
            data: Value,
        };

        pub const DeclRefMut = struct {
            pub const base_tag = Tag.decl_ref_mut;

            base: Payload = Payload{ .tag = base_tag },
            data: Data,

            pub const Data = struct {
                decl_index: Module.Decl.Index,
                runtime_index: RuntimeIndex,
            };
        };

        pub const PayloadPtr = struct {
            base: Payload,
            data: struct {
                container_ptr: Value,
                container_ty: Type,
            },
        };

        pub const ComptimeFieldPtr = struct {
            base: Payload,
            data: struct {
                field_val: Value,
                field_ty: Type,
            },
        };

        pub const ElemPtr = struct {
            pub const base_tag = Tag.elem_ptr;

            base: Payload = Payload{ .tag = base_tag },
            data: struct {
                array_ptr: Value,
                elem_ty: Type,
                index: usize,
            },
        };

        pub const FieldPtr = struct {
            pub const base_tag = Tag.field_ptr;

            base: Payload = Payload{ .tag = base_tag },
            data: struct {
                container_ptr: Value,
                container_ty: Type,
                field_index: usize,
            },
        };

        pub const Bytes = struct {
            base: Payload,
            /// Includes the sentinel, if any.
            data: []const u8,
        };

        pub const StrLit = struct {
            base: Payload,
            data: Module.StringLiteralContext.Key,
        };

        pub const Aggregate = struct {
            base: Payload,
            /// Field values. The types are according to the struct or array type.
            /// The length is provided here so that copying a Value does not depend on the Type.
            data: []Value,
        };

        pub const Slice = struct {
            base: Payload,
            data: struct {
                ptr: Value,
                len: Value,
            },

            pub const ptr_index = 0;
            pub const len_index = 1;
        };

        pub const Ty = struct {
            base: Payload,
            data: Type,
        };

        pub const IntType = struct {
            pub const base_tag = Tag.int_type;

            base: Payload = Payload{ .tag = base_tag },
            data: struct {
                bits: u16,
                signed: bool,
            },
        };

        pub const Float_16 = struct {
            pub const base_tag = Tag.float_16;

            base: Payload = .{ .tag = base_tag },
            data: f16,
        };

        pub const Float_32 = struct {
            pub const base_tag = Tag.float_32;

            base: Payload = .{ .tag = base_tag },
            data: f32,
        };

        pub const Float_64 = struct {
            pub const base_tag = Tag.float_64;

            base: Payload = .{ .tag = base_tag },
            data: f64,
        };

        pub const Float_80 = struct {
            pub const base_tag = Tag.float_80;

            base: Payload = .{ .tag = base_tag },
            data: f80,
        };

        pub const Float_128 = struct {
            pub const base_tag = Tag.float_128;

            base: Payload = .{ .tag = base_tag },
            data: f128,
        };

        pub const Error = struct {
            base: Payload = .{ .tag = .@"error" },
            data: struct {
                /// `name` is owned by `Module` and will be valid for the entire
                /// duration of the compilation.
                /// TODO revisit this when we have the concept of the error tag type
                name: []const u8,
            },
        };

        pub const InferredAlloc = struct {
            pub const base_tag = Tag.inferred_alloc;

            base: Payload = .{ .tag = base_tag },
            data: struct {
                /// The value stored in the inferred allocation. This will go into
                /// peer type resolution. This is stored in a separate list so that
                /// the items are contiguous in memory and thus can be passed to
                /// `Module.resolvePeerTypes`.
                prongs: std.MultiArrayList(struct {
                    /// The dummy instruction used as a peer to resolve the type.
                    /// Although this has a redundant type with placeholder, this is
                    /// needed in addition because it may be a constant value, which
                    /// affects peer type resolution.
                    stored_inst: Air.Inst.Ref,
                    /// The bitcast instruction used as a placeholder when the
                    /// new result pointer type is not yet known.
                    placeholder: Air.Inst.Index,
                }) = .{},
                /// 0 means ABI-aligned.
                alignment: u32,
            },
        };

        pub const InferredAllocComptime = struct {
            pub const base_tag = Tag.inferred_alloc_comptime;

            base: Payload = .{ .tag = base_tag },
            data: struct {
                decl_index: Module.Decl.Index,
                /// 0 means ABI-aligned.
                alignment: u32,
            },
        };

        pub const Union = struct {
            pub const base_tag = Tag.@"union";

            base: Payload = .{ .tag = base_tag },
            data: struct {
                tag: Value,
                val: Value,
            },
        };

        pub const BoundFn = struct {
            pub const base_tag = Tag.bound_fn;

            base: Payload = Payload{ .tag = base_tag },
            data: struct {
                func_inst: Air.Inst.Ref,
                arg0_inst: Air.Inst.Ref,
            },
        };
    };

    /// Big enough to fit any non-BigInt value
    pub const BigIntSpace = struct {
        /// The +1 is headroom so that operations such as incrementing once or decrementing once
        /// are possible without using an allocator.
        limbs: [(@sizeOf(u64) / @sizeOf(std.math.big.Limb)) + 1]std.math.big.Limb,
    };

    pub const zero = initTag(.zero);
    pub const one = initTag(.one);
    pub const negative_one: Value = .{ .ptr_otherwise = &negative_one_payload.base };
    pub const undef = initTag(.undef);
    pub const @"void" = initTag(.void_value);
    pub const @"null" = initTag(.null_value);
    pub const @"false" = initTag(.bool_false);
    pub const @"true" = initTag(.bool_true);

    pub fn makeBool(x: bool) Value {
        return if (x) Value.true else Value.false;
    }

    pub fn boolToInt(x: bool) Value {
        return if (x) Value.one else Value.zero;
    }

    pub const RuntimeIndex = enum(u32) {
        zero = 0,
        comptime_field_ptr = std.math.maxInt(u32),
        _,

        pub fn increment(ri: *RuntimeIndex) void {
            ri.* = @intToEnum(RuntimeIndex, @enumToInt(ri.*) + 1);
        }
    };

    /// This function is used in the debugger pretty formatters in tools/ to fetch the
    /// Tag to Payload mapping to facilitate fancy debug printing for this type.
    fn dbHelper(self: *Value, tag_to_payload_map: *map: {
        const tags = @typeInfo(Tag).Enum.fields;
        var fields: [tags.len]std.builtin.Type.StructField = undefined;
        for (&fields, tags) |*field, t| field.* = .{
            .name = t.name,
            .type = *if (t.value < Tag.no_payload_count) void else @field(Tag, t.name).Type(),
            .default_value = null,
            .is_comptime = false,
            .alignment = 0,
        };
        break :map @Type(.{ .Struct = .{
            .layout = .Extern,
            .fields = &fields,
            .decls = &.{},
            .is_tuple = false,
        } });
    }) void {
        _ = self;
        _ = tag_to_payload_map;
    }

    comptime {
        if (builtin.mode == .Debug) {
            _ = dbHelper;
        }
    }
};

var negative_one_payload: Value.Payload.I64 = .{
    .base = .{ .tag = .int_i64 },
    .data = -1,
};
