const std = @import("std");
const Type = @import("type.zig").Type;
const Value = @import("Value.zig");
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
    if (a.ty.toIntern() != b.ty.toIntern()) return false;
    return a.val.eql(b.val, a.ty, mod);
}

pub fn hash(tv: TypedValue, hasher: *std.hash.Wyhash, mod: *Module) void {
    return tv.val.hash(tv.ty, hasher, mod);
}

pub fn intFromEnum(tv: TypedValue, mod: *Module) Allocator.Error!Value {
    return tv.val.intFromEnum(tv.ty, mod);
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
    const ip = &mod.intern_pool;
    while (true) switch (val.ip_index) {
        .none => switch (val.tag()) {
            .aggregate => return printAggregate(ty, val, writer, level, mod),
            .@"union" => {
                if (level == 0) {
                    return writer.writeAll(".{ ... }");
                }
                const payload = val.castTag(.@"union").?.data;
                try writer.writeAll(".{ ");

                if (payload.tag) |tag| {
                    try print(.{
                        .ty = Type.fromInterned(ip.indexToKey(ty.toIntern()).union_type.enum_tag_ty),
                        .val = tag,
                    }, writer, level - 1, mod);
                    try writer.writeAll(" = ");
                    const field_ty = ty.unionFieldType(tag, mod).?;
                    try print(.{
                        .ty = field_ty,
                        .val = payload.val,
                    }, writer, level - 1, mod);
                } else {
                    try writer.writeAll("(unknown tag) = ");
                    const backing_ty = try ty.unionBackingType(mod);
                    try print(.{
                        .ty = backing_ty,
                        .val = payload.val,
                    }, writer, level - 1, mod);
                }

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
                const max_len = @min(len, max_aggregate_items);
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
                    const max_len: usize = @min(len, max_string_len);
                    var buf: [max_string_len]u8 = undefined;

                    var i: u32 = 0;
                    while (i < max_len) : (i += 1) {
                        const maybe_elem_val = payload.ptr.maybeElemValue(mod, i) catch |err| switch (err) {
                            error.OutOfMemory => @panic("OOM"), // TODO: eliminate this panic
                        };
                        const elem_val = maybe_elem_val orelse return writer.writeAll(".{ (reinterpreted data) }");
                        if (elem_val.isUndef(mod)) break :str;
                        buf[i] = std.math.cast(u8, elem_val.toUnsignedInt(mod)) orelse break :str;
                    }

                    // TODO would be nice if this had a bit of unicode awareness.
                    const truncated = if (len > max_string_len) " (truncated)" else "";
                    return writer.print("\"{}{s}\"", .{ std.zig.fmtEscapes(buf[0..max_len]), truncated });
                }

                try writer.writeAll(".{ ");

                const max_len = @min(len, max_aggregate_items);
                var i: u32 = 0;
                while (i < max_len) : (i += 1) {
                    if (i != 0) try writer.writeAll(", ");
                    const maybe_elem_val = payload.ptr.maybeElemValue(mod, i) catch |err| switch (err) {
                        error.OutOfMemory => @panic("OOM"), // TODO: eliminate this panic
                    };
                    const elem_val = maybe_elem_val orelse return writer.writeAll("(reinterpreted data) }");
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
            },
        },
        else => switch (ip.indexToKey(val.toIntern())) {
            .int_type,
            .ptr_type,
            .array_type,
            .vector_type,
            .opt_type,
            .anyframe_type,
            .error_union_type,
            .simple_type,
            .struct_type,
            .anon_struct_type,
            .union_type,
            .opaque_type,
            .enum_type,
            .func_type,
            .error_set_type,
            .inferred_error_set_type,
            => return Type.print(val.toType(), writer, mod),
            .undef => return writer.writeAll("undefined"),
            .simple_value => |simple_value| switch (simple_value) {
                .void => return writer.writeAll("{}"),
                .empty_struct => return printAggregate(ty, val, writer, level, mod),
                .generic_poison => return writer.writeAll("(generic poison)"),
                else => return writer.writeAll(@tagName(simple_value)),
            },
            .variable => return writer.writeAll("(variable)"),
            .extern_func => |extern_func| return writer.print("(extern function '{}')", .{
                mod.declPtr(extern_func.decl).name.fmt(ip),
            }),
            .func => |func| return writer.print("(function '{}')", .{
                mod.declPtr(func.owner_decl).name.fmt(ip),
            }),
            .int => |int| switch (int.storage) {
                inline .u64, .i64, .big_int => |x| return writer.print("{}", .{x}),
                .lazy_align => |lazy_ty| return writer.print("{d}", .{
                    Type.fromInterned(lazy_ty).abiAlignment(mod),
                }),
                .lazy_size => |lazy_ty| return writer.print("{d}", .{
                    Type.fromInterned(lazy_ty).abiSize(mod),
                }),
            },
            .err => |err| return writer.print("error.{}", .{
                err.name.fmt(ip),
            }),
            .error_union => |error_union| switch (error_union.val) {
                .err_name => |err_name| return writer.print("error.{}", .{
                    err_name.fmt(ip),
                }),
                .payload => |payload| {
                    val = Value.fromInterned(payload);
                    ty = ty.errorUnionPayload(mod);
                },
            },
            .enum_literal => |enum_literal| return writer.print(".{}", .{
                enum_literal.fmt(ip),
            }),
            .enum_tag => |enum_tag| {
                if (level == 0) {
                    return writer.writeAll("(enum)");
                }
                const enum_type = ip.indexToKey(ty.toIntern()).enum_type;
                if (enum_type.tagValueIndex(ip, val.toIntern())) |tag_index| {
                    try writer.print(".{i}", .{enum_type.names.get(ip)[tag_index].fmt(ip)});
                    return;
                }
                try writer.writeAll("@enumFromInt(");
                try print(.{
                    .ty = Type.fromInterned(ip.typeOf(enum_tag.int)),
                    .val = Value.fromInterned(enum_tag.int),
                }, writer, level - 1, mod);
                try writer.writeAll(")");
                return;
            },
            .empty_enum_value => return writer.writeAll("(empty enum value)"),
            .float => |float| switch (float.storage) {
                inline else => |x| return writer.print("{d}", .{@as(f64, @floatCast(x))}),
            },
            .slice => |slice| {
                const ptr_ty = switch (ip.indexToKey(slice.ptr)) {
                    .ptr => |ptr| ty: {
                        if (ptr.addr == .int) return print(.{
                            .ty = Type.fromInterned(ptr.ty),
                            .val = Value.fromInterned(slice.ptr),
                        }, writer, level - 1, mod);
                        break :ty ip.indexToKey(ptr.ty).ptr_type;
                    },
                    .undef => |ptr_ty| ip.indexToKey(ptr_ty).ptr_type,
                    else => unreachable,
                };
                if (level == 0) {
                    return writer.writeAll(".{ ... }");
                }
                const elem_ty = Type.fromInterned(ptr_ty.child);
                const len = Value.fromInterned(slice.len).toUnsignedInt(mod);
                if (elem_ty.eql(Type.u8, mod)) str: {
                    const max_len = @min(len, max_string_len);
                    var buf: [max_string_len]u8 = undefined;
                    for (buf[0..max_len], 0..) |*c, i| {
                        const maybe_elem = try val.maybeElemValue(mod, i);
                        const elem = maybe_elem orelse return writer.writeAll(".{ (reinterpreted data) }");
                        if (elem.isUndef(mod)) break :str;
                        c.* = @as(u8, @intCast(elem.toUnsignedInt(mod)));
                    }
                    const truncated = if (len > max_string_len) " (truncated)" else "";
                    return writer.print("\"{}{s}\"", .{ std.zig.fmtEscapes(buf[0..max_len]), truncated });
                }
                try writer.writeAll(".{ ");
                const max_len = @min(len, max_aggregate_items);
                for (0..max_len) |i| {
                    if (i != 0) try writer.writeAll(", ");
                    const maybe_elem = try val.maybeElemValue(mod, i);
                    const elem = maybe_elem orelse return writer.writeAll("(reinterpreted data) }");
                    try print(.{
                        .ty = elem_ty,
                        .val = elem,
                    }, writer, level - 1, mod);
                }
                if (len > max_aggregate_items) {
                    try writer.writeAll(", ...");
                }
                return writer.writeAll(" }");
            },
            .ptr => |ptr| {
                switch (ptr.addr) {
                    .decl => |decl_index| {
                        const decl = mod.declPtr(decl_index);
                        if (level == 0) return writer.print("(decl '{}')", .{decl.name.fmt(ip)});
                        return print(.{
                            .ty = decl.ty,
                            .val = decl.val,
                        }, writer, level - 1, mod);
                    },
                    .anon_decl => |anon_decl| {
                        const decl_val = anon_decl.val;
                        if (level == 0) return writer.print("(anon decl '{d}')", .{
                            @intFromEnum(decl_val),
                        });
                        return print(.{
                            .ty = Type.fromInterned(ip.typeOf(decl_val)),
                            .val = Value.fromInterned(decl_val),
                        }, writer, level - 1, mod);
                    },
                    .mut_decl => |mut_decl| {
                        const decl = mod.declPtr(mut_decl.decl);
                        if (level == 0) return writer.print("(mut decl '{}')", .{decl.name.fmt(ip)});
                        return print(.{
                            .ty = decl.ty,
                            .val = decl.val,
                        }, writer, level - 1, mod);
                    },
                    .comptime_field => |field_val_ip| {
                        return print(.{
                            .ty = Type.fromInterned(ip.typeOf(field_val_ip)),
                            .val = Value.fromInterned(field_val_ip),
                        }, writer, level - 1, mod);
                    },
                    .int => |int_ip| {
                        try writer.writeAll("@ptrFromInt(");
                        try print(.{
                            .ty = Type.usize,
                            .val = Value.fromInterned(int_ip),
                        }, writer, level - 1, mod);
                        try writer.writeByte(')');
                    },
                    .eu_payload => |eu_ip| {
                        try writer.writeAll("(payload of ");
                        try print(.{
                            .ty = Type.fromInterned(ip.typeOf(eu_ip)),
                            .val = Value.fromInterned(eu_ip),
                        }, writer, level - 1, mod);
                        try writer.writeAll(")");
                    },
                    .opt_payload => |opt_ip| {
                        try print(.{
                            .ty = Type.fromInterned(ip.typeOf(opt_ip)),
                            .val = Value.fromInterned(opt_ip),
                        }, writer, level - 1, mod);
                        try writer.writeAll(".?");
                    },
                    .elem => |elem| {
                        if (level == 0) {
                            try writer.writeAll("(...)");
                        } else {
                            try print(.{
                                .ty = Type.fromInterned(ip.typeOf(elem.base)),
                                .val = Value.fromInterned(elem.base),
                            }, writer, level - 1, mod);
                        }
                        try writer.print("[{}]", .{elem.index});
                    },
                    .field => |field| {
                        const ptr_container_ty = Type.fromInterned(ip.typeOf(field.base));
                        if (level == 0) {
                            try writer.writeAll("(...)");
                        } else {
                            try print(.{
                                .ty = ptr_container_ty,
                                .val = Value.fromInterned(field.base),
                            }, writer, level - 1, mod);
                        }

                        const container_ty = ptr_container_ty.childType(mod);
                        switch (container_ty.zigTypeTag(mod)) {
                            .Struct => {
                                if (container_ty.structFieldName(@intCast(field.index), mod).unwrap()) |field_name| {
                                    try writer.print(".{i}", .{field_name.fmt(ip)});
                                } else {
                                    try writer.print("[{d}]", .{field.index});
                                }
                            },
                            .Union => {
                                const field_name = mod.typeToUnion(container_ty).?.field_names.get(ip)[@intCast(field.index)];
                                try writer.print(".{i}", .{field_name.fmt(ip)});
                            },
                            .Pointer => {
                                std.debug.assert(container_ty.isSlice(mod));
                                try writer.writeAll(switch (field.index) {
                                    Value.slice_ptr_index => ".ptr",
                                    Value.slice_len_index => ".len",
                                    else => unreachable,
                                });
                            },
                            else => unreachable,
                        }
                    },
                }
                return;
            },
            .opt => |opt| switch (opt.val) {
                .none => return writer.writeAll("null"),
                else => |payload| {
                    val = Value.fromInterned(payload);
                    ty = ty.optionalChild(mod);
                },
            },
            .aggregate => |aggregate| switch (aggregate.storage) {
                .bytes => |bytes| {
                    // Strip the 0 sentinel off of strings before printing
                    const zero_sent = blk: {
                        const sent = ty.sentinel(mod) orelse break :blk false;
                        break :blk sent.eql(Value.zero_u8, Type.u8, mod);
                    };
                    const str = if (zero_sent) bytes[0 .. bytes.len - 1] else bytes;
                    return writer.print("\"{}\"", .{std.zig.fmtEscapes(str)});
                },
                .elems, .repeated_elem => return printAggregate(ty, val, writer, level, mod),
            },
            .un => |un| {
                try writer.writeAll(".{ ");
                if (level > 0) {
                    if (un.tag != .none) {
                        try print(.{
                            .ty = ty.unionTagTypeHypothetical(mod),
                            .val = Value.fromInterned(un.tag),
                        }, writer, level - 1, mod);
                        try writer.writeAll(" = ");
                        const field_ty = ty.unionFieldType(Value.fromInterned(un.tag), mod).?;
                        try print(.{
                            .ty = field_ty,
                            .val = Value.fromInterned(un.val),
                        }, writer, level - 1, mod);
                    } else {
                        try writer.writeAll("(unknown tag) = ");
                        const backing_ty = try ty.unionBackingType(mod);
                        try print(.{
                            .ty = backing_ty,
                            .val = Value.fromInterned(un.val),
                        }, writer, level - 1, mod);
                    }
                } else try writer.writeAll("...");
                return writer.writeAll(" }");
            },
            .memoized_call => unreachable,
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
    const ip = &mod.intern_pool;
    if (ty.zigTypeTag(mod) == .Struct) {
        try writer.writeAll(".{");
        const max_len = @min(ty.structFieldCount(mod), max_aggregate_items);

        for (0..max_len) |i| {
            if (i != 0) try writer.writeAll(", ");

            const field_name = switch (ip.indexToKey(ty.toIntern())) {
                .struct_type => |x| x.fieldName(ip, i),
                .anon_struct_type => |x| if (x.isTuple()) .none else x.names.get(ip)[i].toOptional(),
                else => unreachable,
            };

            if (field_name.unwrap()) |name| try writer.print(".{} = ", .{name.fmt(ip)});
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
            const max_len: usize = @min(len, max_string_len);
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

        const max_len = @min(len, max_aggregate_items);
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
