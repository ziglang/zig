const std = @import("std");
const Zcu = @import("Module.zig");
const c = @import("codegen/c.zig");
const trace = @import("tracy.zig").trace;
const zig_h = @import("link/C.zig").zig_h;
const InternPool = @import("InternPool.zig");
const Type = @import("type.zig").Type;
const Zir = std.zig.Zir;

const EmitH = @This();
const Error = error{ OutOfMemory, AnalysisFail };

gpa: std.mem.Allocator,
zcu: *Zcu,
decl: *Zcu.Decl,
emit_h: *Zcu.EmitH,
error_msg: ?*Zcu.ErrorMsg,

pub fn renderDecl(emitter: *EmitH) Error!void {
    const zcu = emitter.zcu;
    const decl = emitter.decl;
    std.debug.assert(decl.analysis == .complete and decl.has_tv);

    const ip = &emitter.zcu.intern_pool;
    const file = decl.getFileScope(zcu);

    const writer = emitter.emit_h.fwd_decl.writer(emitter.gpa);

    if (decl.zir_decl_index.unwrap()) |zir_index| {
        const zir_decl, const extra_end = file.zir.getDeclaration(zir_index.resolve(ip));
        if (zir_decl.flags.has_doc_comment) {
            const doc_comment = file.zir.nullTerminatedString(@enumFromInt(file.zir.extra[extra_end]));
            var it = std.mem.split(u8, doc_comment, "\n");
            while (it.next()) |line| {
                try writer.print("//{s}\n", .{line});
            }
        }
    }

    if (decl.is_exported) {
        switch (ip.indexToKey(decl.val.toIntern())) {
            .variable => |v| {
                std.debug.assert(!v.is_const);

                try writer.writeAll("zig_extern ");
                if (v.is_threadlocal) try writer.writeAll("zig_threadlocal ");
                if (v.is_weak_linkage) try writer.writeAll("zig_weak_linkage ");
                try emitter.renderTypeAndName(writer, decl.name.toSlice(ip), v.ty, .{});
                try writer.writeAll(";\n");
            },
            .func => {
                // TODO: exported decl name?
                // TODO: callconv?
                try writer.writeAll("zig_extern ");
                try emitter.renderTypeAndName(writer, decl.name.toSlice(ip), decl.val.typeOf(zcu).toIntern(), .{});
                try writer.writeAll(";\n");
            },
            else => {
                // Constant
                try writer.writeAll("zig_extern const ");
                try emitter.renderTypeAndName(writer, decl.name.toSlice(ip), decl.val.typeOf(zcu).toIntern(), .{});
                try writer.writeAll(";\n");
            },
        }
    } else {
        // This branch is only reachable due to a type referenced in exported decl.
        std.debug.assert(decl.val.typeOf(zcu).toIntern() == .type_type);

        const value_as_type = decl.val.toType();

        switch (value_as_type.zigTypeTag(zcu)) {
            .Struct => {
                const should_make_opaque = switch (value_as_type.containerLayout(zcu)) {
                    .@"extern" => false,
                    .@"packed" => switch (value_as_type.bitSizeAdvanced(zcu, null) catch unreachable) {
                        0, 8, 16, 32, 64, 128 => false,
                        else => true,
                    },
                    .auto => true,
                };

                const info = zcu.typeToStruct(value_as_type).?;

                const name = decl.name.toSlice(ip);
                if (should_make_opaque) {
                    try writer.print("typedef struct {s} {s};\n", .{ name, name });
                } else {
                    try writer.writeAll("typedef struct ");
                    try writer.print("{s} {{\n", .{name});

                    for (info.field_names.get(ip), info.field_types.get(ip)) |field_name, field_type| {
                        try writer.print("    ", .{});
                        try emitter.renderTypeAndName(writer, field_name.toSlice(ip), field_type, .{});
                        try writer.writeAll(";\n");
                    }

                    try writer.print("}} {s};\n", .{name});
                }
            },
            .Union => {
                const should_make_opaque = switch (value_as_type.containerLayout(zcu)) {
                    .@"extern" => false,
                    .@"packed" => switch (value_as_type.bitSizeAdvanced(zcu, null) catch unreachable) {
                        0, 8, 16, 32, 64, 128 => false,
                        else => true,
                    },
                    .auto => true,
                };

                const info = zcu.typeToUnion(value_as_type).?;
                const tag_type_info = info.loadTagType(ip);

                const name = decl.name.toSlice(ip);
                if (should_make_opaque) {
                    try writer.print("typedef union {s} {s};\n", .{ name, name });
                } else {
                    try writer.writeAll("typedef union ");
                    try writer.print("{s} {{\n", .{name});

                    for (tag_type_info.names.get(ip), info.field_types.get(ip)) |field_name, field_type| {
                        try writer.print("    ", .{});
                        try emitter.renderTypeAndName(writer, field_name.toSlice(ip), field_type, .{});
                        try writer.writeAll(";\n");
                    }

                    try writer.print("}} {s};\n", .{name});
                }
            },
            .Enum => {
                const info = ip.loadEnumType(value_as_type.toIntern());

                const name = decl.name.toSlice(ip);
                try writer.writeAll("typedef enum {\n");

                const values = info.values.get(ip);

                if (values.len > 0) {
                    for (info.names.get(ip), values) |tag_name, value| {
                        try writer.print("    {s} = {d},\n", .{
                            tag_name.toSlice(ip),
                            switch (ip.indexToKey(value).int.storage) {
                                inline .u64, .i64 => |x| std.math.cast(u128, x) orelse unreachable,
                                .big_int => |x| x.to(u128) catch unreachable,
                                .lazy_align, .lazy_size => unreachable,
                            },
                        });
                    }
                } else {
                    // Auto-numbered
                    for (info.names.get(ip), 0..) |tag_name, value| {
                        try writer.print("    {s} = {d},\n", .{ tag_name.toSlice(ip), value });
                    }
                }

                try writer.print("}} {s};\n", .{name});
            },
            // Only queued work is for structs, unions, and enums.
            else => unreachable,
        }
    }
}

