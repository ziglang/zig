const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const log = std.log.scoped(.c);

const link = @import("../link.zig");
const Module = @import("../Module.zig");
const Compilation = @import("../Compilation.zig");
const Value = @import("../value.zig").Value;
const Type = @import("../type.zig").Type;
const TypedValue = @import("../TypedValue.zig");
const C = link.File.C;
const Decl = Module.Decl;
const trace = @import("../tracy.zig").trace;
const LazySrcLoc = Module.LazySrcLoc;
const Air = @import("../Air.zig");
const Zir = @import("../Zir.zig");
const Liveness = @import("../Liveness.zig");

const Mutability = enum { Const, Mut };

pub const CValue = union(enum) {
    none: void,
    /// Index into local_names
    local: usize,
    /// Index into local_names, but take the address.
    local_ref: usize,
    /// A constant instruction, to be rendered inline.
    constant: Air.Inst.Ref,
    /// Index into the parameters
    arg: usize,
    /// By-value
    decl: *Decl,
    decl_ref: *Decl,
};

const BlockData = struct {
    block_id: usize,
    result: CValue,
};

pub const CValueMap = std.AutoHashMap(Air.Inst.Index, CValue);
pub const TypedefMap = std.ArrayHashMap(
    Type,
    struct { name: []const u8, rendered: []u8 },
    Type.HashContext32,
    true,
);

fn formatTypeAsCIdentifier(
    data: Type,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;
    var buffer = [1]u8{0} ** 128;
    // We don't care if it gets cut off, it's still more unique than a number
    var buf = std.fmt.bufPrint(&buffer, "{}", .{data}) catch &buffer;
    return formatIdent(buf, "", .{}, writer);
}

pub fn typeToCIdentifier(t: Type) std.fmt.Formatter(formatTypeAsCIdentifier) {
    return .{ .data = t };
}

fn formatIdent(
    ident: []const u8,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;
    for (ident) |c, i| {
        switch (c) {
            'a'...'z', 'A'...'Z', '_' => try writer.writeByte(c),
            '.' => try writer.writeByte('_'),
            '0'...'9' => if (i == 0) {
                try writer.print("_{x:2}", .{c});
            } else {
                try writer.writeByte(c);
            },
            else => try writer.print("_{x:2}", .{c}),
        }
    }
}

pub fn fmtIdent(ident: []const u8) std.fmt.Formatter(formatIdent) {
    return .{ .data = ident };
}

/// This data is available when outputting .c code for a Module.
/// It is not available when generating .h file.
pub const Object = struct {
    dg: DeclGen,
    air: Air,
    liveness: Liveness,
    gpa: *mem.Allocator,
    code: std.ArrayList(u8),
    value_map: CValueMap,
    blocks: std.AutoHashMapUnmanaged(Air.Inst.Index, BlockData) = .{},
    next_arg_index: usize = 0,
    next_local_index: usize = 0,
    next_block_index: usize = 0,
    indent_writer: IndentWriter(std.ArrayList(u8).Writer),

    fn resolveInst(o: *Object, inst: Air.Inst.Ref) !CValue {
        if (o.air.value(inst)) |_| {
            return CValue{ .constant = inst };
        }
        const index = Air.refToIndex(inst).?;
        return o.value_map.get(index).?; // Assertion means instruction does not dominate usage.
    }

    fn allocLocalValue(o: *Object) CValue {
        const result = o.next_local_index;
        o.next_local_index += 1;
        return .{ .local = result };
    }

    fn allocLocal(o: *Object, ty: Type, mutability: Mutability) !CValue {
        const local_value = o.allocLocalValue();
        try o.renderTypeAndName(o.writer(), ty, local_value, mutability);
        return local_value;
    }

    fn writer(o: *Object) IndentWriter(std.ArrayList(u8).Writer).Writer {
        return o.indent_writer.writer();
    }

    fn writeCValue(o: *Object, w: anytype, c_value: CValue) !void {
        switch (c_value) {
            .none => unreachable,
            .local => |i| return w.print("t{d}", .{i}),
            .local_ref => |i| return w.print("&t{d}", .{i}),
            .constant => |inst| {
                const ty = o.air.typeOf(inst);
                const val = o.air.value(inst).?;
                return o.dg.renderValue(w, ty, val);
            },
            .arg => |i| return w.print("a{d}", .{i}),
            .decl => |decl| return w.writeAll(mem.span(decl.name)),
            .decl_ref => |decl| return w.print("&{s}", .{decl.name}),
        }
    }

    fn renderTypeAndName(
        o: *Object,
        w: anytype,
        ty: Type,
        name: CValue,
        mutability: Mutability,
    ) error{ OutOfMemory, AnalysisFail }!void {
        var suffix = std.ArrayList(u8).init(o.gpa);
        defer suffix.deinit();

        var render_ty = ty;
        while (render_ty.zigTypeTag() == .Array) {
            const sentinel_bit = @boolToInt(render_ty.sentinel() != null);
            const c_len = render_ty.arrayLen() + sentinel_bit;
            try suffix.writer().print("[{d}]", .{c_len});
            render_ty = render_ty.elemType();
        }

        if (render_ty.zigTypeTag() == .Fn) {
            const ret_ty = render_ty.fnReturnType();
            if (ret_ty.zigTypeTag() == .NoReturn) {
                // noreturn attribute is not allowed here.
                try w.writeAll("void");
            } else {
                try o.dg.renderType(w, ret_ty);
            }
            try w.writeAll(" (*");
            switch (mutability) {
                .Const => try w.writeAll("const "),
                .Mut => {},
            }
            try o.writeCValue(w, name);
            try w.writeAll(")(");
            const param_len = render_ty.fnParamLen();
            const is_var_args = render_ty.fnIsVarArgs();
            if (param_len == 0 and !is_var_args)
                try w.writeAll("void")
            else {
                var index: usize = 0;
                while (index < param_len) : (index += 1) {
                    if (index > 0) {
                        try w.writeAll(", ");
                    }
                    try o.dg.renderType(w, render_ty.fnParamType(index));
                }
            }
            if (is_var_args) {
                if (param_len != 0) try w.writeAll(", ");
                try w.writeAll("...");
            }
            try w.writeByte(')');
        } else {
            try o.dg.renderType(w, render_ty);

            const const_prefix = switch (mutability) {
                .Const => "const ",
                .Mut => "",
            };
            try w.print(" {s}", .{const_prefix});
            try o.writeCValue(w, name);
        }
        try w.writeAll(suffix.items);
    }
};

