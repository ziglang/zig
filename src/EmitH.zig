const std = @import("std");
const Zcu = @import("Module.zig");
const c = @import("codegen/c.zig");
const trace = @import("tracy.zig").trace;
const InternPool = @import("InternPool.zig");
const Type = @import("type.zig").Type;
const Zir = std.zig.Zir;

const EmitH = @This();
const Error = error{ OutOfMemory, AnalysisFail };

gpa: std.mem.Allocator,
zcu: *Zcu,
decl: *Zcu.Decl,
decl_index: InternPool.DeclIndex,
emit_h: *Zcu.EmitH,
error_msg: ?*Zcu.ErrorMsg,

pub fn renderDecl(emitter: *EmitH) Error!void {
    const zcu = emitter.zcu;
    const decl = emitter.decl;
    std.debug.assert(decl.analysis == .complete and decl.has_tv);
    const type_of_val = decl.val.typeOf(zcu);

    const ip = &emitter.zcu.intern_pool;
    const file = decl.getFileScope(zcu);

    emitter.emit_h.fwd_decl.items.len = 0;
    const writer = emitter.emit_h.fwd_decl.writer(emitter.gpa);

    if (decl.zir_decl_index.unwrap()) |tracked_inst_index| {
        const zir_decl, const extra_end = file.zir.getDeclaration(tracked_inst_index.resolve(ip));
        if (zir_decl.flags.has_doc_comment) {
            try emitter.renderDocComment(writer, @enumFromInt(file.zir.extra[extra_end]), 0);
        }
    }

    if (zcu.decl_exports.get(emitter.decl_index)) |exports| {
        switch (ip.indexToKey(decl.val.toIntern())) {
            .variable => |v| {
                std.debug.assert(!v.is_const);
                emitter.emit_h.header_section = .variables;

                for (exports.items) |exp| {
                    try writer.writeAll("zig_extern ");
                    if (v.is_threadlocal) try writer.writeAll("zig_threadlocal ");
                    if (exp.opts.linkage == .weak) try writer.writeAll("zig_weak_linkage ");
                    try emitter.renderTypeAndName(writer, exp.opts.name.toSlice(ip), v.ty, .{});
                    try writer.writeAll(";\n");
                }
            },
            .func => {
                emitter.emit_h.header_section = .functions;

                for (exports.items) |exp| {
                    try writer.writeAll("zig_extern ");
                    if (type_of_val.fnCallingConvention(zcu) == .Naked) try writer.writeAll("zig_naked ");
                    try emitter.renderTypeAndName(writer, exp.opts.name.toSlice(ip), type_of_val.toIntern(), .{});
                    try writer.writeAll(";\n");
                }
            },
            else => {
                // Constant
                emitter.emit_h.header_section = .variables;

                for (exports.items) |exp| {
                    try writer.writeAll("zig_extern const ");
                    try emitter.renderTypeAndName(writer, exp.opts.name.toSlice(ip), type_of_val.toIntern(), .{});
                    try writer.writeAll(";\n");
                }
            },
        }
    } else {
        // This branch is only reachable due to a type referenced in exported decl.
        std.debug.assert(type_of_val.toIntern() == .type_type);

        emitter.emit_h.header_section = .typedefs;

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

                    const doc_comments = try emitter.gpa.alloc(std.zig.Zir.NullTerminatedString, info.field_types.len);
                    @memset(doc_comments, .empty);
                    defer emitter.gpa.free(doc_comments);

                    if (info.zir_index.unwrap()) |tracked_inst_index| get_doc_comments: {
                        if (doc_comments.len == 0) break :get_doc_comments;

                        const extended = file.zir.instructions.items(.data)[@intFromEnum(tracked_inst_index.resolve(ip))].extended;
                        const small: std.zig.Zir.Inst.StructDecl.Small = @bitCast(extended.small);

                        var extra_index: usize = extended.operand + @sizeOf(std.zig.Zir.Inst.StructDecl) / @sizeOf(u32);

                        const captures_len = if (small.has_captures_len) blk: {
                            const captures_len = file.zir.extra[extra_index];
                            extra_index += 1;
                            break :blk captures_len;
                        } else 0;

                        const fields_len = if (small.has_fields_len) blk: {
                            const fields_len = file.zir.extra[extra_index];
                            extra_index += 1;
                            break :blk fields_len;
                        } else 0;

                        std.debug.assert(info.field_types.len == fields_len);

                        const decls_len = if (small.has_decls_len) blk: {
                            const decls_len = file.zir.extra[extra_index];
                            extra_index += 1;
                            break :blk decls_len;
                        } else 0;

                        extra_index += captures_len;

                        if (small.has_backing_int) {
                            const backing_int_body_len = file.zir.extra[extra_index];
                            extra_index += 1;
                            extra_index += if (backing_int_body_len == 0)
                                1
                            else
                                backing_int_body_len;
                        }

                        extra_index += decls_len;

                        const bits_per_field = 4;
                        const fields_per_u32 = 32 / bits_per_field;
                        const bit_bags_count = std.math.divCeil(usize, fields_len, fields_per_u32) catch unreachable;

                        var bit_bag_index: usize = extra_index;
                        extra_index += bit_bags_count;
                        var cur_bit_bag: u32 = undefined;
                        var field_i: u32 = 0;
                        while (field_i < fields_len) : (field_i += 1) {
                            if (field_i % fields_per_u32 == 0) {
                                cur_bit_bag = file.zir.extra[bit_bag_index];
                                bit_bag_index += 1;
                            }
                            const has_align = @as(u1, @truncate(cur_bit_bag)) != 0;
                            cur_bit_bag >>= 1;
                            const has_default = @as(u1, @truncate(cur_bit_bag)) != 0;
                            cur_bit_bag >>= 3;

                            extra_index += @intFromBool(!small.is_tuple);
                            const doc_comment_index: Zir.NullTerminatedString = @enumFromInt(file.zir.extra[extra_index]);
                            extra_index += 1;

                            doc_comments[field_i] = doc_comment_index;

                            extra_index += 1;
                            extra_index += @intFromBool(has_align);
                            extra_index += @intFromBool(has_default);
                        }
                    }

                    for (info.field_names.get(ip), info.field_types.get(ip), doc_comments) |field_name, field_type, doc_comment| {
                        try emitter.renderDocComment(writer, doc_comment, 1);
                        try writer.print("    ", .{});
                        try emitter.renderTypeAndName(writer, field_name.toSlice(ip), field_type, .{});
                        try writer.writeAll(";\n");
                    }

                    try writer.print("}} {s};\n\n", .{name});
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

                    const doc_comments = try emitter.gpa.alloc(std.zig.Zir.NullTerminatedString, info.field_types.len);
                    @memset(doc_comments, .empty);
                    defer emitter.gpa.free(doc_comments);

                    if (doc_comments.len > 0) {
                        const extended = file.zir.instructions.items(.data)[@intFromEnum(info.zir_index.resolve(ip))].extended;
                        const small: std.zig.Zir.Inst.UnionDecl.Small = @bitCast(extended.small);

                        var extra_index: usize = extended.operand + @sizeOf(std.zig.Zir.Inst.UnionDecl) / @sizeOf(u32);

                        extra_index += @intFromBool(small.has_tag_type);

                        const captures_len = if (small.has_captures_len) blk: {
                            const captures_len = file.zir.extra[extra_index];
                            extra_index += 1;
                            break :blk captures_len;
                        } else 0;

                        const body_len = if (small.has_body_len) blk: {
                            const body_len = file.zir.extra[extra_index];
                            extra_index += 1;
                            break :blk body_len;
                        } else 0;

                        const fields_len = if (small.has_fields_len) blk: {
                            const fields_len = file.zir.extra[extra_index];
                            extra_index += 1;
                            break :blk fields_len;
                        } else 0;

                        std.debug.assert(info.field_types.len == fields_len);

                        const decls_len = if (small.has_decls_len) blk: {
                            const decls_len = file.zir.extra[extra_index];
                            extra_index += 1;
                            break :blk decls_len;
                        } else 0;

                        extra_index += captures_len;
                        extra_index += decls_len;
                        extra_index += body_len;

                        const bits_per_field = 4;
                        const fields_per_u32 = 32 / bits_per_field;
                        const bit_bags_count = std.math.divCeil(usize, fields_len, fields_per_u32) catch unreachable;
                        const body_end = extra_index;
                        extra_index += bit_bags_count;
                        var bit_bag_index: usize = body_end;
                        var cur_bit_bag: u32 = undefined;
                        var field_i: u32 = 0;
                        while (field_i < fields_len) : (field_i += 1) {
                            if (field_i % fields_per_u32 == 0) {
                                cur_bit_bag = file.zir.extra[bit_bag_index];
                                bit_bag_index += 1;
                            }
                            const has_type = @as(u1, @truncate(cur_bit_bag)) != 0;
                            cur_bit_bag >>= 1;
                            const has_align = @as(u1, @truncate(cur_bit_bag)) != 0;
                            cur_bit_bag >>= 1;
                            const has_value = @as(u1, @truncate(cur_bit_bag)) != 0;
                            cur_bit_bag >>= 2;

                            extra_index += 1;
                            const doc_comment_index: Zir.NullTerminatedString = @enumFromInt(file.zir.extra[extra_index]);
                            extra_index += 1;

                            doc_comments[field_i] = doc_comment_index;

                            extra_index += @intFromBool(has_type);
                            extra_index += @intFromBool(has_align);
                            extra_index += @intFromBool(has_value);
                        }
                    }

                    for (tag_type_info.names.get(ip), info.field_types.get(ip), doc_comments) |field_name, field_type, doc_comment| {
                        try emitter.renderDocComment(writer, doc_comment, 1);
                        try writer.print("    ", .{});
                        try emitter.renderTypeAndName(writer, field_name.toSlice(ip), field_type, .{});
                        try writer.writeAll(";\n");
                    }

                    try writer.print("}} {s};\n\n", .{name});
                }
            },
            .Enum => {
                const info = ip.loadEnumType(value_as_type.toIntern());

                const name = decl.name.toSlice(ip);
                try writer.writeAll("typedef enum {\n");

                const doc_comments = try emitter.gpa.alloc(std.zig.Zir.NullTerminatedString, info.names.len);
                @memset(doc_comments, .empty);
                defer emitter.gpa.free(doc_comments);

                if (info.zir_index.unwrap()) |tracked_inst_index| get_doc_comments: {
                    if (doc_comments.len == 0) break :get_doc_comments;

                    const extended = file.zir.instructions.items(.data)[@intFromEnum(tracked_inst_index.resolve(ip))].extended;
                    const small: std.zig.Zir.Inst.EnumDecl.Small = @bitCast(extended.small);

                    var extra_index: usize = extended.operand + @sizeOf(std.zig.Zir.Inst.EnumDecl) / @sizeOf(u32);

                    extra_index += @intFromBool(small.has_tag_type);

                    const captures_len = if (small.has_captures_len) blk: {
                        const captures_len = file.zir.extra[extra_index];
                        extra_index += 1;
                        break :blk captures_len;
                    } else 0;

                    const body_len = if (small.has_body_len) blk: {
                        const body_len = file.zir.extra[extra_index];
                        extra_index += 1;
                        break :blk body_len;
                    } else 0;

                    const fields_len = if (small.has_fields_len) blk: {
                        const fields_len = file.zir.extra[extra_index];
                        extra_index += 1;
                        break :blk fields_len;
                    } else 0;

                    const decls_len = if (small.has_decls_len) blk: {
                        const decls_len = file.zir.extra[extra_index];
                        extra_index += 1;
                        break :blk decls_len;
                    } else 0;

                    extra_index += captures_len;
                    extra_index += decls_len;
                    extra_index += body_len;

                    const bit_bags_count = std.math.divCeil(usize, fields_len, 32) catch unreachable;
                    const body_end = extra_index;
                    extra_index += bit_bags_count;
                    var bit_bag_index: usize = body_end;
                    var cur_bit_bag: u32 = undefined;
                    var field_i: u32 = 0;
                    while (field_i < fields_len) : (field_i += 1) {
                        if (field_i % 32 == 0) {
                            cur_bit_bag = file.zir.extra[bit_bag_index];
                            bit_bag_index += 1;
                        }
                        const has_tag_value = @as(u1, @truncate(cur_bit_bag)) != 0;
                        cur_bit_bag >>= 1;

                        extra_index += 1;

                        const doc_comment_index: Zir.NullTerminatedString = @enumFromInt(file.zir.extra[extra_index]);
                        extra_index += 1;

                        doc_comments[field_i] = doc_comment_index;

                        extra_index += @intFromBool(has_tag_value);
                    }
                }

                const values = info.values.get(ip);

                if (values.len > 0) {
                    for (info.names.get(ip), doc_comments, values) |tag_name, doc_comment, value| {
                        try emitter.renderDocComment(writer, doc_comment, 1);
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
                    for (info.names.get(ip), doc_comments, 0..) |tag_name, doc_comment, value| {
                        try emitter.renderDocComment(writer, doc_comment, 1);
                        try writer.print("    {s} = {d},\n", .{ tag_name.toSlice(ip), value });
                    }
                }

                try writer.print("}} {s};\n\n", .{name});
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
    try writer.print("{}", .{try emitter.renderTypePrefix(writer, ty, .parens_not_needed, qualifiers)});
    try writeName(writer, name);
    try emitter.renderTypeSuffix(writer, ty, .parens_not_needed, .{});
}

// TODO: Write a better name that is a valid C type name
fn writeName(
    writer: anytype,
    name: []const u8,
) Error!void {
    try writer.writeAll(name);
}

fn renderDocComment(
    emitter: *EmitH,
    writer: anytype,
    string: std.zig.Zir.NullTerminatedString,
    indent: usize,
) Error!void {
    if (string == .empty) return;

    const doc_comment = emitter.decl.getFileScope(emitter.zcu).zir.nullTerminatedString(string);
    var it = std.mem.splitScalar(u8, doc_comment, '\n');
    while (it.next()) |line| {
        try writer.writeByteNTimes(' ', indent * 4);
        try writer.print("//{s}\n", .{line});
    }
}

fn renderTypePrefix(
    emitter: *EmitH,
    writer: anytype,
    index: InternPool.Index,
    are_parens_needed: ParensNeeded,
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
                trailing = try emitter.renderTypePrefix(writer, info.tag_ty, .parens_not_needed, .{});
                try zcu.comp.work_queue.writeItem(.{ .emit_h_decl = info.decl });
            },
            .ptr_type => |info| {
                std.debug.assert(info.flags.size != .Slice);
                try writer.print("{}*", .{try emitter.renderTypePrefix(
                    writer,
                    info.child,
                    .parens_needed,
                    CQualifiers.init(.{
                        .@"const" = info.flags.is_const,
                        .@"volatile" = info.flags.is_volatile,
                    }),
                )});
                trailing = .no_space;
            },
            inline .array_type, .vector_type => |info| {
                const child_trailing = try emitter.renderTypePrefix(
                    writer,
                    info.child,
                    .parens_not_needed,
                    qualifiers,
                );

                switch (are_parens_needed) {
                    .parens_needed => {
                        try writer.print("{}(", .{child_trailing});
                        return .no_space;
                    },
                    .parens_not_needed => return child_trailing,
                }
            },
            .func_type => |info| {
                const child_trailing = try emitter.renderTypePrefix(
                    writer,
                    info.return_type,
                    .parens_not_needed,
                    .{},
                );

                switch (are_parens_needed) {
                    .parens_needed => {
                        try writer.print("{}(", .{child_trailing});
                        return .no_space;
                    },
                    .parens_not_needed => return child_trailing,
                }
            },
            else => return emitter.fail("TODO: implement renderTypePrefix for {s}", .{@tagName(ip.indexToKey(index))}),
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
    are_parens_needed: ParensNeeded,
    qualifiers: CQualifiers,
) Error!void {
    const zcu = emitter.zcu;
    const ip = &zcu.intern_pool;

    switch (ip.indexToKey(index)) {
        .simple_type, .int_type, .struct_type, .union_type, .enum_type => {},
        .ptr_type => |info| try emitter.renderTypeSuffix(
            writer,
            info.child,
            .parens_needed,
            .{},
        ),
        .array_type => |info| {
            switch (are_parens_needed) {
                .parens_needed => try writer.writeByte(')'),
                .parens_not_needed => {},
            }

            try writer.print("[{}]", .{info.lenIncludingSentinel()});
            try emitter.renderTypeSuffix(
                writer,
                info.child,
                .parens_not_needed,
                .{},
            );
        },
        .vector_type => |info| {
            switch (are_parens_needed) {
                .parens_needed => try writer.writeByte(')'),
                .parens_not_needed => {},
            }

            try writer.print("[{}]", .{info.len});
            try emitter.renderTypeSuffix(
                writer,
                info.child,
                .parens_not_needed,
                .{},
            );
        },
        .func_type => |info| {
            switch (are_parens_needed) {
                .parens_needed => try writer.writeByte(')'),
                .parens_not_needed => {},
            }

            try writer.writeByte('(');
            var need_comma = false;
            for (info.param_types.get(ip), 0..) |param_type, param_index| {
                if (need_comma) try writer.writeAll(", ");
                need_comma = true;
                const trailing =
                    try emitter.renderTypePrefix(
                    writer,
                    param_type,
                    .parens_not_needed,
                    qualifiers,
                );

                if (emitter.decl.val.typeOf(zcu).toIntern() == index) {
                    // Is the function type we're emitting actually from our decl?
                    // If so, we can actually emit its param names! :)
                    try writer.print("{}{s}", .{ trailing, zcu.getParamName(emitter.decl.val.toIntern(), @intCast(param_index)) });
                }

                try emitter.renderTypeSuffix(
                    writer,
                    param_type,
                    .parens_not_needed,
                    .{},
                );
            }
            if (info.is_var_args) {
                if (need_comma) try writer.writeAll(", ");
                need_comma = true;
                try writer.writeAll("...");
            }
            if (!need_comma) try writer.writeAll("void");
            try writer.writeByte(')');

            try emitter.renderTypeSuffix(
                writer,
                info.return_type,
                .parens_not_needed,
                .{},
            );
        },
        else => return emitter.fail("TODO: implement renderTypeSuffix for {s}", .{@tagName(ip.indexToKey(index))}),
    }
}