// Logic adapted from codegen/c.zig

fn renderTypeAndName(
    emitter: *EmitH,
    writer: anytype,
    name: []const u8,
    ty: InternPool.Index,
    qualifiers: CQualifiers,
) Error!void {
    try writer.print("{}", .{try emitter.renderTypePrefix(writer, ty, qualifiers)});
    try writeName(writer, name);
    try emitter.renderTypeSuffix(writer, ty, .{});
}

/// TODO: Write a good name that:
/// - is a valid C type name
/// - is FQN-esque for decls
/// - doesn't have conflicts
/// - optional: is not super duper long
fn writeName(
    writer: anytype,
    name: []const u8,
) Error!void {
    try writer.writeAll(name);
}

fn renderTypePrefix(
    emitter: *EmitH,
    writer: anytype,
    index: InternPool.Index,
    qualifiers: CQualifiers,
) Error!TrailingSpace {
    const zcu = emitter.zcu;
    const ip = &zcu.intern_pool;

    var trailing: TrailingSpace = .maybe_space;

    switch (index) {
        .f16_type => try writer.writeAll("zig_f16"),
        .f32_type => try writer.writeAll("zig_f32"),
        .f64_type => try writer.writeAll("zig_f64"),
        .f80_type => try writer.writeAll("zig_f80"),
        .f128_type => try writer.writeAll("zig_f128"),
        .usize_type => try writer.writeAll("uintptr_t"),
        .isize_type => try writer.writeAll("intptr_t"),
        .c_char_type => try writer.writeAll("char"),
        .c_short_type => try writer.writeAll("short"),
        .c_ushort_type => try writer.writeAll("ushort"),
        .c_int_type => try writer.writeAll("int"),
        .c_uint_type => try writer.writeAll("uint"),
        .c_long_type => try writer.writeAll("long"),
        .c_ulong_type => try writer.writeAll("unsigned long"),
        .c_longlong_type => try writer.writeAll("long long"),
        .c_ulonglong_type => try writer.writeAll("unsigned long long"),
        .c_longdouble_type => try writer.writeAll("long double"),
        .anyopaque_type => try writer.writeAll("void"),
        .bool_type => try writer.writeAll("_Bool"),
        .void_type => try writer.writeAll("void"),
        .u0_type => try writer.writeAll("void"), // TODO: skip this param
        .u8_type => try writer.writeAll("uint8_t"),
        .u16_type => try writer.writeAll("uint16_t"),
        .u32_type => try writer.writeAll("uint32_t"),
        .u64_type => try writer.writeAll("uint64_t"),
        .u128_type => try writer.writeAll("zig_u128"),
        else => switch (ip.indexToKey(index)) {
            .struct_type => {
                const info = zcu.typeToStruct(Type.fromInterned(index)).?;
                const decl = info.decl.unwrap().?;
                try writeName(writer, ip.declPtrConst(decl).name.toSlice(ip));
                try zcu.comp.work_queue.writeItem(.{ .emit_h_decl = decl });
            },
            .union_type => {
                const info = zcu.typeToUnion(Type.fromInterned(index)).?;
                try writeName(writer, ip.declPtrConst(info.decl).name.toSlice(ip));
                try zcu.comp.work_queue.writeItem(.{ .emit_h_decl = info.decl });
            },
            .enum_type => {
                const info = ip.loadEnumType(index);
                trailing = try emitter.renderTypePrefix(writer, info.tag_ty, .{});
                try zcu.comp.work_queue.writeItem(.{ .emit_h_decl = info.decl });
            },
            .ptr_type => |info| {
                std.debug.assert(info.flags.size != .Slice);
                try writer.print("{}*", .{try emitter.renderTypePrefix(
                    writer,
                    info.child,
                    CQualifiers.init(.{
                        .@"const" = info.flags.is_const,
                        .@"volatile" = info.flags.is_volatile,
                    }),
                )});
                trailing = .no_space;
            },
            .array_type => |info| {
                try writer.print("{}(", .{try emitter.renderTypePrefix(writer, info.child, qualifiers)});
                return .no_space;
            },
            .func_type => |info| {
                try writer.print("{}(", .{try emitter.renderTypePrefix(writer, info.return_type, .{})});
                return .no_space;
            },
            else => return emitter.fail("TODO: implement emitInlineType for {s}", .{@tagName(ip.indexToKey(index))}),
        },
    }

    var qualifier_it = qualifiers.iterator();
    while (qualifier_it.next()) |qualifier| {
        try writer.print("{}{s}", .{ trailing, @tagName(qualifier) });
        trailing = .maybe_space;
    }

    return trailing;
}

