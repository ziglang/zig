//! This type exists only for legacy purposes, and will be removed in the future.
//! It is a thin wrapper around a `Value` which also, redundantly, stores its `Type`.

const std = @import("std");
const Type = @import("type.zig").Type;
const Value = @import("Value.zig");
const Zcu = @import("Module.zig");
const Module = Zcu;
const Sema = @import("Sema.zig");
const InternPool = @import("InternPool.zig");
const Allocator = std.mem.Allocator;
const Target = std.Target;

const max_aggregate_items = 100;
const max_string_len = 256;

pub const FormatContext = struct {
    val: Value,
    mod: *Module,
    opt_sema: ?*Sema,
    depth: u8,
};

pub fn format(
    ctx: FormatContext,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = options;
    comptime std.debug.assert(fmt.len == 0);
    return print(ctx.val, writer, ctx.depth, ctx.mod, ctx.opt_sema) catch |err| switch (err) {
        error.OutOfMemory => @panic("OOM"), // We're not allowed to return this from a format function
        error.ComptimeBreak, error.ComptimeReturn => unreachable,
        error.AnalysisFail, error.NeededSourceLocation => unreachable, // TODO: re-evaluate when we use `opt_sema` more fully
        else => |e| return e,
    };
}

pub fn print(
    val: Value,
    writer: anytype,
    level: u8,
    mod: *Module,
    /// If this `Sema` is provided, we will recurse through pointers where possible to provide friendly output.
    opt_sema: ?*Sema,
) (@TypeOf(writer).Error || Module.CompileError)!void {
    const ip = &mod.intern_pool;
    switch (ip.indexToKey(val.toIntern())) {
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
        => try Type.print(val.toType(), writer, mod),
        .undef => try writer.writeAll("undefined"),
        .simple_value => |simple_value| switch (simple_value) {
            .void => try writer.writeAll("{}"),
            .empty_struct => try writer.writeAll(".{}"),
            .generic_poison => try writer.writeAll("(generic poison)"),
            else => try writer.writeAll(@tagName(simple_value)),
        },
        .variable => try writer.writeAll("(variable)"),
        .extern_func => |extern_func| try writer.print("(extern function '{}')", .{
            mod.declPtr(extern_func.decl).name.fmt(ip),
        }),
        .func => |func| try writer.print("(function '{}')", .{
            mod.declPtr(func.owner_decl).name.fmt(ip),
        }),
        .int => |int| switch (int.storage) {
            inline .u64, .i64, .big_int => |x| try writer.print("{}", .{x}),
            .lazy_align => |ty| if (opt_sema) |sema| {
                const a = (try Type.fromInterned(ty).abiAlignmentAdvanced(mod, .{ .sema = sema })).scalar;
                try writer.print("{}", .{a.toByteUnits() orelse 0});
            } else try writer.print("@alignOf({})", .{Type.fromInterned(ty).fmt(mod)}),
            .lazy_size => |ty| if (opt_sema) |sema| {
                const s = (try Type.fromInterned(ty).abiSizeAdvanced(mod, .{ .sema = sema })).scalar;
                try writer.print("{}", .{s});
            } else try writer.print("@sizeOf({})", .{Type.fromInterned(ty).fmt(mod)}),
        },
        .err => |err| try writer.print("error.{}", .{
            err.name.fmt(ip),
        }),
        .error_union => |error_union| switch (error_union.val) {
            .err_name => |err_name| try writer.print("error.{}", .{
                err_name.fmt(ip),
            }),
            .payload => |payload| try print(Value.fromInterned(payload), writer, level, mod, opt_sema),
        },
        .enum_literal => |enum_literal| try writer.print(".{}", .{
            enum_literal.fmt(ip),
        }),
        .enum_tag => |enum_tag| {
            const enum_type = ip.loadEnumType(val.typeOf(mod).toIntern());
            if (enum_type.tagValueIndex(ip, val.toIntern())) |tag_index| {
                return writer.print(".{i}", .{enum_type.names.get(ip)[tag_index].fmt(ip)});
            }
            if (level == 0) {
                return writer.writeAll("@enumFromInt(...)");
            }
            try writer.writeAll("@enumFromInt(");
            try print(Value.fromInterned(enum_tag.int), writer, level - 1, mod, opt_sema);
            try writer.writeAll(")");
        },
        .empty_enum_value => try writer.writeAll("(empty enum value)"),
        .float => |float| switch (float.storage) {
            inline else => |x| try writer.print("{d}", .{@as(f64, @floatCast(x))}),
        },
        .slice => |slice| {
            const print_contents = switch (ip.getBackingAddrTag(slice.ptr).?) {
                .field, .arr_elem, .eu_payload, .opt_payload => unreachable,
                .anon_decl, .comptime_alloc, .comptime_field => true,
                .decl, .int => false,
            };
            if (print_contents) {
                // TODO: eventually we want to load the slice as an array with `opt_sema`, but that's
                // currently not possible without e.g. triggering compile errors.
            }
            try printPtr(Value.fromInterned(slice.ptr), writer, level, mod, opt_sema);
            try writer.writeAll("[0..");
            if (level == 0) {
                try writer.writeAll("(...)");
            } else {
                try print(Value.fromInterned(slice.len), writer, level - 1, mod, opt_sema);
            }
            try writer.writeAll("]");
        },
        .ptr => {
            const print_contents = switch (ip.getBackingAddrTag(val.toIntern()).?) {
                .field, .arr_elem, .eu_payload, .opt_payload => unreachable,
                .anon_decl, .comptime_alloc, .comptime_field => true,
                .decl, .int => false,
            };
            if (print_contents) {
                // TODO: eventually we want to load the pointer with `opt_sema`, but that's
                // currently not possible without e.g. triggering compile errors.
            }
            try printPtr(val, writer, level, mod, opt_sema);
        },
        .opt => |opt| switch (opt.val) {
            .none => try writer.writeAll("null"),
            else => |payload| try print(Value.fromInterned(payload), writer, level, mod, opt_sema),
        },
        .aggregate => |aggregate| try printAggregate(val, aggregate, false, writer, level, mod, opt_sema),
        .un => |un| {
            if (level == 0) {
                try writer.writeAll(".{ ... }");
                return;
            }
            if (un.tag == .none) {
                const backing_ty = try val.typeOf(mod).unionBackingType(mod);
                try writer.print("@bitCast(@as({}, ", .{backing_ty.fmt(mod)});
                try print(Value.fromInterned(un.val), writer, level - 1, mod, opt_sema);
                try writer.writeAll("))");
            } else {
                try writer.writeAll(".{ ");
                try print(Value.fromInterned(un.tag), writer, level - 1, mod, opt_sema);
                try writer.writeAll(" = ");
                try print(Value.fromInterned(un.val), writer, level - 1, mod, opt_sema);
                try writer.writeAll(" }");
            }
        },
        .memoized_call => unreachable,
    }
}