/// This data is available both when outputting .c code and when outputting an .h file.
pub const DeclGen = struct {
    module: *Module,
    decl: *Decl,
    fwd_decl: std.ArrayList(u8),
    error_msg: ?*Module.ErrorMsg,
    typedefs: TypedefMap,

    fn fail(dg: *DeclGen, comptime format: []const u8, args: anytype) error{ AnalysisFail, OutOfMemory } {
        @setCold(true);
        const src: LazySrcLoc = .{ .node_offset = 0 };
        const src_loc = src.toSrcLocWithDecl(dg.decl);
        dg.error_msg = try Module.ErrorMsg.create(dg.module.gpa, src_loc, format, args);
        return error.AnalysisFail;
    }

    fn renderValue(
        dg: *DeclGen,
        writer: anytype,
        t: Type,
        val: Value,
    ) error{ OutOfMemory, AnalysisFail }!void {
        if (val.isUndef()) {
            // This should lower to 0xaa bytes in safe modes, and for unsafe modes should
            // lower to leaving variables uninitialized (that might need to be implemented
            // outside of this function).
            return writer.writeAll("{}");
            //return dg.fail("TODO: C backend: implement renderValue undef", .{});
        }
        switch (t.zigTypeTag()) {
            .Int => {
                if (t.isSignedInt())
                    return writer.print("{d}", .{val.toSignedInt()});
                return writer.print("{d}", .{val.toUnsignedInt()});
            },
            .Pointer => switch (t.ptrSize()) {
                .Slice => {
                    try writer.writeByte('(');
                    try dg.renderType(writer, t);
                    try writer.writeAll("){");
                    var buf: Type.Payload.ElemType = undefined;
                    try dg.renderValue(writer, t.slicePtrFieldType(&buf), val);
                    try writer.writeAll(", ");
                    try writer.print("{d}", .{val.sliceLen()});
                    try writer.writeAll("}");
                },
                else => switch (val.tag()) {
                    .null_value, .zero => try writer.writeAll("NULL"),
                    .one => try writer.writeAll("1"),
                    .decl_ref => {
                        const decl = val.castTag(.decl_ref).?.data;
                        decl.alive = true;

                        // Determine if we must pointer cast.
                        assert(decl.has_tv);
                        if (t.eql(decl.ty)) {
                            try writer.print("&{s}", .{decl.name});
                        } else {
                            try writer.writeAll("(");
                            try dg.renderType(writer, t);
                            try writer.print(")&{s}", .{decl.name});
                        }
                    },
                    .function => {
                        const func = val.castTag(.function).?.data;
                        try writer.print("{s}", .{func.owner_decl.name});
                    },
                    .extern_fn => {
                        const decl = val.castTag(.extern_fn).?.data;
                        try writer.print("{s}", .{decl.name});
                    },
                    else => unreachable,
                },
            },
            .Array => {
                // First try specific tag representations for more efficiency.
                switch (val.tag()) {
                    .undef, .empty_struct_value, .empty_array => try writer.writeAll("{}"),
                    .bytes => {
                        const bytes = val.castTag(.bytes).?.data;
                        // TODO: make our own C string escape instead of using std.zig.fmtEscapes
                        try writer.print("\"{}\"", .{std.zig.fmtEscapes(bytes)});
                    },
                    else => {
                        // Fall back to generic implementation.
                        var arena = std.heap.ArenaAllocator.init(dg.module.gpa);
                        defer arena.deinit();

                        try writer.writeAll("{");
                        var index: usize = 0;
                        const len = t.arrayLen();
                        const elem_ty = t.elemType();
                        while (index < len) : (index += 1) {
                            if (index != 0) try writer.writeAll(",");
                            const elem_val = try val.elemValue(&arena.allocator, index);
                            try dg.renderValue(writer, elem_ty, elem_val);
                        }
                        if (t.sentinel()) |sentinel_val| {
                            if (index != 0) try writer.writeAll(",");
                            try dg.renderValue(writer, elem_ty, sentinel_val);
                        }
                        try writer.writeAll("}");
                    },
                }
            },
            .Bool => return writer.print("{}", .{val.toBool()}),
            .Optional => {
                var opt_buf: Type.Payload.ElemType = undefined;
                const payload_type = t.optionalChild(&opt_buf);
                if (t.isPtrLikeOptional()) {
                    return dg.renderValue(writer, payload_type, val);
                }
                try writer.writeByte('(');
                try dg.renderType(writer, t);
                try writer.writeAll("){");
                if (val.castTag(.opt_payload)) |pl| {
                    const payload_val = pl.data;
                    try writer.writeAll(" .is_null = false, .payload = ");
                    try dg.renderValue(writer, payload_type, payload_val);
                    try writer.writeAll(" }");
                } else {
                    try writer.writeAll(" .is_null = true }");
                }
            },
            .ErrorSet => {
                switch (val.tag()) {
                    .@"error" => {
                        const payload = val.castTag(.@"error").?;
                        // error values will be #defined at the top of the file
                        return writer.print("zig_error_{s}", .{payload.data.name});
                    },
                    else => {
                        // In this case we are rendering an error union which has a
                        // 0 bits payload.
                        return writer.writeAll("0");
                    },
                }
            },
            .ErrorUnion => {
                const error_type = t.errorUnionSet();
                const payload_type = t.errorUnionPayload();

                if (!payload_type.hasCodeGenBits()) {
                    // We use the error type directly as the type.
                    const err_val = if (val.errorUnionIsPayload()) Value.initTag(.zero) else val;
                    return dg.renderValue(writer, error_type, err_val);
                }

                try writer.writeByte('(');
                try dg.renderType(writer, t);
                try writer.writeAll("){");
                if (val.castTag(.eu_payload)) |pl| {
                    const payload_val = pl.data;
                    try writer.writeAll(" .payload = ");
                    try dg.renderValue(writer, payload_type, payload_val);
                    try writer.writeAll(", .error = 0 }");
                } else {
                    try writer.writeAll(" .error = ");
                    try dg.renderValue(writer, error_type, val);
                    try writer.writeAll(" }");
                }
            },
            .Enum => {
                switch (val.tag()) {
                    .enum_field_index => {
                        const field_index = val.castTag(.enum_field_index).?.data;
                        switch (t.tag()) {
                            .enum_simple => return writer.print("{d}", .{field_index}),
                            .enum_full, .enum_nonexhaustive => {
                                const enum_full = t.cast(Type.Payload.EnumFull).?.data;
                                if (enum_full.values.count() != 0) {
                                    const tag_val = enum_full.values.keys()[field_index];
                                    return dg.renderValue(writer, enum_full.tag_ty, tag_val);
                                } else {
                                    return writer.print("{d}", .{field_index});
                                }
                            },
                            else => unreachable,
                        }
                    },
                    else => {
                        var int_tag_ty_buffer: Type.Payload.Bits = undefined;
                        const int_tag_ty = t.intTagType(&int_tag_ty_buffer);
                        return dg.renderValue(writer, int_tag_ty, val);
                    },
                }
            },
            .Fn => switch (val.tag()) {
                .null_value, .zero => try writer.writeAll("NULL"),
                .one => try writer.writeAll("1"),
                .decl_ref => {
                    const decl = val.castTag(.decl_ref).?.data;
                    decl.alive = true;

                    // Determine if we must pointer cast.
                    assert(decl.has_tv);
                    if (t.eql(decl.ty)) {
                        try writer.print("&{s}", .{decl.name});
                    } else {
                        try writer.writeAll("(");
                        try dg.renderType(writer, t);
                        try writer.print(")&{s}", .{decl.name});
                    }
                },
                .function => {
                    const decl = val.castTag(.function).?.data.owner_decl;
                    decl.alive = true;
                    try writer.print("{s}", .{decl.name});
                },
                .extern_fn => {
                    const decl = val.castTag(.extern_fn).?.data;
                    decl.alive = true;
                    try writer.print("{s}", .{decl.name});
                },
                else => unreachable,
            },
            else => |e| return dg.fail("TODO: C backend: implement value {s}", .{
                @tagName(e),
            }),
        }
    }

    fn renderFunctionSignature(dg: *DeclGen, w: anytype, is_global: bool) !void {
        if (!is_global) {
            try w.writeAll("static ");
        }
        if (dg.decl.val.castTag(.function)) |func_payload| {
            const func: *Module.Fn = func_payload.data;
            if (func.is_cold) {
                try w.writeAll("ZIG_COLD ");
            }
        }
        try dg.renderType(w, dg.decl.ty.fnReturnType());
        const decl_name = mem.span(dg.decl.name);
        try w.print(" {s}(", .{decl_name});
        const param_len = dg.decl.ty.fnParamLen();
        const is_var_args = dg.decl.ty.fnIsVarArgs();
        if (param_len == 0 and !is_var_args)
            try w.writeAll("void")
        else {
            var index: usize = 0;
            while (index < param_len) : (index += 1) {
                if (index > 0) {
                    try w.writeAll(", ");
                }
                try dg.renderType(w, dg.decl.ty.fnParamType(index));
                try w.print(" a{d}", .{index});
            }
        }
        if (is_var_args) {
            if (param_len != 0) try w.writeAll(", ");
            try w.writeAll("...");
        }
        try w.writeByte(')');
    }

    fn renderType(dg: *DeclGen, w: anytype, t: Type) error{ OutOfMemory, AnalysisFail }!void {
        switch (t.zigTypeTag()) {
            .NoReturn => {
                try w.writeAll("zig_noreturn void");
            },
            .Void => try w.writeAll("void"),
            .Bool => try w.writeAll("bool"),
            .Int => {
                switch (t.tag()) {
                    .u8 => try w.writeAll("uint8_t"),
                    .i8 => try w.writeAll("int8_t"),
                    .u16 => try w.writeAll("uint16_t"),
                    .i16 => try w.writeAll("int16_t"),
                    .u32 => try w.writeAll("uint32_t"),
                    .i32 => try w.writeAll("int32_t"),
                    .u64 => try w.writeAll("uint64_t"),
                    .i64 => try w.writeAll("int64_t"),
                    .usize => try w.writeAll("uintptr_t"),
                    .isize => try w.writeAll("intptr_t"),
                    .c_short => try w.writeAll("short"),
                    .c_ushort => try w.writeAll("unsigned short"),
                    .c_int => try w.writeAll("int"),
                    .c_uint => try w.writeAll("unsigned int"),
                    .c_long => try w.writeAll("long"),
                    .c_ulong => try w.writeAll("unsigned long"),
                    .c_longlong => try w.writeAll("long long"),
                    .c_ulonglong => try w.writeAll("unsigned long long"),
                    .int_signed, .int_unsigned => {
                        const info = t.intInfo(dg.module.getTarget());
                        const sign_prefix = switch (info.signedness) {
                            .signed => "",
                            .unsigned => "u",
                        };
                        inline for (.{ 8, 16, 32, 64, 128 }) |nbits| {
                            if (info.bits <= nbits) {
                                try w.print("{s}int{d}_t", .{ sign_prefix, nbits });
                                break;
                            }
                        } else {
                            return dg.fail("TODO: C backend: implement integer types larger than 128 bits", .{});
                        }
                    },
                    else => unreachable,
                }
            },

            .Float => return dg.fail("TODO: C backend: implement type Float", .{}),

            .Pointer => {
                if (t.isSlice()) {
                    if (dg.typedefs.get(t)) |some| {
                        return w.writeAll(some.name);
                    }

                    var buffer = std.ArrayList(u8).init(dg.typedefs.allocator);
                    defer buffer.deinit();
                    const bw = buffer.writer();

                    try bw.writeAll("typedef struct { ");
                    const elem_type = t.elemType();
                    try dg.renderType(bw, elem_type);
                    try bw.writeAll(" *");
                    if (t.isConstPtr()) {
                        try bw.writeAll("const ");
                    }
                    if (t.isVolatilePtr()) {
                        try bw.writeAll("volatile ");
                    }
                    try bw.writeAll("ptr; size_t len; } ");
                    const name_index = buffer.items.len;
                    try bw.print("zig_L_{s};\n", .{typeToCIdentifier(elem_type)});

                    const rendered = buffer.toOwnedSlice();
                    errdefer dg.typedefs.allocator.free(rendered);
                    const name = rendered[name_index .. rendered.len - 2];

                    try dg.typedefs.ensureUnusedCapacity(1);
                    try w.writeAll(name);
                    dg.typedefs.putAssumeCapacityNoClobber(t, .{ .name = name, .rendered = rendered });
                } else {
                    try dg.renderType(w, t.elemType());
                    try w.writeAll(" *");
                    if (t.isConstPtr()) {
                        try w.writeAll("const ");
                    }
                    if (t.isVolatilePtr()) {
                        try w.writeAll("volatile ");
                    }
                }
            },
            .Array => {
                try dg.renderType(w, t.elemType());
                try w.writeAll(" *");
            },
            .Optional => {
                var opt_buf: Type.Payload.ElemType = undefined;
                const child_type = t.optionalChild(&opt_buf);
                if (t.isPtrLikeOptional()) {
                    return dg.renderType(w, child_type);
                } else if (dg.typedefs.get(t)) |some| {
                    return w.writeAll(some.name);
                }

                var buffer = std.ArrayList(u8).init(dg.typedefs.allocator);
                defer buffer.deinit();
                const bw = buffer.writer();

                try bw.writeAll("typedef struct { ");
                try dg.renderType(bw, child_type);
                try bw.writeAll(" payload; bool is_null; } ");
                const name_index = buffer.items.len;
                try bw.print("zig_Q_{s};\n", .{typeToCIdentifier(child_type)});

                const rendered = buffer.toOwnedSlice();
                errdefer dg.typedefs.allocator.free(rendered);
                const name = rendered[name_index .. rendered.len - 2];

                try dg.typedefs.ensureUnusedCapacity(1);
                try w.writeAll(name);
                dg.typedefs.putAssumeCapacityNoClobber(t, .{ .name = name, .rendered = rendered });
            },
            .ErrorSet => {
                comptime std.debug.assert(Type.initTag(.anyerror).abiSize(std.Target.current) == 2);
                try w.writeAll("uint16_t");
            },
            .ErrorUnion => {
                if (dg.typedefs.get(t)) |some| {
                    return w.writeAll(some.name);
                }
                const child_type = t.errorUnionPayload();
                const err_set_type = t.errorUnionSet();

                if (!child_type.hasCodeGenBits()) {
                    return dg.renderType(w, err_set_type);
                }

                var buffer = std.ArrayList(u8).init(dg.typedefs.allocator);
                defer buffer.deinit();
                const bw = buffer.writer();

                try bw.writeAll("typedef struct { ");
                try dg.renderType(bw, child_type);
                try bw.writeAll(" payload; uint16_t error; } ");
                const name_index = buffer.items.len;
                if (err_set_type.castTag(.error_set_inferred)) |inf_err_set_payload| {
                    const func = inf_err_set_payload.data.func;
                    try bw.print("zig_E_{s};\n", .{func.owner_decl.name});
                } else {
                    try bw.print("zig_E_{s}_{s};\n", .{
                        typeToCIdentifier(err_set_type), typeToCIdentifier(child_type),
                    });
                }

                const rendered = buffer.toOwnedSlice();
                errdefer dg.typedefs.allocator.free(rendered);
                const name = rendered[name_index .. rendered.len - 2];

                try dg.typedefs.ensureUnusedCapacity(1);
                try w.writeAll(name);
                dg.typedefs.putAssumeCapacityNoClobber(t, .{ .name = name, .rendered = rendered });
            },
            .Struct => {
                if (dg.typedefs.get(t)) |some| {
                    return w.writeAll(some.name);
                }
                const struct_obj = t.castTag(.@"struct").?.data; // Handle 0 bit types elsewhere.
                const fqn = try struct_obj.getFullyQualifiedName(dg.typedefs.allocator);
                defer dg.typedefs.allocator.free(fqn);

                var buffer = std.ArrayList(u8).init(dg.typedefs.allocator);
                defer buffer.deinit();

                try buffer.appendSlice("typedef struct {\n");
                {
                    var it = struct_obj.fields.iterator();
                    while (it.next()) |entry| {
                        try buffer.append(' ');
                        try dg.renderType(buffer.writer(), entry.value_ptr.ty);
                        try buffer.writer().print(" {s};\n", .{fmtIdent(entry.key_ptr.*)});
                    }
                }
                try buffer.appendSlice("} ");

                const name_start = buffer.items.len;
                try buffer.writer().print("zig_S_{s};\n", .{fmtIdent(fqn)});

                const rendered = buffer.toOwnedSlice();
                errdefer dg.typedefs.allocator.free(rendered);
                const name = rendered[name_start .. rendered.len - 2];

                try dg.typedefs.ensureUnusedCapacity(1);
                try w.writeAll(name);
                dg.typedefs.putAssumeCapacityNoClobber(t, .{ .name = name, .rendered = rendered });
            },
            .Enum => {
                // For enums, we simply use the integer tag type.
                var int_tag_ty_buffer: Type.Payload.Bits = undefined;
                const int_tag_ty = t.intTagType(&int_tag_ty_buffer);

                try dg.renderType(w, int_tag_ty);
            },
            .Union => return dg.fail("TODO: C backend: implement type Union", .{}),
            .Fn => {
                try dg.renderType(w, t.fnReturnType());
                try w.writeAll(" (*)(");
                const param_len = t.fnParamLen();
                const is_var_args = t.fnIsVarArgs();
                if (param_len == 0 and !is_var_args)
                    try w.writeAll("void")
                else {
                    var index: usize = 0;
                    while (index < param_len) : (index += 1) {
                        if (index > 0) {
                            try w.writeAll(", ");
                        }
                        try dg.renderType(w, t.fnParamType(index));
                    }
                }
                if (is_var_args) {
                    if (param_len != 0) try w.writeAll(", ");
                    try w.writeAll("...");
                }
                try w.writeByte(')');
            },
            .Opaque => return dg.fail("TODO: C backend: implement type Opaque", .{}),
            .Frame => return dg.fail("TODO: C backend: implement type Frame", .{}),
            .AnyFrame => return dg.fail("TODO: C backend: implement type AnyFrame", .{}),
            .Vector => return dg.fail("TODO: C backend: implement type Vector", .{}),

            .Null,
            .Undefined,
            .EnumLiteral,
            .ComptimeFloat,
            .ComptimeInt,
            .Type,
            => unreachable, // must be const or comptime

            .BoundFn => unreachable, // this type will be deleted from the language
        }
    }

    fn declIsGlobal(dg: *DeclGen, tv: TypedValue) bool {
        switch (tv.val.tag()) {
            .extern_fn => return true,
            .function => {
                const func = tv.val.castTag(.function).?.data;
                return dg.module.decl_exports.contains(func.owner_decl);
            },
            .variable => {
                const variable = tv.val.castTag(.variable).?.data;
                return dg.module.decl_exports.contains(variable.owner_decl);
            },
            else => unreachable,
        }
    }
};