fn renderTypeSuffix(
    emitter: *EmitH,
    writer: anytype,
    index: InternPool.Index,
    qualifiers: CQualifiers,
) Error!void {
    const zcu = emitter.zcu;
    const ip = &zcu.intern_pool;

    switch (ip.indexToKey(index)) {
        .simple_type, .int_type, .struct_type, .union_type, .enum_type => {},
        .ptr_type => |info| try emitter.renderTypeSuffix(writer, info.child, .{}),
        .array_type => |info| {
            try writer.print(")[{}]", .{info.lenIncludingSentinel()});
            try emitter.renderTypeSuffix(writer, info.child, .{});
        },
        .func_type => |info| {
            try writer.writeAll(")(");

            var need_comma = false;
            for (info.param_types.get(ip), 0..) |param_type, param_index| {
                if (need_comma) try writer.writeAll(", ");
                need_comma = true;
                const trailing =
                    try emitter.renderTypePrefix(writer, param_type, qualifiers);
                try writer.print("{}a{d}", .{ trailing, param_index });
                try emitter.renderTypeSuffix(writer, param_type, .{});
            }
            if (info.is_var_args) {
                if (need_comma) try writer.writeAll(", ");
                need_comma = true;
                try writer.writeAll("...");
            }
            if (!need_comma) try writer.writeAll("void");
            try writer.writeByte(')');

            try emitter.renderTypeSuffix(writer, info.return_type, .{});
        },
        else => return emitter.fail("TODO: implement emitInlineType for {s}", .{@tagName(ip.indexToKey(index))}),
    }
}

const CQualifiers = std.enums.EnumSet(enum { @"const", @"volatile", restrict });
const TrailingSpace = enum {
    no_space,
    maybe_space,

    pub fn format(
        trailing_space: @This(),
        comptime fmt: []const u8,
        _: std.fmt.FormatOptions,
        w: anytype,
    ) @TypeOf(w).Error!void {
        if (fmt.len != 0)
            @compileError("invalid format string '" ++ fmt ++ "' for type '" ++
                @typeName(@This()) ++ "'");
        switch (trailing_space) {
            .no_space => {},
            .maybe_space => try w.writeByte(' '),
        }
    }
};

fn fail(emitter: *EmitH, comptime format: []const u8, args: anytype) Error {
    emitter.error_msg = Zcu.ErrorMsg.create(emitter.gpa, emitter.decl.srcLoc(emitter.zcu), format, args) catch |err| return err;
    return error.AnalysisFail;
}

pub fn flushEmitH(zcu: *Zcu) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const emit_h = zcu.emit_h orelse return;

    // We collect a list of buffers to write, and write them all at once with pwritev 😎
    const num_buffers = emit_h.decl_table.count() + 1;
    var all_buffers = try std.ArrayList(std.posix.iovec_const).initCapacity(zcu.gpa, num_buffers);
    defer all_buffers.deinit();

    var file_size: u64 = zig_h.len;
    if (zig_h.len != 0) {
        all_buffers.appendAssumeCapacity(.{
            .base = zig_h,
            .len = zig_h.len,
        });
    }

    for (0..emit_h.decl_table.count()) |decl_table_index| {
        const decl_emit_h = emit_h.allocated_emit_h.at(decl_table_index);
        const buf = decl_emit_h.fwd_decl.items;
        if (buf.len != 0) {
            all_buffers.appendAssumeCapacity(.{
                .base = buf.ptr,
                .len = buf.len,
            });
            file_size += buf.len;
        }
    }

    const directory = emit_h.loc.directory orelse zcu.comp.local_cache_directory;
    const file = try directory.handle.createFile(emit_h.loc.basename, .{
        // We set the end position explicitly below; by not truncating the file, we possibly
        // make it easier on the file system by doing 1 reallocation instead of two.
        .truncate = false,
    });
    defer file.close();

    try file.setEndPos(file_size);
    try file.pwritevAll(all_buffers.items, 0);
}