fn printAggregate(
    val: Value,
    aggregate: InternPool.Key.Aggregate,
    is_ref: bool,
    writer: anytype,
    level: u8,
    zcu: *Zcu,
    opt_sema: ?*Sema,
) (@TypeOf(writer).Error || Module.CompileError)!void {
    if (level == 0) {
        if (is_ref) try writer.writeByte('&');
        return writer.writeAll(".{ ... }");
    }
    const ip = &zcu.intern_pool;
    const ty = Type.fromInterned(aggregate.ty);
    switch (ty.zigTypeTag(zcu)) {
        .Struct => if (!ty.isTuple(zcu)) {
            if (is_ref) try writer.writeByte('&');
            if (ty.structFieldCount(zcu) == 0) {
                return writer.writeAll(".{}");
            }
            try writer.writeAll(".{ ");
            const max_len = @min(ty.structFieldCount(zcu), max_aggregate_items);
            for (0..max_len) |i| {
                if (i != 0) try writer.writeAll(", ");
                const field_name = ty.structFieldName(@intCast(i), zcu).unwrap().?;
                try writer.print(".{i} = ", .{field_name.fmt(ip)});
                try print(try val.fieldValue(zcu, i), writer, level - 1, zcu, opt_sema);
            }
            try writer.writeAll(" }");
            return;
        },
        .Array => {
            switch (aggregate.storage) {
                .bytes => |bytes| string: {
                    const len = ty.arrayLenIncludingSentinel(zcu);
                    if (len == 0) break :string;
                    const slice = bytes.toSlice(if (bytes.at(len - 1, ip) == 0) len - 1 else len, ip);
                    try writer.print("\"{}\"", .{std.zig.fmtEscapes(slice)});
                    if (!is_ref) try writer.writeAll(".*");
                    return;
                },
                .elems, .repeated_elem => {},
            }
            switch (ty.arrayLen(zcu)) {
                0 => {
                    if (is_ref) try writer.writeByte('&');
                    return writer.writeAll(".{}");
                },
                1 => one_byte_str: {
                    // The repr isn't `bytes`, but we might still be able to print this as a string
                    if (ty.childType(zcu).toIntern() != .u8_type) break :one_byte_str;
                    const elem_val = Value.fromInterned(aggregate.storage.values()[0]);
                    if (elem_val.isUndef(zcu)) break :one_byte_str;
                    const byte = elem_val.toUnsignedInt(zcu);
                    try writer.print("\"{}\"", .{std.zig.fmtEscapes(&.{@intCast(byte)})});
                    if (!is_ref) try writer.writeAll(".*");
                    return;
                },
                else => {},
            }
        },
        .Vector => if (ty.arrayLen(zcu) == 0) {
            if (is_ref) try writer.writeByte('&');
            return writer.writeAll(".{}");
        },
        else => unreachable,
    }

    const len = ty.arrayLen(zcu);

    if (is_ref) try writer.writeByte('&');
    try writer.writeAll(".{ ");

    const max_len = @min(len, max_aggregate_items);
    for (0..max_len) |i| {
        if (i != 0) try writer.writeAll(", ");
        try print(try val.fieldValue(zcu, i), writer, level - 1, zcu, opt_sema);
    }
    if (len > max_aggregate_items) {
        try writer.writeAll(", ...");
    }
    return writer.writeAll(" }");
}