const ParensNeeded = enum { parens_needed, parens_not_needed };
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
    emitter.error_msg = Zcu.ErrorMsg.create(emitter.gpa, emitter.decl.navSrcLoc(emitter.zcu).upgrade(emitter.zcu), format, args) catch |err| return err;
    return error.AnalysisFail;
}

pub const HeaderSection = enum {
    unknown,
    typedefs,
    variables,
    functions,
};

pub fn flushEmitH(zcu: *Zcu) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const emit_h = zcu.emit_h orelse return;

    // We collect a list of buffers to write, and write them all at once with pwritev 😎
    const num_buffers = emit_h.decl_table.count() + 1;

    const sorted_emit_hs = try zcu.gpa.alloc(Zcu.EmitH, emit_h.allocated_emit_h.count());
    defer zcu.gpa.free(sorted_emit_hs);

    emit_h.allocated_emit_h.writeToSlice(sorted_emit_hs, 0);

    std.sort.pdq(Zcu.EmitH, sorted_emit_hs, void{}, struct {
        fn lessThan(context: void, lhs: Zcu.EmitH, rhs: Zcu.EmitH) bool {
            _ = context;
            return @intFromEnum(lhs.header_section) < @intFromEnum(rhs.header_section);
        }
    }.lessThan);

    var all_buffers = try std.ArrayList(std.posix.iovec_const).initCapacity(zcu.gpa, num_buffers);
    defer all_buffers.deinit();

    const zig_h = "#include \"zig.h\"\n\n";

    var file_size: u64 = zig_h.len;
    if (zig_h.len != 0) {
        all_buffers.appendAssumeCapacity(.{
            .base = zig_h,
            .len = zig_h.len,
        });
    }

    for (sorted_emit_hs) |decl_emit_h| {
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