pub fn genDecl(o: *Object) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const tv: TypedValue = .{
        .ty = o.dg.decl.ty,
        .val = o.dg.decl.val,
    };
    if (tv.val.castTag(.function)) |func_payload| {
        const func: *Module.Fn = func_payload.data;
        if (func.owner_decl == o.dg.decl) {
            const is_global = o.dg.declIsGlobal(tv);
            const fwd_decl_writer = o.dg.fwd_decl.writer();
            if (is_global) {
                try fwd_decl_writer.writeAll("ZIG_EXTERN_C ");
            }
            try o.dg.renderFunctionSignature(fwd_decl_writer, is_global);
            try fwd_decl_writer.writeAll(";\n");

            try o.indent_writer.insertNewline();
            try o.dg.renderFunctionSignature(o.writer(), is_global);

            try o.writer().writeByte(' ');
            const main_body = o.air.getMainBody();
            try genBody(o, main_body);

            try o.indent_writer.insertNewline();
            return;
        }
    }
    if (tv.val.tag() == .extern_fn) {
        const writer = o.writer();
        try writer.writeAll("ZIG_EXTERN_C ");
        try o.dg.renderFunctionSignature(writer, true);
        try writer.writeAll(";\n");
    } else if (tv.val.castTag(.variable)) |var_payload| {
        const variable: *Module.Var = var_payload.data;
        const is_global = o.dg.declIsGlobal(tv);
        const fwd_decl_writer = o.dg.fwd_decl.writer();
        if (is_global or variable.is_extern) {
            try fwd_decl_writer.writeAll("ZIG_EXTERN_C ");
        }
        if (variable.is_threadlocal) {
            try fwd_decl_writer.writeAll("zig_threadlocal ");
        }
        try o.dg.renderType(fwd_decl_writer, o.dg.decl.ty);
        const decl_name = mem.span(o.dg.decl.name);
        try fwd_decl_writer.print(" {s};\n", .{decl_name});

        try o.indent_writer.insertNewline();
        const w = o.writer();
        try o.dg.renderType(w, o.dg.decl.ty);
        try w.print(" {s} = ", .{decl_name});
        if (variable.init.tag() != .unreachable_value) {
            try o.dg.renderValue(w, tv.ty, variable.init);
        }
        try w.writeAll(";");
        try o.indent_writer.insertNewline();
    } else {
        const writer = o.writer();
        try writer.writeAll("static ");

        // TODO ask the Decl if it is const
        // https://github.com/ziglang/zig/issues/7582

        const decl_c_value: CValue = .{ .decl = o.dg.decl };
        try o.renderTypeAndName(writer, tv.ty, decl_c_value, .Mut);

        try writer.writeAll(" = ");
        try o.dg.renderValue(writer, tv.ty, tv.val);
        try writer.writeAll(";\n");
    }
}

