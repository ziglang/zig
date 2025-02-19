//! This type exists only for legacy purposes, and will be removed in the future.
//! It is a thin wrapper around a `Value` which also, redundantly, stores its `Type`.

const std = @import("std");
const Type = @import("Type.zig");
const Value = @import("Value.zig");
const Zcu = @import("Zcu.zig");
const Sema = @import("Sema.zig");
const InternPool = @import("InternPool.zig");
const Allocator = std.mem.Allocator;
const Target = std.Target;

const max_aggregate_items = 100;
const max_string_len = 256;

pub const FormatContext = struct {
    val: Value,
    pt: Zcu.PerThread,
    opt_sema: ?*Sema,
    depth: u8,
};

pub fn formatSema(
    ctx: FormatContext,
    comptime fmt: []const u8,
    options: std.fmt.Options,
    writer: *std.io.BufferedWriter,
) anyerror!void {
    _ = options;
    const sema = ctx.opt_sema.?;
    comptime std.debug.assert(fmt.len == 0);
    return print(ctx.val, writer, ctx.depth, ctx.pt, sema) catch |err| switch (err) {
        error.OutOfMemory => @panic("OOM"), // We're not allowed to return this from a format function
        error.ComptimeBreak, error.ComptimeReturn => unreachable,
        error.AnalysisFail => unreachable, // TODO: re-evaluate when we use `sema` more fully
        else => |e| return e,
    };
}

pub fn format(
    ctx: FormatContext,
    comptime fmt: []const u8,
    options: std.fmt.Options,
    writer: *std.io.BufferedWriter,
) anyerror!void {
    _ = options;
    std.debug.assert(ctx.opt_sema == null);
    comptime std.debug.assert(fmt.len == 0);
    return print(ctx.val, writer, ctx.depth, ctx.pt, null) catch |err| switch (err) {
        error.OutOfMemory => @panic("OOM"), // We're not allowed to return this from a format function
        error.ComptimeBreak, error.ComptimeReturn, error.AnalysisFail => unreachable,
        else => |e| return e,
    };
}

