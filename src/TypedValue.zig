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
        .ty = self.ty,
        .val = try self.val.copy(arena),
    };
}

pub fn eql(a: TypedValue, b: TypedValue, mod: *Module) bool {
    if (a.ty.ip_index != b.ty.ip_index) return false;
    return a.val.eql(b.val, a.ty, mod);
}

pub fn hash(tv: TypedValue, hasher: *std.hash.Wyhash, mod: *Module) void {
    return tv.val.hash(tv.ty, hasher, mod);
}

pub fn enumToInt(tv: TypedValue, mod: *Module) Allocator.Error!Value {
    return tv.val.enumToInt(tv.ty, mod);
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
    return ctx.tv.print(writer, 3, ctx.mod) catch |err| switch (err) {
        error.OutOfMemory => @panic("OOM"), // We're not allowed to return this from a format function
        else => |e| return e,
    };
}

/// Prints the Value according to the Type, not according to the Value Tag.
pub fn print(
    tv: TypedValue,
    writer: anytype,
    level: u8,
    mod: *Module,
) (@TypeOf(writer).Error || Allocator.Error)!void {
    var val = tv.val;
    var ty = tv.ty;
    if (val.isVariable(mod))
        return writer.writeAll("(variable)");

    while (true) switch (val.ip_index) {
        .empty_struct => return printAggregate(ty, val, writer, level, mod),
        .none => switch (val.tag()) {
            .aggregate => return printAggregate(ty, val, writer, level, mod),
            .@"union" => {
                if (level == 0) {
                    return writer.writeAll(".{ ... }");
                }
                const union_val = val.castTag(.@"union").?.data;
                try writer.writeAll(".{ ");

                try print(.{
                    .ty = mod.unionPtr(mod.intern_pool.indexToKey(ty.ip_index).union_type.index).tag_ty,
                    .val = union_val.tag,
                }, writer, level - 1, mod);
                try writer.writeAll(" = ");
                try print(.{
                    .ty = ty.unionFieldType(union_val.tag, mod),
                    .val = union_val.val,
                }, writer, level - 1, mod);

                return writer.writeAll(" }");
            },
            .bytes => return writer.print("\"{}\"", .{std.zig.fmtEscapes(val.castTag(.bytes).?.data)}),
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
                        const elem_val = payload.ptr.elemValue(mod, i) catch |err| switch (err) {
                            error.OutOfMemory => @panic("OOM"), // TODO: eliminate this panic
                        };
                        if (elem_val.isUndef(mod)) break :str;
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
                    const elem_val = payload.ptr.elemValue(mod, i) catch |err| switch (err) {
                        error.OutOfMemory => @panic("OOM"), // TODO: eliminate this panic
                    };
                    try print(.{
                        .ty = elem_ty,
                        .val = elem_val,
                    }, writer, level - 1, mod);
                }
                if (len > max_aggregate_items) {
                    try writer.writeAll(", ...");
                }
                return writer.writeAll(" }");
            },
            .eu_payload => {
                val = val.castTag(.eu_payload).?.data;
                ty = ty.errorUnionPayload(mod);
            },
            .opt_payload => {
                val = val.castTag(.opt_payload).?.data;
                ty = ty.optionalChild(mod);
                return print(.{ .ty = ty, .val = val }, writer, level, mod);
            },
        },
        else => {
            const key = mod.intern_pool.indexToKey(val.ip_index);
            if (key.typeOf() == .type_type) {
                return Type.print(val.toType(), writer, mod);
            }
            switch (key) {
                .int => |int| switch (int.storage) {
                    inline .u64, .i64, .big_int => |x| return writer.print("{}", .{x}),
                    .lazy_align => |lazy_ty| return writer.print("{d}", .{
                        lazy_ty.toType().abiAlignment(mod),
                    }),
                    .lazy_size => |lazy_ty| return writer.print("{d}", .{
                        lazy_ty.toType().abiSize(mod),
                    }),
                },
                .enum_tag => |enum_tag| {
                    if (level == 0) {
                        return writer.writeAll("(enum)");
                    }

                    try writer.writeAll("@intToEnum(");
                    try print(.{
                        .ty = Type.type,
                        .val = enum_tag.ty.toValue(),
                    }, writer, level - 1, mod);
                    try writer.writeAll(", ");
                    try print(.{
                        .ty = mod.intern_pool.typeOf(enum_tag.int).toType(),
                        .val = enum_tag.int.toValue(),
                    }, writer, level - 1, mod);
                    try writer.writeAll(")");
                    return;
                },
                .float => |float| switch (float.storage) {
                    inline else => |x| return writer.print("{}", .{x}),
                },
                else => return writer.print("{}", .{val.ip_index}),
            }
        },
    };
}

fn printAggregate(
    ty: Type,
    val: Value,
    writer: anytype,
    level: u8,
    mod: *Module,
) (@TypeOf(writer).Error || Allocator.Error)!void {
    if (level == 0) {
        return writer.writeAll(".{ ... }");
    }
    if (ty.zigTypeTag(mod) == .Struct) {
        try writer.writeAll(".{");
        const max_len = std.math.min(ty.structFieldCount(mod), max_aggregate_items);

        var i: u32 = 0;
        while (i < max_len) : (i += 1) {
            if (i != 0) try writer.writeAll(", ");
            switch (ty.ip_index) {
                .none => {}, // TODO make this unreachable after finishing InternPool migration
                else => switch (mod.intern_pool.indexToKey(ty.ip_index)) {
                    .struct_type, .anon_struct_type => try writer.print(".{s} = ", .{ty.structFieldName(i, mod)}),
                    else => {},
                },
            }
            try print(.{
                .ty = ty.structFieldType(i, mod),
                .val = try val.fieldValue(mod, i),
            }, writer, level - 1, mod);
        }
        if (ty.structFieldCount(mod) > max_aggregate_items) {
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
                const elem = try val.fieldValue(mod, i);
                if (elem.isUndef(mod)) break :str;
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
                .val = try val.fieldValue(mod, i),
            }, writer, level - 1, mod);
        }
        if (len > max_aggregate_items) {
            try writer.writeAll(", ...");
        }
        return writer.writeAll(" }");
    }
}