pub fn genHeader(dg: *DeclGen) error{ AnalysisFail, OutOfMemory }!void {
    const tracy = trace(@src());
    defer tracy.end();

    const tv: TypedValue = .{
        .ty = dg.decl.ty,
        .val = dg.decl.val,
    };
    const writer = dg.fwd_decl.writer();

    switch (tv.ty.zigTypeTag()) {
        .Fn => {
            const is_global = dg.declIsGlobal(tv);
            if (is_global) {
                try writer.writeAll("ZIG_EXTERN_C ");
                try dg.renderFunctionSignature(writer, is_global);
                try dg.fwd_decl.appendSlice(";\n");
            }
        },
        else => {},
    }
}

fn genBody(o: *Object, body: []const Air.Inst.Index) error{ AnalysisFail, OutOfMemory }!void {
    const writer = o.writer();
    if (body.len == 0) {
        try writer.writeAll("{}");
        return;
    }

    try writer.writeAll("{\n");
    o.indent_writer.pushIndent();

    const air_tags = o.air.instructions.items(.tag);

    for (body) |inst| {
        const result_value = switch (air_tags[inst]) {
            // zig fmt: off
            .constant => unreachable, // excluded from function bodies
            .const_ty => unreachable, // excluded from function bodies
            .arg      => airArg(o),

            .breakpoint => try airBreakpoint(o),
            .unreach    => try airUnreach(o),

            // TODO use a different strategy for add that communicates to the optimizer
            // that wrapping is UB.
            .add, .ptr_add => try airBinOp( o, inst, " + "),
            .addwrap       => try airWrapOp(o, inst, " + ", "addw_"),
            // TODO use a different strategy for sub that communicates to the optimizer
            // that wrapping is UB.
            .sub, .ptr_sub => try airBinOp( o, inst, " - "),
            .subwrap       => try airWrapOp(o, inst, " - ", "subw_"),
            // TODO use a different strategy for mul that communicates to the optimizer
            // that wrapping is UB.
            .mul           => try airBinOp( o, inst, " * "),
            .mulwrap       => try airWrapOp(o, inst, " * ", "mulw_"),
            // TODO use a different strategy for div that communicates to the optimizer
            // that wrapping is UB.
            .div           => try airBinOp( o, inst, " / "),
            .rem           => try airBinOp( o, inst, " % "),

            .cmp_eq  => try airBinOp(o, inst, " == "),
            .cmp_gt  => try airBinOp(o, inst, " > "),
            .cmp_gte => try airBinOp(o, inst, " >= "),
            .cmp_lt  => try airBinOp(o, inst, " < "),
            .cmp_lte => try airBinOp(o, inst, " <= "),
            .cmp_neq => try airBinOp(o, inst, " != "),

            // bool_and and bool_or are non-short-circuit operations
            .bool_and   => try airBinOp(o, inst, " & "),
            .bool_or    => try airBinOp(o, inst, " | "),
            .bit_and    => try airBinOp(o, inst, " & "),
            .bit_or     => try airBinOp(o, inst, " | "),
            .xor        => try airBinOp(o, inst, " ^ "),

            .shr        => try airBinOp(o, inst, " >> "),
            .shl        => try airBinOp(o, inst, " << "),

            .not        => try airNot(  o, inst),

            .optional_payload     => try airOptionalPayload(o, inst),
            .optional_payload_ptr => try airOptionalPayload(o, inst),

            .is_err          => try airIsErr(o, inst, "", ".", "!="),
            .is_non_err      => try airIsErr(o, inst, "", ".", "=="),
            .is_err_ptr      => try airIsErr(o, inst, "*", "->", "!="),
            .is_non_err_ptr  => try airIsErr(o, inst, "*", "->", "=="),

            .is_null         => try airIsNull(o, inst, "==", ""),
            .is_non_null     => try airIsNull(o, inst, "!=", ""),
            .is_null_ptr     => try airIsNull(o, inst, "==", "[0]"),
            .is_non_null_ptr => try airIsNull(o, inst, "!=", "[0]"),

            .alloc            => try airAlloc(o, inst),
            .assembly         => try airAsm(o, inst),
            .block            => try airBlock(o, inst),
            .bitcast          => try airBitcast(o, inst),
            .call             => try airCall(o, inst),
            .dbg_stmt         => try airDbgStmt(o, inst),
            .intcast          => try airIntCast(o, inst),
            .trunc            => try airTrunc(o, inst),
            .bool_to_int      => try airBoolToInt(o, inst),
            .load             => try airLoad(o, inst),
            .ret              => try airRet(o, inst),
            .store            => try airStore(o, inst),
            .loop             => try airLoop(o, inst),
            .cond_br          => try airCondBr(o, inst),
            .br               => try airBr(o, inst),
            .switch_br        => try airSwitchBr(o, inst),
            .wrap_optional    => try airWrapOptional(o, inst),
            .struct_field_ptr => try airStructFieldPtr(o, inst),

            .struct_field_ptr_index_0 => try airStructFieldPtrIndex(o, inst, 0),
            .struct_field_ptr_index_1 => try airStructFieldPtrIndex(o, inst, 1),
            .struct_field_ptr_index_2 => try airStructFieldPtrIndex(o, inst, 2),
            .struct_field_ptr_index_3 => try airStructFieldPtrIndex(o, inst, 3),

            .struct_field_val => try airStructFieldVal(o, inst),
            .slice_ptr        => try airSliceField(o, inst, ".ptr;\n"),
            .slice_len        => try airSliceField(o, inst, ".len;\n"),

            .ptr_elem_val       => try airPtrElemVal(o, inst, "["),
            .ptr_ptr_elem_val   => try airPtrElemVal(o, inst, "[0]["),
            .ptr_elem_ptr       => try airPtrElemPtr(o, inst),
            .slice_elem_val     => try airSliceElemVal(o, inst, "["),
            .ptr_slice_elem_val => try airSliceElemVal(o, inst, "[0]["),

            .unwrap_errunion_payload     => try airUnwrapErrUnionPay(o, inst),
            .unwrap_errunion_err         => try airUnwrapErrUnionErr(o, inst),
            .unwrap_errunion_payload_ptr => try airUnwrapErrUnionPay(o, inst),
            .unwrap_errunion_err_ptr     => try airUnwrapErrUnionErr(o, inst),
            .wrap_errunion_payload       => try airWrapErrUnionPay(o, inst),
            .wrap_errunion_err           => try airWrapErrUnionErr(o, inst),

            .ptrtoint  => return o.dg.fail("TODO: C backend: implement codegen for ptrtoint", .{}),
            .floatcast => return o.dg.fail("TODO: C backend: implement codegen for floatcast", .{}),
            // zig fmt: on
        };
        switch (result_value) {
            .none => {},
            else => try o.value_map.putNoClobber(inst, result_value),
        }
    }

    o.indent_writer.popIndent();
    try writer.writeAll("}");
}