fn printPtr(ptr_val: Value, writer: anytype, level: u8, zcu: *Zcu, opt_sema: ?*Sema) (@TypeOf(writer).Error || Module.CompileError)!void {
    const ptr = switch (zcu.intern_pool.indexToKey(ptr_val.toIntern())) {
        .undef => return writer.writeAll("undefined"),
        .ptr => |ptr| ptr,
        else => unreachable,
    };

    if (ptr.base_addr == .anon_decl) {
        // If the value is an aggregate, we can potentially print it more nicely.
        switch (zcu.intern_pool.indexToKey(ptr.base_addr.anon_decl.val)) {
            .aggregate => |agg| return printAggregate(
                Value.fromInterned(ptr.base_addr.anon_decl.val),
                agg,
                true,
                writer,
                level,
                zcu,
                opt_sema,
            ),
            else => {},
        }
    }

    var arena = std.heap.ArenaAllocator.init(zcu.gpa);
    defer arena.deinit();
    const derivation = try ptr_val.pointerDerivationAdvanced(arena.allocator(), zcu, opt_sema);
    try printPtrDerivation(derivation, writer, level, zcu, opt_sema);
}

/// Print `derivation` as an lvalue, i.e. such that writing `&` before this gives the pointer value.
fn printPtrDerivation(derivation: Value.PointerDeriveStep, writer: anytype, level: u8, zcu: *Zcu, opt_sema: ?*Sema) (@TypeOf(writer).Error || Module.CompileError)!void {
    const ip = &zcu.intern_pool;
    switch (derivation) {
        .int => |int| try writer.print("@as({}, @ptrFromInt({x})).*", .{
            int.ptr_ty.fmt(zcu),
            int.addr,
        }),
        .decl_ptr => |decl| {
            try zcu.declPtr(decl).renderFullyQualifiedName(zcu, writer);
        },
        .anon_decl_ptr => |anon| {
            const ty = Value.fromInterned(anon.val).typeOf(zcu);
            try writer.print("@as({}, ", .{ty.fmt(zcu)});
            try print(Value.fromInterned(anon.val), writer, level - 1, zcu, opt_sema);
            try writer.writeByte(')');
        },
        .comptime_alloc_ptr => |info| {
            try writer.print("@as({}, ", .{info.val.typeOf(zcu).fmt(zcu)});
            try print(info.val, writer, level - 1, zcu, opt_sema);
            try writer.writeByte(')');
        },
        .comptime_field_ptr => |val| {
            const ty = val.typeOf(zcu);
            try writer.print("@as({}, ", .{ty.fmt(zcu)});
            try print(val, writer, level - 1, zcu, opt_sema);
            try writer.writeByte(')');
        },
        .eu_payload_ptr => |info| {
            try writer.writeByte('(');
            try printPtrDerivation(info.parent.*, writer, level, zcu, opt_sema);
            try writer.writeAll(" catch unreachable)");
        },
        .opt_payload_ptr => |info| {
            try printPtrDerivation(info.parent.*, writer, level, zcu, opt_sema);
            try writer.writeAll(".?");
        },
        .field_ptr => |field| {
            try printPtrDerivation(field.parent.*, writer, level, zcu, opt_sema);
            const agg_ty = (try field.parent.ptrType(zcu)).childType(zcu);
            switch (agg_ty.zigTypeTag(zcu)) {
                .Struct => if (agg_ty.structFieldName(field.field_idx, zcu).unwrap()) |field_name| {
                    try writer.print(".{i}", .{field_name.fmt(ip)});
                } else {
                    try writer.print("[{d}]", .{field.field_idx});
                },
                .Union => {
                    const tag_ty = agg_ty.unionTagTypeHypothetical(zcu);
                    const field_name = tag_ty.enumFieldName(field.field_idx, zcu);
                    try writer.print(".{i}", .{field_name.fmt(ip)});
                },
                .Pointer => switch (field.field_idx) {
                    Value.slice_ptr_index => try writer.writeAll(".ptr"),
                    Value.slice_len_index => try writer.writeAll(".len"),
                    else => unreachable,
                },
                else => unreachable,
            }
        },
        .elem_ptr => |elem| {
            try printPtrDerivation(elem.parent.*, writer, level, zcu, opt_sema);
            try writer.print("[{d}]", .{elem.elem_idx});
        },
        .offset_and_cast => |oac| if (oac.byte_offset == 0) {
            try writer.print("@as({}, @ptrCast(", .{oac.new_ptr_ty.fmt(zcu)});
            try printPtrDerivation(oac.parent.*, writer, level, zcu, opt_sema);
            try writer.writeAll("))");
        } else {
            try writer.print("@as({}, @ptrFromInt(@intFromPtr(", .{oac.new_ptr_ty.fmt(zcu)});
            try printPtrDerivation(oac.parent.*, writer, level, zcu, opt_sema);
            try writer.print(") + {d}))", .{oac.byte_offset});
        },
    }
}