pub fn print(
    val: Value,
    writer: *std.io.BufferedWriter,
    level: u8,
    pt: Zcu.PerThread,
    opt_sema: ?*Sema,
) anyerror!void {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
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
        .tuple_type,
        .union_type,
        .opaque_type,
        .enum_type,
        .func_type,
        .error_set_type,
        .inferred_error_set_type,
        => try Type.print(val.toType(), writer, pt),
        .undef => try writer.writeAll("undefined"),
        .simple_value => |simple_value| switch (simple_value) {
            .void => try writer.writeAll("{}"),
            .empty_tuple => try writer.writeAll(".{}"),
            else => try writer.writeAll(@tagName(simple_value)),
        },
        .variable => try writer.writeAll("(variable)"),
        .@"extern" => |e| try writer.print("(extern '{}')", .{e.name.fmt(ip)}),
        .func => |func| try writer.print("(function '{}')", .{ip.getNav(func.owner_nav).name.fmt(ip)}),
        .int => |int| switch (int.storage) {
            inline .u64, .i64, .big_int => |x| try writer.print("{}", .{x}),
            .lazy_align => |ty| if (opt_sema != null) {
                const a = try Type.fromInterned(ty).abiAlignmentSema(pt);
                try writer.print("{}", .{a.toByteUnits() orelse 0});
            } else try writer.print("@alignOf({})", .{Type.fromInterned(ty).fmt(pt)}),
            .lazy_size => |ty| if (opt_sema != null) {
                const s = try Type.fromInterned(ty).abiSizeSema(pt);
                try writer.print("{}", .{s});
            } else try writer.print("@sizeOf({})", .{Type.fromInterned(ty).fmt(pt)}),
        },
        .err => |err| try writer.print("error.{}", .{
            err.name.fmt(ip),
        }),
        .error_union => |error_union| switch (error_union.val) {
            .err_name => |err_name| try writer.print("error.{}", .{
                err_name.fmt(ip),
            }),
            .payload => |payload| try print(Value.fromInterned(payload), writer, level, pt, opt_sema),
        },
        .enum_literal => |enum_literal| try writer.print(".{}", .{
            enum_literal.fmt(ip),
        }),
        .enum_tag => |enum_tag| {
            const enum_type = ip.loadEnumType(val.typeOf(zcu).toIntern());
            if (enum_type.tagValueIndex(ip, val.toIntern())) |tag_index| {
                return writer.print(".{i}", .{enum_type.names.get(ip)[tag_index].fmt(ip)});
            }
            if (level == 0) {
                return writer.writeAll("@enumFromInt(...)");
            }
            try writer.writeAll("@enumFromInt(");
            try print(Value.fromInterned(enum_tag.int), writer, level - 1, pt, opt_sema);
            try writer.writeAll(")");
        },
        .empty_enum_value => try writer.writeAll("(empty enum value)"),
        .float => |float| switch (float.storage) {
            inline else => |x| try writer.print("{d}", .{@as(f64, @floatCast(x))}),
        },
        .slice => |slice| {
            if (ip.isUndef(slice.ptr)) {
                if (slice.len == .zero_usize) {
                    return writer.writeAll("&.{}");
                }
                try print(.fromInterned(slice.ptr), writer, level - 1, pt, opt_sema);
            } else {
                const print_contents = switch (ip.getBackingAddrTag(slice.ptr).?) {
                    .field, .arr_elem, .eu_payload, .opt_payload => unreachable,
                    .uav, .comptime_alloc, .comptime_field => true,
                    .nav, .int => false,
                };
                if (print_contents) {
                    // TODO: eventually we want to load the slice as an array with `sema`, but that's
                    // currently not possible without e.g. triggering compile errors.
                }
                try printPtr(Value.fromInterned(slice.ptr), null, writer, level, pt, opt_sema);
            }
            try writer.writeAll("[0..");
            if (level == 0) {
                try writer.writeAll("(...)");
            } else {
                try print(Value.fromInterned(slice.len), writer, level - 1, pt, opt_sema);
            }
            try writer.writeAll("]");
        },
        .ptr => {
            const print_contents = switch (ip.getBackingAddrTag(val.toIntern()).?) {
                .field, .arr_elem, .eu_payload, .opt_payload => unreachable,
                .uav, .comptime_alloc, .comptime_field => true,
                .nav, .int => false,
            };
            if (print_contents) {
                // TODO: eventually we want to load the pointer with `sema`, but that's
                // currently not possible without e.g. triggering compile errors.
            }
            try printPtr(val, .rvalue, writer, level, pt, opt_sema);
        },
        .opt => |opt| switch (opt.val) {
            .none => try writer.writeAll("null"),
            else => |payload| try print(Value.fromInterned(payload), writer, level, pt, opt_sema),
        },
        .aggregate => |aggregate| try printAggregate(val, aggregate, false, writer, level, pt, opt_sema),
        .un => |un| {
            if (level == 0) {
                try writer.writeAll(".{ ... }");
                return;
            }
            if (un.tag == .none) {
                const backing_ty = try val.typeOf(zcu).unionBackingType(pt);
                try writer.print("@bitCast(@as({}, ", .{backing_ty.fmt(pt)});
                try print(Value.fromInterned(un.val), writer, level - 1, pt, opt_sema);
                try writer.writeAll("))");
            } else {
                try writer.writeAll(".{ ");
                try print(Value.fromInterned(un.tag), writer, level - 1, pt, opt_sema);
                try writer.writeAll(" = ");
                try print(Value.fromInterned(un.val), writer, level - 1, pt, opt_sema);
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
    writer: *std.io.BufferedWriter,
    level: u8,
    pt: Zcu.PerThread,
    opt_sema: ?*Sema,
) anyerror!void {
    if (level == 0) {
        if (is_ref) try writer.writeByte('&');
        return writer.writeAll(".{ ... }");
    }
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const ty = Type.fromInterned(aggregate.ty);
    switch (ty.zigTypeTag(zcu)) {
        .@"struct" => if (!ty.isTuple(zcu)) {
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
                try print(try val.fieldValue(pt, i), writer, level - 1, pt, opt_sema);
            }
            try writer.writeAll(" }");
            return;
        },
        .array => {
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
        .vector => if (ty.arrayLen(zcu) == 0) {
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
        try print(try val.fieldValue(pt, i), writer, level - 1, pt, opt_sema);
    }
    if (len > max_aggregate_items) {
        try writer.writeAll(", ...");
    }
    return writer.writeAll(" }");
}

fn printPtr(
    ptr_val: Value,
    /// Whether to print `derivation` as an lvalue or rvalue. If `null`, the more concise option is chosen.
    want_kind: ?PrintPtrKind,
    writer: *std.io.BufferedWriter,
    level: u8,
    pt: Zcu.PerThread,
    opt_sema: ?*Sema,
) anyerror!void {
    const ptr = switch (pt.zcu.intern_pool.indexToKey(ptr_val.toIntern())) {
        .undef => return writer.writeAll("undefined"),
        .ptr => |ptr| ptr,
        else => unreachable,
    };

    if (ptr.base_addr == .uav) {
        // If the value is an aggregate, we can potentially print it more nicely.
        switch (pt.zcu.intern_pool.indexToKey(ptr.base_addr.uav.val)) {
            .aggregate => |agg| return printAggregate(
                Value.fromInterned(ptr.base_addr.uav.val),
                agg,
                true,
                writer,
                level,
                pt,
                opt_sema,
            ),
            else => {},
        }
    }

    var arena = std.heap.ArenaAllocator.init(pt.zcu.gpa);
    defer arena.deinit();
    const derivation = if (opt_sema) |sema|
        try ptr_val.pointerDerivationAdvanced(arena.allocator(), pt, true, sema)
    else
        try ptr_val.pointerDerivationAdvanced(arena.allocator(), pt, false, null);

    _ = try printPtrDerivation(derivation, writer, pt, want_kind, .{ .print_val = .{
        .level = level,
        .opt_sema = opt_sema,
    } }, 20);
}

const PrintPtrKind = enum { lvalue, rvalue };

/// Print the pointer defined by `derivation` as an lvalue or an rvalue.
/// Returns the root derivation, which may be ignored.
pub fn printPtrDerivation(
    derivation: Value.PointerDeriveStep,
    writer: *std.io.BufferedWriter,
    pt: Zcu.PerThread,
    /// Whether to print `derivation` as an lvalue or rvalue. If `null`, the more concise option is chosen.
    /// If this is `.rvalue`, the result may look like `&foo`, so it's not necessarily valid to treat it as
    /// an atom -- e.g. `&foo.*` is distinct from `(&foo).*`.
    want_kind: ?PrintPtrKind,
    /// How to print the "root" of the derivation. `.print_val` will recursively print other values if needed,
    /// e.g. for UAV refs. `.str` will just write the root as the given string.
    root_strat: union(enum) {
        str: []const u8,
        print_val: struct {
            level: u8,
            opt_sema: ?*Sema,
        },
    },
    /// The maximum recursion depth. We can never recurse infinitely here, but the depth can be arbitrary,
    /// so at this depth we just write "..." to prevent stack overflow.
    ptr_depth: u8,
) anyerror!Value.PointerDeriveStep {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;

    if (ptr_depth == 0) {
        const root_step = root: switch (derivation) {
            inline .eu_payload_ptr,
            .opt_payload_ptr,
            .field_ptr,
            .elem_ptr,
            .offset_and_cast,
            => |step| continue :root step.parent.*,
            else => |step| break :root step,
        };
        try writer.writeAll("...");
        return root_step;
    }

    const result_kind: PrintPtrKind = switch (derivation) {
        .nav_ptr,
        .uav_ptr,
        .comptime_alloc_ptr,
        .comptime_field_ptr,
        .eu_payload_ptr,
        .opt_payload_ptr,
        .field_ptr,
        .elem_ptr,
        => .lvalue,

        .offset_and_cast,
        .int,
        => .rvalue,
    };

    const need_kind = want_kind orelse result_kind;

    if (need_kind == .rvalue and result_kind == .lvalue) {
        try writer.writeByte('&');
    }

    // null if `derivation` is the root.
    const root_or_null: ?Value.PointerDeriveStep = switch (derivation) {
        .eu_payload_ptr => |info| root: {
            try writer.writeByte('(');
            const root = try printPtrDerivation(info.parent.*, writer, pt, .lvalue, root_strat, ptr_depth - 1);
            try writer.writeAll(" catch unreachable)");
            break :root root;
        },
        .opt_payload_ptr => |info| root: {
            const root = try printPtrDerivation(info.parent.*, writer, pt, .lvalue, root_strat, ptr_depth - 1);
            try writer.writeAll(".?");
            break :root root;
        },
        .field_ptr => |field| root: {
            const root = try printPtrDerivation(field.parent.*, writer, pt, null, root_strat, ptr_depth - 1);
            const agg_ty = (try field.parent.ptrType(pt)).childType(zcu);
            switch (agg_ty.zigTypeTag(zcu)) {
                .@"struct" => if (agg_ty.structFieldName(field.field_idx, zcu).unwrap()) |field_name| {
                    try writer.print(".{i}", .{field_name.fmt(ip)});
                } else {
                    try writer.print("[{d}]", .{field.field_idx});
                },
                .@"union" => {
                    const tag_ty = agg_ty.unionTagTypeHypothetical(zcu);
                    const field_name = tag_ty.enumFieldName(field.field_idx, zcu);
                    try writer.print(".{i}", .{field_name.fmt(ip)});
                },
                .pointer => switch (field.field_idx) {
                    Value.slice_ptr_index => try writer.writeAll(".ptr"),
                    Value.slice_len_index => try writer.writeAll(".len"),
                    else => unreachable,
                },
                else => unreachable,
            }
            break :root root;
        },
        .elem_ptr => |elem| root: {
            const root = try printPtrDerivation(elem.parent.*, writer, pt, null, root_strat, ptr_depth - 1);
            try writer.print("[{d}]", .{elem.elem_idx});
            break :root root;
        },

        .offset_and_cast => |oac| if (oac.byte_offset == 0) root: {
            try writer.print("@as({}, @ptrCast(", .{oac.new_ptr_ty.fmt(pt)});
            const root = try printPtrDerivation(oac.parent.*, writer, pt, .rvalue, root_strat, ptr_depth - 1);
            try writer.writeAll("))");
            break :root root;
        } else root: {
            try writer.print("@as({}, @ptrFromInt(@intFromPtr(", .{oac.new_ptr_ty.fmt(pt)});
            const root = try printPtrDerivation(oac.parent.*, writer, pt, .rvalue, root_strat, ptr_depth - 1);
            try writer.print(") + {d}))", .{oac.byte_offset});
            break :root root;
        },

        .int, .nav_ptr, .uav_ptr, .comptime_alloc_ptr, .comptime_field_ptr => null,
    };

    if (root_or_null == null) switch (root_strat) {
        .str => |x| try writer.writeAll(x),
        .print_val => |x| switch (derivation) {
            .int => |int| try writer.print("@as({}, @ptrFromInt(0x{x}))", .{ int.ptr_ty.fmt(pt), int.addr }),
            .nav_ptr => |nav| try writer.print("{}", .{ip.getNav(nav).fqn.fmt(ip)}),
            .uav_ptr => |uav| {
                const ty = Value.fromInterned(uav.val).typeOf(zcu);
                try writer.print("@as({}, ", .{ty.fmt(pt)});
                try print(Value.fromInterned(uav.val), writer, x.level - 1, pt, x.opt_sema);
                try writer.writeByte(')');
            },
            .comptime_alloc_ptr => |info| {
                try writer.print("@as({}, ", .{info.val.typeOf(zcu).fmt(pt)});
                try print(info.val, writer, x.level - 1, pt, x.opt_sema);
                try writer.writeByte(')');
            },
            .comptime_field_ptr => |val| {
                const ty = val.typeOf(zcu);
                try writer.print("@as({}, ", .{ty.fmt(pt)});
                try print(val, writer, x.level - 1, pt, x.opt_sema);
                try writer.writeByte(')');
            },
            else => unreachable,
        },
    };

    if (need_kind == .lvalue and result_kind == .rvalue) {
        try writer.writeAll(".*");
    }

    return root_or_null orelse derivation;
}