fn airSliceField(o: *Object, inst: Air.Inst.Index, suffix: []const u8) !CValue {
    if (o.liveness.isUnused(inst))
        return CValue.none;

    const ty_op = o.air.instructions.items(.data)[inst].ty_op;
    const operand = try o.resolveInst(ty_op.operand);
    const writer = o.writer();
    const local = try o.allocLocal(Type.initTag(.usize), .Const);
    try writer.writeAll(" = ");
    try o.writeCValue(writer, operand);
    try writer.writeAll(suffix);
    return local;
}

fn airPtrElemVal(o: *Object, inst: Air.Inst.Index, prefix: []const u8) !CValue {
    const is_volatile = false; // TODO
    if (!is_volatile and o.liveness.isUnused(inst))
        return CValue.none;

    _ = prefix;
    return o.dg.fail("TODO: C backend: airPtrElemVal", .{});
}

fn airPtrElemPtr(o: *Object, inst: Air.Inst.Index) !CValue {
    if (o.liveness.isUnused(inst))
        return CValue.none;

    return o.dg.fail("TODO: C backend: airPtrElemPtr", .{});
}

fn airSliceElemVal(o: *Object, inst: Air.Inst.Index, prefix: []const u8) !CValue {
    const is_volatile = false; // TODO
    if (!is_volatile and o.liveness.isUnused(inst))
        return CValue.none;

    const bin_op = o.air.instructions.items(.data)[inst].bin_op;
    const slice = try o.resolveInst(bin_op.lhs);
    const index = try o.resolveInst(bin_op.rhs);
    const writer = o.writer();
    const local = try o.allocLocal(o.air.typeOfIndex(inst), .Const);
    try writer.writeAll(" = ");
    try o.writeCValue(writer, slice);
    try writer.writeAll(prefix);
    try o.writeCValue(writer, index);
    try writer.writeAll("];\n");
    return local;
}

fn airAlloc(o: *Object, inst: Air.Inst.Index) !CValue {
    const writer = o.writer();
    const inst_ty = o.air.typeOfIndex(inst);

    // First line: the variable used as data storage.
    const elem_type = inst_ty.elemType();
    const mutability: Mutability = if (inst_ty.isConstPtr()) .Const else .Mut;
    const local = try o.allocLocal(elem_type, mutability);
    try writer.writeAll(";\n");

    return CValue{ .local_ref = local.local };
}

fn airArg(o: *Object) CValue {
    const i = o.next_arg_index;
    o.next_arg_index += 1;
    return .{ .arg = i };
}

fn airLoad(o: *Object, inst: Air.Inst.Index) !CValue {
    const ty_op = o.air.instructions.items(.data)[inst].ty_op;
    const is_volatile = o.air.typeOf(ty_op.operand).isVolatilePtr();
    if (!is_volatile and o.liveness.isUnused(inst))
        return CValue.none;
    const inst_ty = o.air.typeOfIndex(inst);
    const operand = try o.resolveInst(ty_op.operand);
    const writer = o.writer();
    const local = try o.allocLocal(inst_ty, .Const);
    switch (operand) {
        .local_ref => |i| {
            const wrapped: CValue = .{ .local = i };
            try writer.writeAll(" = ");
            try o.writeCValue(writer, wrapped);
            try writer.writeAll(";\n");
        },
        .decl_ref => |decl| {
            const wrapped: CValue = .{ .decl = decl };
            try writer.writeAll(" = ");
            try o.writeCValue(writer, wrapped);
            try writer.writeAll(";\n");
        },
        else => {
            try writer.writeAll(" = *");
            try o.writeCValue(writer, operand);
            try writer.writeAll(";\n");
        },
    }
    return local;
}

fn airRet(o: *Object, inst: Air.Inst.Index) !CValue {
    const un_op = o.air.instructions.items(.data)[inst].un_op;
    const writer = o.writer();
    if (o.air.typeOf(un_op).hasCodeGenBits()) {
        const operand = try o.resolveInst(un_op);
        try writer.writeAll("return ");
        try o.writeCValue(writer, operand);
        try writer.writeAll(";\n");
    } else {
        try writer.writeAll("return;\n");
    }
    return CValue.none;
}

fn airIntCast(o: *Object, inst: Air.Inst.Index) !CValue {
    if (o.liveness.isUnused(inst))
        return CValue.none;

    const ty_op = o.air.instructions.items(.data)[inst].ty_op;
    const operand = try o.resolveInst(ty_op.operand);

    const writer = o.writer();
    const inst_ty = o.air.typeOfIndex(inst);
    const local = try o.allocLocal(inst_ty, .Const);
    try writer.writeAll(" = (");
    try o.dg.renderType(writer, inst_ty);
    try writer.writeAll(")");
    try o.writeCValue(writer, operand);
    try writer.writeAll(";\n");
    return local;
}

fn airTrunc(o: *Object, inst: Air.Inst.Index) !CValue {
    if (o.liveness.isUnused(inst))
        return CValue.none;

    const ty_op = o.air.instructions.items(.data)[inst].ty_op;
    const operand = try o.resolveInst(ty_op.operand);
    _ = operand;
    return o.dg.fail("TODO: C backend: airTrunc", .{});
}

fn airBoolToInt(o: *Object, inst: Air.Inst.Index) !CValue {
    if (o.liveness.isUnused(inst))
        return CValue.none;
    const un_op = o.air.instructions.items(.data)[inst].un_op;
    const writer = o.writer();
    const inst_ty = o.air.typeOfIndex(inst);
    const operand = try o.resolveInst(un_op);
    const local = try o.allocLocal(inst_ty, .Const);
    try writer.writeAll(" = ");
    try o.writeCValue(writer, operand);
    try writer.writeAll(";\n");
    return local;
}

fn airStore(o: *Object, inst: Air.Inst.Index) !CValue {
    // *a = b;
    const bin_op = o.air.instructions.items(.data)[inst].bin_op;
    const dest_ptr = try o.resolveInst(bin_op.lhs);
    const src_val = try o.resolveInst(bin_op.rhs);

    const writer = o.writer();
    switch (dest_ptr) {
        .local_ref => |i| {
            const dest: CValue = .{ .local = i };
            try o.writeCValue(writer, dest);
            try writer.writeAll(" = ");
            try o.writeCValue(writer, src_val);
            try writer.writeAll(";\n");
        },
        .decl_ref => |decl| {
            const dest: CValue = .{ .decl = decl };
            try o.writeCValue(writer, dest);
            try writer.writeAll(" = ");
            try o.writeCValue(writer, src_val);
            try writer.writeAll(";\n");
        },
        else => {
            try writer.writeAll("*");
            try o.writeCValue(writer, dest_ptr);
            try writer.writeAll(" = ");
            try o.writeCValue(writer, src_val);
            try writer.writeAll(";\n");
        },
    }
    return CValue.none;
}

fn airWrapOp(
    o: *Object,
    inst: Air.Inst.Index,
    str_op: [*:0]const u8,
    fn_op: [*:0]const u8,
) !CValue {
    if (o.liveness.isUnused(inst))
        return CValue.none;

    const bin_op = o.air.instructions.items(.data)[inst].bin_op;
    const inst_ty = o.air.typeOfIndex(inst);
    const int_info = inst_ty.intInfo(o.dg.module.getTarget());
    const bits = int_info.bits;

    // if it's an unsigned int with non-arbitrary bit size then we can just add
    if (int_info.signedness == .unsigned) {
        const ok_bits = switch (bits) {
            8, 16, 32, 64, 128 => true,
            else => false,
        };
        if (ok_bits or inst_ty.tag() != .int_unsigned) {
            return try airBinOp(o, inst, str_op);
        }
    }

    if (bits > 64) {
        return o.dg.fail("TODO: C backend: airWrapOp for large integers", .{});
    }

    var min_buf: [80]u8 = undefined;
    const min = switch (int_info.signedness) {
        .unsigned => "0",
        else => switch (inst_ty.tag()) {
            .c_short => "SHRT_MIN",
            .c_int => "INT_MIN",
            .c_long => "LONG_MIN",
            .c_longlong => "LLONG_MIN",
            .isize => "INTPTR_MIN",
            else => blk: {
                const val = -1 * std.math.pow(i64, 2, @intCast(i64, bits - 1));
                break :blk std.fmt.bufPrint(&min_buf, "{d}", .{val}) catch |err| switch (err) {
                    error.NoSpaceLeft => unreachable,
                    else => |e| return e,
                };
            },
        },
    };

    var max_buf: [80]u8 = undefined;
    const max = switch (inst_ty.tag()) {
        .c_short => "SHRT_MAX",
        .c_ushort => "USHRT_MAX",
        .c_int => "INT_MAX",
        .c_uint => "UINT_MAX",
        .c_long => "LONG_MAX",
        .c_ulong => "ULONG_MAX",
        .c_longlong => "LLONG_MAX",
        .c_ulonglong => "ULLONG_MAX",
        .isize => "INTPTR_MAX",
        .usize => "UINTPTR_MAX",
        else => blk: {
            const pow_bits = switch (int_info.signedness) {
                .signed => bits - 1,
                .unsigned => bits,
            };
            const val = std.math.pow(u64, 2, pow_bits) - 1;
            break :blk std.fmt.bufPrint(&max_buf, "{}", .{val}) catch |err| switch (err) {
                error.NoSpaceLeft => unreachable,
                else => |e| return e,
            };
        },
    };

    const lhs = try o.resolveInst(bin_op.lhs);
    const rhs = try o.resolveInst(bin_op.rhs);
    const w = o.writer();

    const ret = try o.allocLocal(inst_ty, .Mut);
    try w.print(" = zig_{s}", .{fn_op});

    switch (inst_ty.tag()) {
        .isize => try w.writeAll("isize"),
        .c_short => try w.writeAll("short"),
        .c_int => try w.writeAll("int"),
        .c_long => try w.writeAll("long"),
        .c_longlong => try w.writeAll("longlong"),
        else => {
            const prefix_byte: u8 = switch (int_info.signedness) {
                .signed => 'i',
                .unsigned => 'u',
            };
            for ([_]u8{ 8, 16, 32, 64 }) |nbits| {
                if (bits <= nbits) {
                    try w.print("{c}{d}", .{ prefix_byte, nbits });
                    break;
                }
            } else {
                unreachable;
            }
        },
    }

    try w.writeByte('(');
    try o.writeCValue(w, lhs);
    try w.writeAll(", ");
    try o.writeCValue(w, rhs);

    if (int_info.signedness == .signed) {
        try w.print(", {s}", .{min});
    }

    try w.print(", {s});", .{max});
    try o.indent_writer.insertNewline();

    return ret;
}

