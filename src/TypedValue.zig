const std = @import("std");
const Type = @import("type.zig").Type;
const Value = @import("value.zig").Value;
const Module = @import("Module.zig");
const Allocator = std.mem.Allocator;
const TypedValue = @This();
const Target = std.Target;

ty: Type,
val: Value,

/// Memory management for TypedValue. The main purpose of this type
/// is to be small and have a deinit() function to free associated resources.
pub const Managed = struct {
    /// If the tag value is less than Tag.no_payload_count, then no pointer
    /// dereference is needed.
    typed_value: TypedValue,
    /// If this is `null` then there is no memory management needed.
    arena: ?*std.heap.ArenaAllocator.State = null,

    pub fn deinit(self: *Managed, allocator: Allocator) void {
        if (self.arena) |a| a.promote(allocator).deinit();
        self.* = undefined;
    }
};

/// Assumes arena allocation. Does a recursive copy.
pub fn copy(self: TypedValue, arena: Allocator) error{OutOfMemory}!TypedValue {
    return TypedValue{
        .ty = try self.ty.copy(arena),
        .val = try self.val.copy(arena),
    };
}

pub fn eql(a: TypedValue, b: TypedValue, mod: *Module) bool {
    if (!a.ty.eql(b.ty, mod)) return false;
    return a.val.eql(b.val, a.ty, mod);
}

pub fn hash(tv: TypedValue, hasher: *std.hash.Wyhash, mod: *Module) void {
    return tv.val.hash(tv.ty, hasher, mod);
}

pub fn enumToInt(tv: TypedValue, buffer: *Value.Payload.U64) Value {
    return tv.val.enumToInt(tv.ty, buffer);
}

const max_aggregate_items = 100;

const FormatContext = struct {
    tv: TypedValue,
    mod: *Module,
};

pub fn format(
    ctx: FormatContext,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = options;
    comptime std.debug.assert(fmt.len == 0);
    return ctx.tv.print(writer, 3, ctx.mod);
}

