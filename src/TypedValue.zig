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
const max_string_len = 256;

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
    var val = tv.val;
    var ty = tv.ty;
    if (val.isVariable(mod))
        return writer.writeAll("(variable)");

    while (true) switch (val.ip_index) {
        .none => switch (val.tag()) {
            .empty_struct_value, .aggregate => {
                if (level == 0) {
                    return writer.writeAll(".{ ... }");
                }
                if (ty.zigTypeTag(mod) == .Struct) {
                    try writer.writeAll(".{");
                    const max_len = std.math.min(ty.structFieldCount(), max_aggregate_items);

                    var i: u32 = 0;
                    while (i < max_len) : (i += 1) {
                        if (i != 0) try writer.writeAll(", ");
                        switch (ty.tag()) {
                            .anon_struct, .@"struct" => try writer.print(".{s} = ", .{ty.structFieldName(i)}),
                            else => {},
                        }
                        try print(.{
                            .ty = ty.structFieldType(i),
                            .val = val.fieldValue(ty, mod, i),
                        }, writer, level - 1, mod);
                    }
                    if (ty.structFieldCount() > max_aggregate_items) {
                        try writer.writeAll(", ...");
                    }
                    return writer.writeAll("}");
                } else {
                    const elem_ty = ty.elemType2(mod);
                    const len = ty.arrayLen(mod);

                    if (elem_ty.eql(Type.u8, mod)) str: {
                        const max_len = @intCast(usize, std.math.min(len, max_string_len));
                        var buf: [max_string_len]u8 = undefined;

                        var i: u32 = 0;
                        while (i < max_len) : (i += 1) {
                            const elem = val.fieldValue(ty, mod, i);
                            if (elem.isUndef()) break :str;
                            buf[i] = std.math.cast(u8, elem.toUnsignedInt(mod)) orelse break :str;
                        }

                        const truncated = if (len > max_string_len) " (truncated)" else "";
                        return writer.print("\"{}{s}\"", .{ std.zig.fmtEscapes(buf[0..max_len]), truncated });
                    }

                    try writer.writeAll(".{ ");

                    const max_len = std.math.min(len, max_aggregate_items);
                    var i: u32 = 0;
                    while (i < max_len) : (i += 1) {
                        if (i != 0) try writer.writeAll(", ");
                        try print(.{
                            .ty = elem_ty,
                            .val = val.fieldValue(ty, mod, i),
                        }, writer, level - 1, mod);
                    }
                    if (len > max_aggregate_items) {
                        try writer.writeAll(", ...");
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
                    .ty = ty.cast(Type.Payload.Union).?.data.tag_ty,
                    .val = union_val.tag,
                }, writer, level - 1, mod);
                try writer.writeAll(" = ");
                try print(.{
                    .ty = ty.unionFieldType(union_val.tag, mod),
                    .val = union_val.val,
                }, writer, level - 1, mod);

                return writer.writeAll(" }");
            },
            .zero => return writer.writeAll("0"),
            .one => return writer.writeAll("1"),
            .the_only_possible_value => return writer.writeAll("0"),
            .ty => return val.castTag(.ty).?.data.print(writer, mod),
            .int_u64 => return std.fmt.formatIntValue(val.castTag(.int_u64).?.data, "", .{}, writer),
            .int_i64 => return std.fmt.formatIntValue(val.castTag(.int_i64).?.data, "", .{}, writer),
            .int_big_positive => return writer.print("{}", .{val.castTag(.int_big_positive).?.asBigInt()}),
            .int_big_negative => return writer.print("{}", .{val.castTag(.int_big_negative).?.asBigInt()}),
            .lazy_align => {
                const sub_ty = val.castTag(.lazy_align).?.data;
                const x = sub_ty.abiAlignment(mod);
                return writer.print("{d}", .{x});
            },
            .lazy_size => {
                const sub_ty = val.castTag(.lazy_size).?.data;
                const x = sub_ty.abiSize(mod);
                return writer.print("{d}", .{x});
            },
            .function => return writer.print("(function '{s}')", .{
                mod.declPtr(val.castTag(.function).?.data.owner_decl).name,
            }),
            .extern_fn => return writer.writeAll("(extern function)"),
            .variable => unreachable,
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
            .comptime_field_ptr => {
                const payload = val.castTag(.comptime_field_ptr).?.data;
                if (level == 0) {
                    return writer.writeAll("(comptime field ptr)");
                }
                return print(.{
                    .ty = payload.field_ty,
                    .val = payload.field_val,
                }, writer, level - 1, mod);
            },
            .elem_ptr => {
                const elem_ptr = val.castTag(.elem_ptr).?.data;
                try writer.writeAll("&");
                if (level == 0) {
                    try writer.writeAll("(ptr)");
                } else {
                    try print(.{
                        .ty = elem_ptr.elem_ty,
                        .val = elem_ptr.array_ptr,
                    }, writer, level - 1, mod);
                }
                return writer.print("[{}]", .{elem_ptr.index});
            },
            .field_ptr => {
                const field_ptr = val.castTag(.field_ptr).?.data;
                try writer.writeAll("&");
                if (level == 0) {
                    try writer.writeAll("(ptr)");
                } else {
                    try print(.{
                        .ty = field_ptr.container_ty,
                        .val = field_ptr.container_ptr,
                    }, writer, level - 1, mod);
                }

                if (field_ptr.container_ty.zigTypeTag(mod) == .Struct) {
                    switch (field_ptr.container_ty.tag()) {
                        .tuple => return writer.print(".@\"{d}\"", .{field_ptr.field_index}),
                        else => {
                            const field_name = field_ptr.container_ty.structFieldName(field_ptr.field_index);
                            return writer.print(".{s}", .{field_name});
                        },
                    }
                } else if (field_ptr.container_ty.zigTypeTag(mod) == .Union) {
                    const field_name = field_ptr.container_ty.unionFields().keys()[field_ptr.field_index];
                    return writer.print(".{s}", .{field_name});
                } else if (field_ptr.container_ty.isSlice(mod)) {
                    switch (field_ptr.field_index) {
                        Value.Payload.Slice.ptr_index => return writer.writeAll(".ptr"),
                        Value.Payload.Slice.len_index => return writer.writeAll(".len"),
                        else => unreachable,
                    }
                }
            },
            .empty_array => return writer.writeAll(".{}"),
            .enum_literal => return writer.print(".{}", .{std.zig.fmtId(val.castTag(.enum_literal).?.data)}),
            .enum_field_index => {
                return writer.print(".{s}", .{ty.enumFieldName(val.castTag(.enum_field_index).?.data)});
            },
            .bytes => return writer.print("\"{}\"", .{std.zig.fmtEscapes(val.castTag(.bytes).?.data)}),
            .str_lit => {
                const str_lit = val.castTag(.str_lit).?.data;
                const bytes = mod.string_literal_bytes.items[str_lit.index..][0..str_lit.len];
                return writer.print("\"{}\"", .{std.zig.fmtEscapes(bytes)});
            },
            .repeated => {
                if (level == 0) {
                    return writer.writeAll(".{ ... }");
                }
                var i: u32 = 0;
                try writer.writeAll(".{ ");
                const elem_tv = TypedValue{
                    .ty = ty.elemType2(mod),
                    .val = val.castTag(.repeated).?.data,
                };
                const len = ty.arrayLen(mod);
                const max_len = std.math.min(len, max_aggregate_items);
                while (i < max_len) : (i += 1) {
                    if (i != 0) try writer.writeAll(", ");
                    try print(elem_tv, writer, level - 1, mod);
                }
                if (len > max_aggregate_items) {
                    try writer.writeAll(", ...");
                }
                return writer.writeAll(" }");
            },
            .empty_array_sentinel => {
                if (level == 0) {
                    return writer.writeAll(".{ (sentinel) }");
                }
                try writer.writeAll(".{ ");
                try print(.{
                    .ty = ty.elemType2(mod),
                    .val = ty.sentinel(mod).?,
                }, writer, level - 1, mod);
                return writer.writeAll(" }");
            },
            .slice => {
                if (level == 0) {
                    return writer.writeAll(".{ ... }");
                }
                const payload = val.castTag(.slice).?.data;
                const elem_ty = ty.elemType2(mod);
                const len = payload.len.toUnsignedInt(mod);

                if (elem_ty.eql(Type.u8, mod)) str: {
                    const max_len = @intCast(usize, std.math.min(len, max_string_len));
                    var buf: [max_string_len]u8 = undefined;

                    var i: u32 = 0;
                    while (i < max_len) : (i += 1) {
                        var elem_buf: Value.ElemValueBuffer = undefined;
                        const elem_val = payload.ptr.elemValueBuffer(mod, i, &elem_buf);
                        if (elem_val.isUndef()) break :str;
                        buf[i] = std.math.cast(u8, elem_val.toUnsignedInt(mod)) orelse break :str;
                    }

                    // TODO would be nice if this had a bit of unicode awareness.
                    const truncated = if (len > max_string_len) " (truncated)" else "";
                    return writer.print("\"{}{s}\"", .{ std.zig.fmtEscapes(buf[0..max_len]), truncated });
                }

                try writer.writeAll(".{ ");

                const max_len = std.math.min(len, max_aggregate_items);
                var i: u32 = 0;
                while (i < max_len) : (i += 1) {
                    if (i != 0) try writer.writeAll(", ");
                    var buf: Value.ElemValueBuffer = undefined;
                    try print(.{
                        .ty = elem_ty,
                        .val = payload.ptr.elemValueBuffer(mod, i, &buf),
                    }, writer, level - 1, mod);
                }
                if (len > max_aggregate_items) {
                    try writer.writeAll(", ...");
                }
                return writer.writeAll(" }");
            },
            .float_16 => return writer.print("{d}", .{val.castTag(.float_16).?.data}),
            .float_32 => return writer.print("{d}", .{val.castTag(.float_32).?.data}),
            .float_64 => return writer.print("{d}", .{val.castTag(.float_64).?.data}),
            .float_80 => return writer.print("{d}", .{@floatCast(f64, val.castTag(.float_80).?.data)}),
            .float_128 => return writer.print("{d}", .{@floatCast(f64, val.castTag(.float_128).?.data)}),
            .@"error" => return writer.print("error.{s}", .{val.castTag(.@"error").?.data.name}),
            .eu_payload => {
                val = val.castTag(.eu_payload).?.data;
                ty = ty.errorUnionPayload();
            },
            .opt_payload => {
                val = val.castTag(.opt_payload).?.data;
                ty = ty.optionalChild(mod);
                return print(.{ .ty = ty, .val = val }, writer, level, mod);
            },
            .eu_payload_ptr => {
                try writer.writeAll("&");

                const data = val.castTag(.eu_payload_ptr).?.data;

                var ty_val: Value.Payload.Ty = .{
                    .base = .{ .tag = .ty },
                    .data = ty,
                };

                try writer.writeAll("@as(");
                try print(.{
                    .ty = Type.type,
                    .val = Value.initPayload(&ty_val.base),
                }, writer, level - 1, mod);

                try writer.writeAll(", &(payload of ");

                try print(.{
                    .ty = mod.singleMutPtrType(data.container_ty) catch @panic("OOM"),
                    .val = data.container_ptr,
                }, writer, level - 1, mod);

                try writer.writeAll("))");
                return;
            },
            .opt_payload_ptr => {
                const data = val.castTag(.opt_payload_ptr).?.data;

                var ty_val: Value.Payload.Ty = .{
                    .base = .{ .tag = .ty },
                    .data = ty,
                };

                try writer.writeAll("@as(");
                try print(.{
                    .ty = Type.type,
                    .val = Value.initPayload(&ty_val.base),
                }, writer, level - 1, mod);

                try writer.writeAll(", &(payload of ");

                try print(.{
                    .ty = mod.singleMutPtrType(data.container_ty) catch @panic("OOM"),
                    .val = data.container_ptr,
                }, writer, level - 1, mod);

                try writer.writeAll("))");
                return;
            },

            // TODO these should not appear in this function
            .inferred_alloc => return writer.writeAll("(inferred allocation value)"),
            .inferred_alloc_comptime => return writer.writeAll("(inferred comptime allocation value)"),
            .runtime_value => return writer.writeAll("[runtime value]"),
        },
        else => {
            try writer.print("(interned: {})", .{val.ip_index});
            return;
        },
    };
}