fn airNot(o: *Object, inst: Air.Inst.Index) !CValue {
    if (o.liveness.isUnused(inst))
        return CValue.none;

    const ty_op = o.air.instructions.items(.data)[inst].ty_op;
    const op = try o.resolveInst(ty_op.operand);

    const writer = o.writer();
    const inst_ty = o.air.typeOfIndex(inst);
    const local = try o.allocLocal(inst_ty, .Const);

    try writer.writeAll(" = ");
    if (inst_ty.zigTypeTag() == .Bool)
        try writer.writeAll("!")
    else
        try writer.writeAll("~");
    try o.writeCValue(writer, op);
    try writer.writeAll(";\n");

    return local;
}

fn airBinOp(o: *Object, inst: Air.Inst.Index, operator: [*:0]const u8) !CValue {
    if (o.liveness.isUnused(inst))
        return CValue.none;

    const bin_op = o.air.instructions.items(.data)[inst].bin_op;
    const lhs = try o.resolveInst(bin_op.lhs);
    const rhs = try o.resolveInst(bin_op.rhs);

    const writer = o.writer();
    const inst_ty = o.air.typeOfIndex(inst);
    const local = try o.allocLocal(inst_ty, .Const);

    try writer.writeAll(" = ");
    try o.writeCValue(writer, lhs);
    try writer.print("{s}", .{operator});
    try o.writeCValue(writer, rhs);
    try writer.writeAll(";\n");

    return local;
}

fn airCall(o: *Object, inst: Air.Inst.Index) !CValue {
    const pl_op = o.air.instructions.items(.data)[inst].pl_op;
    const extra = o.air.extraData(Air.Call, pl_op.payload);
    const args = @bitCast([]const Air.Inst.Ref, o.air.extra[extra.end..][0..extra.data.args_len]);
    const fn_ty = o.air.typeOf(pl_op.operand);
    const ret_ty = fn_ty.fnReturnType();
    const unused_result = o.liveness.isUnused(inst);
    const writer = o.writer();

    var result_local: CValue = .none;
    if (unused_result) {
        if (ret_ty.hasCodeGenBits()) {
            try writer.print("(void)", .{});
        }
    } else {
        result_local = try o.allocLocal(ret_ty, .Const);
        try writer.writeAll(" = ");
    }

    if (o.air.value(pl_op.operand)) |func_val| {
        const fn_decl = if (func_val.castTag(.extern_fn)) |extern_fn|
            extern_fn.data
        else if (func_val.castTag(.function)) |func_payload|
            func_payload.data.owner_decl
        else
            unreachable;

        try writer.writeAll(mem.spanZ(fn_decl.name));
    } else {
        const callee = try o.resolveInst(pl_op.operand);
        try o.writeCValue(writer, callee);
    }

    try writer.writeAll("(");
    for (args) |arg, i| {
        if (i != 0) {
            try writer.writeAll(", ");
        }
        if (o.air.value(arg)) |val| {
            try o.dg.renderValue(writer, o.air.typeOf(arg), val);
        } else {
            const val = try o.resolveInst(arg);
            try o.writeCValue(writer, val);
        }
    }
    try writer.writeAll(");\n");
    return result_local;
}

fn airDbgStmt(o: *Object, inst: Air.Inst.Index) !CValue {
    const dbg_stmt = o.air.instructions.items(.data)[inst].dbg_stmt;
    const writer = o.writer();
    try writer.print("#line {d}\n", .{dbg_stmt.line + 1});
    return CValue.none;
}

fn airBlock(o: *Object, inst: Air.Inst.Index) !CValue {
    const ty_pl = o.air.instructions.items(.data)[inst].ty_pl;
    const extra = o.air.extraData(Air.Block, ty_pl.payload);
    const body = o.air.extra[extra.end..][0..extra.data.body_len];

    const block_id: usize = o.next_block_index;
    o.next_block_index += 1;
    const writer = o.writer();

    const inst_ty = o.air.typeOfIndex(inst);
    const result = if (inst_ty.tag() != .void and !o.liveness.isUnused(inst)) blk: {
        // allocate a location for the result
        const local = try o.allocLocal(inst_ty, .Mut);
        try writer.writeAll(";\n");
        break :blk local;
    } else CValue{ .none = {} };

    try o.blocks.putNoClobber(o.gpa, inst, .{
        .block_id = block_id,
        .result = result,
    });

    try genBody(o, body);
    try o.indent_writer.insertNewline();
    // label must be followed by an expression, add an empty one.
    try writer.print("zig_block_{d}:;\n", .{block_id});
    return result;
}

fn airBr(o: *Object, inst: Air.Inst.Index) !CValue {
    const branch = o.air.instructions.items(.data)[inst].br;
    const block = o.blocks.get(branch.block_inst).?;
    const result = block.result;
    const writer = o.writer();

    // If result is .none then the value of the block is unused.
    if (result != .none) {
        const operand = try o.resolveInst(branch.operand);
        try o.writeCValue(writer, result);
        try writer.writeAll(" = ");
        try o.writeCValue(writer, operand);
        try writer.writeAll(";\n");
    }

    try o.writer().print("goto zig_block_{d};\n", .{block.block_id});
    return CValue.none;
}

fn airBitcast(o: *Object, inst: Air.Inst.Index) !CValue {
    const ty_op = o.air.instructions.items(.data)[inst].ty_op;
    const operand = try o.resolveInst(ty_op.operand);

    const writer = o.writer();
    const inst_ty = o.air.typeOfIndex(inst);
    if (inst_ty.zigTypeTag() == .Pointer and
        o.air.typeOf(ty_op.operand).zigTypeTag() == .Pointer)
    {
        const local = try o.allocLocal(inst_ty, .Const);
        try writer.writeAll(" = (");
        try o.dg.renderType(writer, inst_ty);

        try writer.writeAll(")");
        try o.writeCValue(writer, operand);
        try writer.writeAll(";\n");
        return local;
    }

    const local = try o.allocLocal(inst_ty, .Mut);
    try writer.writeAll(";\n");

    try writer.writeAll("memcpy(&");
    try o.writeCValue(writer, local);
    try writer.writeAll(", &");
    try o.writeCValue(writer, operand);
    try writer.writeAll(", sizeof ");
    try o.writeCValue(writer, local);
    try writer.writeAll(");\n");

    return local;
}

fn airBreakpoint(o: *Object) !CValue {
    try o.writer().writeAll("zig_breakpoint();\n");
    return CValue.none;
}

fn airUnreach(o: *Object) !CValue {
    try o.writer().writeAll("zig_unreachable();\n");
    return CValue.none;
}

fn airLoop(o: *Object, inst: Air.Inst.Index) !CValue {
    const ty_pl = o.air.instructions.items(.data)[inst].ty_pl;
    const loop = o.air.extraData(Air.Block, ty_pl.payload);
    const body = o.air.extra[loop.end..][0..loop.data.body_len];
    try o.writer().writeAll("while (true) ");
    try genBody(o, body);
    try o.indent_writer.insertNewline();
    return CValue.none;
}