/// Prints the Value according to the Type, not according to the Value Tag.
pub fn print(
    tv: TypedValue,
    writer: anytype,
    level: u8,
    mod: *Module,
) @TypeOf(writer).Error!void {
    const target = mod.getTarget();
    var val = tv.val;
    var ty = tv.ty;
    while (true) switch (val.tag()) {
        .u1_type => return writer.writeAll("u1"),
        .u8_type => return writer.writeAll("u8"),
        .i8_type => return writer.writeAll("i8"),
        .u16_type => return writer.writeAll("u16"),
        .i16_type => return writer.writeAll("i16"),
        .u32_type => return writer.writeAll("u32"),
        .i32_type => return writer.writeAll("i32"),
        .u64_type => return writer.writeAll("u64"),
        .i64_type => return writer.writeAll("i64"),
        .u128_type => return writer.writeAll("u128"),
        .i128_type => return writer.writeAll("i128"),
        .isize_type => return writer.writeAll("isize"),
        .usize_type => return writer.writeAll("usize"),
        .c_short_type => return writer.writeAll("c_short"),
        .c_ushort_type => return writer.writeAll("c_ushort"),
        .c_int_type => return writer.writeAll("c_int"),
        .c_uint_type => return writer.writeAll("c_uint"),
        .c_long_type => return writer.writeAll("c_long"),
        .c_ulong_type => return writer.writeAll("c_ulong"),
        .c_longlong_type => return writer.writeAll("c_longlong"),
        .c_ulonglong_type => return writer.writeAll("c_ulonglong"),
        .c_longdouble_type => return writer.writeAll("c_longdouble"),
        .f16_type => return writer.writeAll("f16"),
        .f32_type => return writer.writeAll("f32"),
        .f64_type => return writer.writeAll("f64"),
        .f80_type => return writer.writeAll("f80"),
        .f128_type => return writer.writeAll("f128"),
        .anyopaque_type => return writer.writeAll("anyopaque"),
        .bool_type => return writer.writeAll("bool"),
        .void_type => return writer.writeAll("void"),
        .type_type => return writer.writeAll("type"),
        .anyerror_type => return writer.writeAll("anyerror"),
        .comptime_int_type => return writer.writeAll("comptime_int"),
        .comptime_float_type => return writer.writeAll("comptime_float"),
        .noreturn_type => return writer.writeAll("noreturn"),
        .null_type => return writer.writeAll("@Type(.Null)"),
        .undefined_type => return writer.writeAll("@Type(.Undefined)"),
        .fn_noreturn_no_args_type => return writer.writeAll("fn() noreturn"),
        .fn_void_no_args_type => return writer.writeAll("fn() void"),
        .fn_naked_noreturn_no_args_type => return writer.writeAll("fn() callconv(.Naked) noreturn"),
        .fn_ccc_void_no_args_type => return writer.writeAll("fn() callconv(.C) void"),
        .single_const_pointer_to_comptime_int_type => return writer.writeAll("*const comptime_int"),
        .anyframe_type => return writer.writeAll("anyframe"),
        .const_slice_u8_type => return writer.writeAll("[]const u8"),
        .const_slice_u8_sentinel_0_type => return writer.writeAll("[:0]const u8"),
        .anyerror_void_error_union_type => return writer.writeAll("anyerror!void"),

        .enum_literal_type => return writer.writeAll("@Type(.EnumLiteral)"),
        .manyptr_u8_type => return writer.writeAll("[*]u8"),
        .manyptr_const_u8_type => return writer.writeAll("[*]const u8"),
        .manyptr_const_u8_sentinel_0_type => return writer.writeAll("[*:0]const u8"),
        .atomic_order_type => return writer.writeAll("std.builtin.AtomicOrder"),
        .atomic_rmw_op_type => return writer.writeAll("std.builtin.AtomicRmwOp"),
        .calling_convention_type => return writer.writeAll("std.builtin.CallingConvention"),
        .address_space_type => return writer.writeAll("std.builtin.AddressSpace"),
        .float_mode_type => return writer.writeAll("std.builtin.FloatMode"),
        .reduce_op_type => return writer.writeAll("std.builtin.ReduceOp"),
        .call_options_type => return writer.writeAll("std.builtin.CallOptions"),
        .prefetch_options_type => return writer.writeAll("std.builtin.PrefetchOptions"),
        .export_options_type => return writer.writeAll("std.builtin.ExportOptions"),
        .extern_options_type => return writer.writeAll("std.builtin.ExternOptions"),
        .type_info_type => return writer.writeAll("std.builtin.Type"),

        .empty_struct_value => return writer.writeAll(".{}"),
        .aggregate => {
            if (level == 0) {
                return writer.writeAll(".{ ... }");
            }
            const vals = val.castTag(.aggregate).?.data;
            if (ty.zigTypeTag() == .Struct) {
                try writer.writeAll(".{ ");
                const struct_fields = ty.structFields();
                const max_len = std.math.min(struct_fields.count(), max_aggregate_items);

                const field_names = struct_fields.keys();
                const fields = struct_fields.values();

                var i: u32 = 0;
                while (i < max_len) : (i += 1) {
                    if (i != 0) try writer.writeAll(", ");
                    try writer.print(".{s} = ", .{field_names[i]});
                    try print(.{
                        .ty = fields[i].ty,
                        .val = vals[i],
                    }, writer, level - 1, mod);
                }
                return writer.writeAll(" }");
            } else {
                try writer.writeAll(".{ ");
                const elem_ty = ty.elemType2();
                const max_len = std.math.min(ty.arrayLen(), max_aggregate_items);

                var i: u32 = 0;
                while (i < max_len) : (i += 1) {
                    if (i != 0) try writer.writeAll(", ");
                    try print(.{
                        .ty = elem_ty,
                        .val = vals[i],
                    }, writer, level - 1, mod);
                }
                return writer.writeAll(" }");
            }
        },
        .@"union" => {
            if (level == 0) {
                return writer.writeAll(".{ ... }");
            }
            const union_val = val.castTag(.@"union").?.data;
            try writer.writeAll(".{ ");

            try print(.{
                .ty = ty.unionTagType().?,
                .val = union_val.tag,
            }, writer, level - 1, mod);
            try writer.writeAll(" = ");
            try print(.{
                .ty = ty.unionFieldType(union_val.tag, mod),
                .val = union_val.val,
            }, writer, level - 1, mod);

            return writer.writeAll(" }");
        },
        .null_value => return writer.writeAll("null"),
        .undef => return writer.writeAll("undefined"),
        .zero => return writer.writeAll("0"),
        .one => return writer.writeAll("1"),
        .void_value => return writer.writeAll("{}"),
        .unreachable_value => return writer.writeAll("unreachable"),
        .the_only_possible_value => {
            val = ty.onePossibleValue().?;
        },
        .bool_true => return writer.writeAll("true"),
        .bool_false => return writer.writeAll("false"),
        .ty => return val.castTag(.ty).?.data.print(writer, mod),
        .int_type => {
            const int_type = val.castTag(.int_type).?.data;
            return writer.print("{s}{d}", .{
                if (int_type.signed) "s" else "u",
                int_type.bits,
            });
        },
        .int_u64 => return std.fmt.formatIntValue(val.castTag(.int_u64).?.data, "", .{}, writer),
        .int_i64 => return std.fmt.formatIntValue(val.castTag(.int_i64).?.data, "", .{}, writer),
        .int_big_positive => return writer.print("{}", .{val.castTag(.int_big_positive).?.asBigInt()}),
        .int_big_negative => return writer.print("{}", .{val.castTag(.int_big_negative).?.asBigInt()}),
        .lazy_align => {
            const sub_ty = val.castTag(.lazy_align).?.data;
            const x = sub_ty.abiAlignment(target);
            return writer.print("{d}", .{x});
        },
        .function => return writer.print("(function '{s}')", .{
            mod.declPtr(val.castTag(.function).?.data.owner_decl).name,
        }),
        .extern_fn => return writer.writeAll("(extern function)"),
        .variable => return writer.writeAll("(variable)"),
        .decl_ref_mut => {
            const decl_index = val.castTag(.decl_ref_mut).?.data.decl_index;
            const decl = mod.declPtr(decl_index);
            if (level == 0) {
                return writer.print("(decl ref mut '{s}')", .{decl.name});
            }
            return print(.{
                .ty = decl.ty,
                .val = decl.val,
            }, writer, level - 1, mod);
        },
        .decl_ref => {
            const decl_index = val.castTag(.decl_ref).?.data;
            const decl = mod.declPtr(decl_index);
            if (level == 0) {
                return writer.print("(decl ref '{s}')", .{decl.name});
            }
            return print(.{
                .ty = decl.ty,
                .val = decl.val,
            }, writer, level - 1, mod);
        },
        .elem_ptr => {
            const elem_ptr = val.castTag(.elem_ptr).?.data;
            try writer.writeAll("&");
            try print(.{
                .ty = elem_ptr.elem_ty,
                .val = elem_ptr.array_ptr,
            }, writer, level - 1, mod);
            return writer.print("[{}]", .{elem_ptr.index});
        },
        .field_ptr => {
            const field_ptr = val.castTag(.field_ptr).?.data;
            try writer.writeAll("&");
            try print(.{
                .ty = field_ptr.container_ty,
                .val = field_ptr.container_ptr,
            }, writer, level - 1, mod);

            if (field_ptr.container_ty.zigTypeTag() == .Struct) {
                const field_name = field_ptr.container_ty.structFields().keys()[field_ptr.field_index];
                return writer.print(".{s}", .{field_name});
            } else if (field_ptr.container_ty.zigTypeTag() == .Union) {
                const field_name = field_ptr.container_ty.unionFields().keys()[field_ptr.field_index];
                return writer.print(".{s}", .{field_name});
            } else unreachable;
        },
        .empty_array => return writer.writeAll(".{}"),
        .enum_literal => return writer.print(".{}", .{std.zig.fmtId(val.castTag(.enum_literal).?.data)}),
        .enum_field_index => {
            return writer.print(".{s}", .{ty.enumFieldName(val.castTag(.enum_field_index).?.data)});
        },
        .bytes => return writer.print("\"{}\"", .{std.zig.fmtEscapes(val.castTag(.bytes).?.data)}),
        .repeated => {
            if (level == 0) {
                return writer.writeAll(".{ ... }");
            }
            var i: u32 = 0;
            try writer.writeAll(".{ ");
            const elem_tv = TypedValue{
                .ty = ty.elemType2(),
                .val = val.castTag(.repeated).?.data,
            };
            while (i < max_aggregate_items) : (i += 1) {
                if (i != 0) try writer.writeAll(", ");
                try print(elem_tv, writer, level - 1, mod);
            }
            return writer.writeAll(" }");
        },
        .empty_array_sentinel => {
            if (level == 0) {
                return writer.writeAll(".{ (sentinel) }");
            }
            try writer.writeAll(".{ ");
            try print(.{
                .ty = ty.elemType2(),
                .val = ty.sentinel().?,
            }, writer, level - 1, mod);
            return writer.writeAll(" }");
        },
        .slice => return writer.writeAll("(slice)"),
        .float_16 => return writer.print("{}", .{val.castTag(.float_16).?.data}),
        .float_32 => return writer.print("{}", .{val.castTag(.float_32).?.data}),
        .float_64 => return writer.print("{}", .{val.castTag(.float_64).?.data}),
        .float_80 => return writer.print("{}", .{val.castTag(.float_80).?.data}),
        .float_128 => return writer.print("{}", .{val.castTag(.float_128).?.data}),
        .@"error" => return writer.print("error.{s}", .{val.castTag(.@"error").?.data.name}),
        .eu_payload => {
            val = val.castTag(.eu_payload).?.data;
        },
        .opt_payload => {
            val = val.castTag(.opt_payload).?.data;
        },
        .eu_payload_ptr => {
            try writer.writeAll("&");
            val = val.castTag(.eu_payload_ptr).?.data.container_ptr;
        },
        .opt_payload_ptr => {
            try writer.writeAll("&");
            val = val.castTag(.opt_payload_ptr).?.data.container_ptr;
        },

        // TODO these should not appear in this function
        .inferred_alloc => return writer.writeAll("(inferred allocation value)"),
        .inferred_alloc_comptime => return writer.writeAll("(inferred comptime allocation value)"),
        .bound_fn => {
            const bound_func = val.castTag(.bound_fn).?.data;
            return writer.print("(bound_fn %{}(%{})", .{ bound_func.func_inst, bound_func.arg0_inst });
        },
        .generic_poison_type => return writer.writeAll("(generic poison type)"),
        .generic_poison => return writer.writeAll("(generic poison)"),
    };
}