fn airCondBr(o: *Object, inst: Air.Inst.Index) !CValue {
    const pl_op = o.air.instructions.items(.data)[inst].pl_op;
    const cond = try o.resolveInst(pl_op.operand);
    const extra = o.air.extraData(Air.CondBr, pl_op.payload);
    const then_body = o.air.extra[extra.end..][0..extra.data.then_body_len];
    const else_body = o.air.extra[extra.end + then_body.len ..][0..extra.data.else_body_len];
    const writer = o.writer();

    try writer.writeAll("if (");
    try o.writeCValue(writer, cond);
    try writer.writeAll(") ");
    try genBody(o, then_body);
    try writer.writeAll(" else ");
    try genBody(o, else_body);
    try o.indent_writer.insertNewline();

    return CValue.none;
}

fn airSwitchBr(o: *Object, inst: Air.Inst.Index) !CValue {
    const pl_op = o.air.instructions.items(.data)[inst].pl_op;
    const condition = try o.resolveInst(pl_op.operand);
    const condition_ty = o.air.typeOf(pl_op.operand);
    const switch_br = o.air.extraData(Air.SwitchBr, pl_op.payload);
    const writer = o.writer();

    try writer.writeAll("switch (");
    try o.writeCValue(writer, condition);
    try writer.writeAll(") {");
    o.indent_writer.pushIndent();

    var extra_index: usize = switch_br.end;
    var case_i: u32 = 0;
    while (case_i < switch_br.data.cases_len) : (case_i += 1) {
        const case = o.air.extraData(Air.SwitchBr.Case, extra_index);
        const items = @bitCast([]const Air.Inst.Ref, o.air.extra[case.end..][0..case.data.items_len]);
        const case_body = o.air.extra[case.end + items.len ..][0..case.data.body_len];
        extra_index = case.end + case.data.items_len + case_body.len;

        for (items) |item| {
            try o.indent_writer.insertNewline();
            try writer.writeAll("case ");
            try o.dg.renderValue(writer, condition_ty, o.air.value(item).?);
            try writer.writeAll(": ");
        }
        // The case body must be noreturn so we don't need to insert a break.
        try genBody(o, case_body);
    }

    const else_body = o.air.extra[extra_index..][0..switch_br.data.else_body_len];
    try o.indent_writer.insertNewline();
    try writer.writeAll("default: ");
    try genBody(o, else_body);
    try o.indent_writer.insertNewline();

    o.indent_writer.popIndent();
    try writer.writeAll("}\n");
    return CValue.none;
}

fn airAsm(o: *Object, inst: Air.Inst.Index) !CValue {
    const air_datas = o.air.instructions.items(.data);
    const air_extra = o.air.extraData(Air.Asm, air_datas[inst].ty_pl.payload);
    const zir = o.dg.decl.namespace.file_scope.zir;
    const extended = zir.instructions.items(.data)[air_extra.data.zir_index].extended;
    const zir_extra = zir.extraData(Zir.Inst.Asm, extended.operand);
    const asm_source = zir.nullTerminatedString(zir_extra.data.asm_source);
    const outputs_len = @truncate(u5, extended.small);
    const args_len = @truncate(u5, extended.small >> 5);
    const clobbers_len = @truncate(u5, extended.small >> 10);
    _ = clobbers_len; // TODO honor these
    const is_volatile = @truncate(u1, extended.small >> 15) != 0;
    const outputs = @bitCast([]const Air.Inst.Ref, o.air.extra[air_extra.end..][0..outputs_len]);
    const args = @bitCast([]const Air.Inst.Ref, o.air.extra[air_extra.end + outputs.len ..][0..args_len]);

    if (outputs_len > 1) {
        return o.dg.fail("TODO implement codegen for asm with more than 1 output", .{});
    }

    if (o.liveness.isUnused(inst) and !is_volatile)
        return CValue.none;

    var extra_i: usize = zir_extra.end;
    const output_constraint: ?[]const u8 = out: {
        var i: usize = 0;
        while (i < outputs_len) : (i += 1) {
            const output = zir.extraData(Zir.Inst.Asm.Output, extra_i);
            extra_i = output.end;
            break :out zir.nullTerminatedString(output.data.constraint);
        }
        break :out null;
    };
    const args_extra_begin = extra_i;

    const writer = o.writer();
    for (args) |arg| {
        const input = zir.extraData(Zir.Inst.Asm.Input, extra_i);
        extra_i = input.end;
        const constraint = zir.nullTerminatedString(input.data.constraint);
        if (constraint[0] == '{' and constraint[constraint.len - 1] == '}') {
            const reg = constraint[1 .. constraint.len - 1];
            const arg_c_value = try o.resolveInst(arg);
            try writer.writeAll("register ");
            try o.dg.renderType(writer, o.air.typeOf(arg));

            try writer.print(" {s}_constant __asm__(\"{s}\") = ", .{ reg, reg });
            try o.writeCValue(writer, arg_c_value);
            try writer.writeAll(";\n");
        } else {
            return o.dg.fail("TODO non-explicit inline asm regs", .{});
        }
    }
    const volatile_string: []const u8 = if (is_volatile) "volatile " else "";
    try writer.print("__asm {s}(\"{s}\"", .{ volatile_string, asm_source });
    if (output_constraint) |_| {
        return o.dg.fail("TODO: CBE inline asm output", .{});
    }
    if (args.len > 0) {
        if (output_constraint == null) {
            try writer.writeAll(" :");
        }
        try writer.writeAll(": ");
        extra_i = args_extra_begin;
        for (args) |_, index| {
            const input = zir.extraData(Zir.Inst.Asm.Input, extra_i);
            extra_i = input.end;
            const constraint = zir.nullTerminatedString(input.data.constraint);
            if (constraint[0] == '{' and constraint[constraint.len - 1] == '}') {
                const reg = constraint[1 .. constraint.len - 1];
                if (index > 0) {
                    try writer.writeAll(", ");
                }
                try writer.print("\"r\"({s}_constant)", .{reg});
            } else {
                // This is blocked by the earlier test
                unreachable;
            }
        }
    }
    try writer.writeAll(");\n");

    if (o.liveness.isUnused(inst))
        return CValue.none;

    return o.dg.fail("TODO: C backend: inline asm expression result used", .{});
}

fn airIsNull(
    o: *Object,
    inst: Air.Inst.Index,
    operator: [*:0]const u8,
    deref_suffix: [*:0]const u8,
) !CValue {
    if (o.liveness.isUnused(inst))
        return CValue.none;

    const un_op = o.air.instructions.items(.data)[inst].un_op;
    const writer = o.writer();
    const operand = try o.resolveInst(un_op);

    const local = try o.allocLocal(Type.initTag(.bool), .Const);
    try writer.writeAll(" = (");
    try o.writeCValue(writer, operand);

    if (o.air.typeOf(un_op).isPtrLikeOptional()) {
        // operand is a regular pointer, test `operand !=/== NULL`
        try writer.print("){s} {s} NULL;\n", .{ deref_suffix, operator });
    } else {
        try writer.print("){s}.is_null {s} true;\n", .{ deref_suffix, operator });
    }
    return local;
}

fn airOptionalPayload(o: *Object, inst: Air.Inst.Index) !CValue {
    if (o.liveness.isUnused(inst))
        return CValue.none;

    const ty_op = o.air.instructions.items(.data)[inst].ty_op;
    const writer = o.writer();
    const operand = try o.resolveInst(ty_op.operand);
    const operand_ty = o.air.typeOf(ty_op.operand);

    const opt_ty = if (operand_ty.zigTypeTag() == .Pointer)
        operand_ty.elemType()
    else
        operand_ty;

    if (opt_ty.isPtrLikeOptional()) {
        // the operand is just a regular pointer, no need to do anything special.
        // *?*T -> **T and ?*T -> *T are **T -> **T and *T -> *T in C
        return operand;
    }

    const inst_ty = o.air.typeOfIndex(inst);
    const maybe_deref = if (operand_ty.zigTypeTag() == .Pointer) "->" else ".";
    const maybe_addrof = if (inst_ty.zigTypeTag() == .Pointer) "&" else "";

    const local = try o.allocLocal(inst_ty, .Const);
    try writer.print(" = {s}(", .{maybe_addrof});
    try o.writeCValue(writer, operand);

    try writer.print("){s}payload;\n", .{maybe_deref});
    return local;
}

fn airStructFieldPtr(o: *Object, inst: Air.Inst.Index) !CValue {
    if (o.liveness.isUnused(inst))
        // TODO this @as is needed because of a stage1 bug
        return @as(CValue, CValue.none);

    const ty_pl = o.air.instructions.items(.data)[inst].ty_pl;
    const extra = o.air.extraData(Air.StructField, ty_pl.payload).data;
    const struct_ptr = try o.resolveInst(extra.struct_operand);
    const struct_ptr_ty = o.air.typeOf(extra.struct_operand);
    return structFieldPtr(o, inst, struct_ptr_ty, struct_ptr, extra.field_index);
}

fn airStructFieldPtrIndex(o: *Object, inst: Air.Inst.Index, index: u8) !CValue {
    if (o.liveness.isUnused(inst))
        // TODO this @as is needed because of a stage1 bug
        return @as(CValue, CValue.none);

    const ty_op = o.air.instructions.items(.data)[inst].ty_op;
    const struct_ptr = try o.resolveInst(ty_op.operand);
    const struct_ptr_ty = o.air.typeOf(ty_op.operand);
    return structFieldPtr(o, inst, struct_ptr_ty, struct_ptr, index);
}

fn structFieldPtr(o: *Object, inst: Air.Inst.Index, struct_ptr_ty: Type, struct_ptr: CValue, index: u32) !CValue {
    const writer = o.writer();
    const struct_obj = struct_ptr_ty.elemType().castTag(.@"struct").?.data;
    const field_name = struct_obj.fields.keys()[index];

    const inst_ty = o.air.typeOfIndex(inst);
    const local = try o.allocLocal(inst_ty, .Const);
    switch (struct_ptr) {
        .local_ref => |i| {
            try writer.print(" = &t{d}.{};\n", .{ i, fmtIdent(field_name) });
        },
        else => {
            try writer.writeAll(" = &");
            try o.writeCValue(writer, struct_ptr);
            try writer.print("->{};\n", .{fmtIdent(field_name)});
        },
    }
    return local;
}

fn airStructFieldVal(o: *Object, inst: Air.Inst.Index) !CValue {
    if (o.liveness.isUnused(inst))
        return CValue.none;

    const ty_pl = o.air.instructions.items(.data)[inst].ty_pl;
    const extra = o.air.extraData(Air.StructField, ty_pl.payload).data;
    const writer = o.writer();
    const struct_byval = try o.resolveInst(extra.struct_operand);
    const struct_ty = o.air.typeOf(extra.struct_operand);
    const struct_obj = struct_ty.castTag(.@"struct").?.data;
    const field_name = struct_obj.fields.keys()[extra.field_index];

    const inst_ty = o.air.typeOfIndex(inst);
    const local = try o.allocLocal(inst_ty, .Const);
    try writer.writeAll(" = ");
    try o.writeCValue(writer, struct_byval);
    try writer.print(".{};\n", .{fmtIdent(field_name)});
    return local;
}

// *(E!T) -> E NOT *E
fn airUnwrapErrUnionErr(o: *Object, inst: Air.Inst.Index) !CValue {
    if (o.liveness.isUnused(inst))
        return CValue.none;

    const ty_op = o.air.instructions.items(.data)[inst].ty_op;
    const inst_ty = o.air.typeOfIndex(inst);
    const writer = o.writer();
    const operand = try o.resolveInst(ty_op.operand);
    const operand_ty = o.air.typeOf(ty_op.operand);

    const payload_ty = operand_ty.errorUnionPayload();
    if (!payload_ty.hasCodeGenBits()) {
        if (operand_ty.zigTypeTag() == .Pointer) {
            const local = try o.allocLocal(inst_ty, .Const);
            try writer.writeAll(" = *");
            try o.writeCValue(writer, operand);
            try writer.writeAll(";\n");
            return local;
        } else {
            return operand;
        }
    }

    const maybe_deref = if (operand_ty.zigTypeTag() == .Pointer) "->" else ".";

    const local = try o.allocLocal(inst_ty, .Const);
    try writer.writeAll(" = (");
    try o.writeCValue(writer, operand);

    try writer.print("){s}error;\n", .{maybe_deref});
    return local;
}

fn airUnwrapErrUnionPay(o: *Object, inst: Air.Inst.Index) !CValue {
    if (o.liveness.isUnused(inst))
        return CValue.none;

    const ty_op = o.air.instructions.items(.data)[inst].ty_op;
    const writer = o.writer();
    const operand = try o.resolveInst(ty_op.operand);
    const operand_ty = o.air.typeOf(ty_op.operand);

    const payload_ty = operand_ty.errorUnionPayload();
    if (!payload_ty.hasCodeGenBits()) {
        return CValue.none;
    }

    const inst_ty = o.air.typeOfIndex(inst);
    const maybe_deref = if (operand_ty.zigTypeTag() == .Pointer) "->" else ".";
    const maybe_addrof = if (inst_ty.zigTypeTag() == .Pointer) "&" else "";

    const local = try o.allocLocal(inst_ty, .Const);
    try writer.print(" = {s}(", .{maybe_addrof});
    try o.writeCValue(writer, operand);

    try writer.print("){s}payload;\n", .{maybe_deref});
    return local;
}

fn airWrapOptional(o: *Object, inst: Air.Inst.Index) !CValue {
    if (o.liveness.isUnused(inst))
        return CValue.none;

    const ty_op = o.air.instructions.items(.data)[inst].ty_op;
    const writer = o.writer();
    const operand = try o.resolveInst(ty_op.operand);

    const inst_ty = o.air.typeOfIndex(inst);
    if (inst_ty.isPtrLikeOptional()) {
        // the operand is just a regular pointer, no need to do anything special.
        return operand;
    }

    // .wrap_optional is used to convert non-optionals into optionals so it can never be null.
    const local = try o.allocLocal(inst_ty, .Const);
    try writer.writeAll(" = { .is_null = false, .payload =");
    try o.writeCValue(writer, operand);
    try writer.writeAll("};\n");
    return local;
}
fn airWrapErrUnionErr(o: *Object, inst: Air.Inst.Index) !CValue {
    if (o.liveness.isUnused(inst))
        return CValue.none;

    const writer = o.writer();
    const ty_op = o.air.instructions.items(.data)[inst].ty_op;
    const operand = try o.resolveInst(ty_op.operand);

    const inst_ty = o.air.typeOfIndex(inst);
    const local = try o.allocLocal(inst_ty, .Const);
    try writer.writeAll(" = { .error = ");
    try o.writeCValue(writer, operand);
    try writer.writeAll(" };\n");
    return local;
}

fn airWrapErrUnionPay(o: *Object, inst: Air.Inst.Index) !CValue {
    if (o.liveness.isUnused(inst))
        return CValue.none;

    const ty_op = o.air.instructions.items(.data)[inst].ty_op;
    const writer = o.writer();
    const operand = try o.resolveInst(ty_op.operand);

    const inst_ty = o.air.typeOfIndex(inst);
    const local = try o.allocLocal(inst_ty, .Const);
    try writer.writeAll(" = { .error = 0, .payload = ");
    try o.writeCValue(writer, operand);
    try writer.writeAll(" };\n");
    return local;
}

fn airIsErr(
    o: *Object,
    inst: Air.Inst.Index,
    deref_prefix: [*:0]const u8,
    deref_suffix: [*:0]const u8,
    op_str: [*:0]const u8,
) !CValue {
    if (o.liveness.isUnused(inst))
        return CValue.none;

    const un_op = o.air.instructions.items(.data)[inst].un_op;
    const writer = o.writer();
    const operand = try o.resolveInst(un_op);
    const operand_ty = o.air.typeOf(un_op);
    const local = try o.allocLocal(Type.initTag(.bool), .Const);
    const payload_ty = operand_ty.errorUnionPayload();
    if (!payload_ty.hasCodeGenBits()) {
        try writer.print(" = {s}", .{deref_prefix});
        try o.writeCValue(writer, operand);
        try writer.print(" {s} 0;\n", .{op_str});
    } else {
        try writer.writeAll(" = ");
        try o.writeCValue(writer, operand);
        try writer.print("{s}error {s} 0;\n", .{ deref_suffix, op_str });
    }
    return local;
}

fn IndentWriter(comptime UnderlyingWriter: type) type {
    return struct {
        const Self = @This();
        pub const Error = UnderlyingWriter.Error;
        pub const Writer = std.io.Writer(*Self, Error, write);

        pub const indent_delta = 1;

        underlying_writer: UnderlyingWriter,
        indent_count: usize = 0,
        current_line_empty: bool = true,

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }

        pub fn write(self: *Self, bytes: []const u8) Error!usize {
            if (bytes.len == 0) return @as(usize, 0);

            const current_indent = self.indent_count * Self.indent_delta;
            if (self.current_line_empty and current_indent > 0) {
                try self.underlying_writer.writeByteNTimes(' ', current_indent);
            }
            self.current_line_empty = false;

            return self.writeNoIndent(bytes);
        }

        pub fn insertNewline(self: *Self) Error!void {
            _ = try self.writeNoIndent("\n");
        }

        pub fn pushIndent(self: *Self) void {
            self.indent_count += 1;
        }

        pub fn popIndent(self: *Self) void {
            assert(self.indent_count != 0);
            self.indent_count -= 1;
        }

        fn writeNoIndent(self: *Self, bytes: []const u8) Error!usize {
            if (bytes.len == 0) return @as(usize, 0);

            try self.underlying_writer.writeAll(bytes);
            if (bytes[bytes.len - 1] == '\n') {
                self.current_line_empty = true;
            }
            return bytes.len;
        }
    };
}
