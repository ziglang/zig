const std = @import("std");
const builtin = @import("builtin");
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
const BigIntConst = std.math.big.int.Const;

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
    /// Render these bytes literally.
    /// TODO make this a [*:0]const u8 to save memory
    bytes: []const u8,
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

/// This data is available when outputting .c code for a `*Module.Fn`.
/// It is not available when generating .h file.
pub const Function = struct {
    air: Air,
    liveness: Liveness,
    value_map: CValueMap,
    blocks: std.AutoHashMapUnmanaged(Air.Inst.Index, BlockData) = .{},
    next_arg_index: usize = 0,
    next_local_index: usize = 0,
    next_block_index: usize = 0,
    object: Object,
    func: *Module.Fn,

    fn resolveInst(f: *Function, inst: Air.Inst.Ref) !CValue {
        if (f.air.value(inst)) |_| {
            return CValue{ .constant = inst };
        }
        const index = Air.refToIndex(inst).?;
        return f.value_map.get(index).?; // Assertion means instruction does not dominate usage.
    }

    fn allocLocalValue(f: *Function) CValue {
        const result = f.next_local_index;
        f.next_local_index += 1;
        return .{ .local = result };
    }

    fn allocLocal(f: *Function, ty: Type, mutability: Mutability) !CValue {
        const local_value = f.allocLocalValue();
        try f.object.dg.renderTypeAndName(f.object.writer(), ty, local_value, mutability);
        return local_value;
    }

    fn writeCValue(f: *Function, w: anytype, c_value: CValue) !void {
        switch (c_value) {
            .constant => |inst| {
                const ty = f.air.typeOf(inst);
                const val = f.air.value(inst).?;
                return f.object.dg.renderValue(w, ty, val);
            },
            else => return f.object.dg.writeCValue(w, c_value),
        }
    }

    fn fail(f: *Function, comptime format: []const u8, args: anytype) error{ AnalysisFail, OutOfMemory } {
        return f.object.dg.fail(format, args);
    }

    fn renderType(f: *Function, w: anytype, t: Type) !void {
        return f.object.dg.renderType(w, t);
    }
};

/// This data is available when outputting .c code for a `Module`.
/// It is not available when generating .h file.
pub const Object = struct {
    dg: DeclGen,
    code: std.ArrayList(u8),
    indent_writer: IndentWriter(std.ArrayList(u8).Writer),

    fn writer(o: *Object) IndentWriter(std.ArrayList(u8).Writer).Writer {
        return o.indent_writer.writer();
    }
};

/// This data is available both when outputting .c code and when outputting an .h file.
pub const DeclGen = struct {
    gpa: *std.mem.Allocator,
    module: *Module,
    decl: *Decl,
    fwd_decl: std.ArrayList(u8),
    error_msg: ?*Module.ErrorMsg,
    /// The key of this map is Type which has references to typedefs_arena.
    typedefs: TypedefMap,
    typedefs_arena: *std.mem.Allocator,

    fn fail(dg: *DeclGen, comptime format: []const u8, args: anytype) error{ AnalysisFail, OutOfMemory } {
        @setCold(true);
        const src: LazySrcLoc = .{ .node_offset = 0 };
        const src_loc = src.toSrcLoc(dg.decl);
        dg.error_msg = try Module.ErrorMsg.create(dg.module.gpa, src_loc, format, args);
        return error.AnalysisFail;
    }

    fn getTypedefName(dg: *DeclGen, t: Type) ?[]const u8 {
        if (dg.typedefs.get(t)) |some| {
            return some.name;
        } else {
            return null;
        }
    }

    fn renderDeclValue(
        dg: *DeclGen,
        writer: anytype,
        ty: Type,
        val: Value,
        decl: *Decl,
    ) error{ OutOfMemory, AnalysisFail }!void {
        decl.alive = true;

        if (ty.isSlice()) {
            try writer.writeByte('(');
            try dg.renderType(writer, ty);
            try writer.writeAll("){");
            var buf: Type.SlicePtrFieldTypeBuffer = undefined;
            try dg.renderValue(writer, ty.slicePtrFieldType(&buf), val);
            try writer.writeAll(", ");
            try writer.print("{d}", .{val.sliceLen()});
            try writer.writeAll("}");
            return;
        }

        assert(decl.has_tv);
        // We shouldn't cast C function pointers as this is UB (when you call
        // them).  The analysis until now should ensure that the C function
        // pointers are compatible.  If they are not, then there is a bug
        // somewhere and we should let the C compiler tell us about it.
        if (ty.castPtrToFn() == null) {
            // Determine if we must pointer cast.
            if (ty.eql(decl.ty)) {
                try writer.writeByte('&');
            } else {
                try writer.writeAll("(");
                try dg.renderType(writer, ty);
                try writer.writeAll(")&");
            }
        }
        try dg.renderDeclName(decl, writer);
    }

    fn renderInt128(
        writer: anytype,
        int_val: anytype,
    ) error{ OutOfMemory, AnalysisFail }!void {
        const int_info = @typeInfo(@TypeOf(int_val)).Int;
        const is_signed = int_info.signedness == .signed;
        const is_neg = int_val < 0;
        comptime assert(int_info.bits > 64 and int_info.bits <= 128);

        // Clang and GCC don't support 128-bit integer constants but will hopefully unfold them
        // if we construct one manually.
        const magnitude = std.math.absCast(int_val);

        const high = @truncate(u64, magnitude >> 64);
        const low = @truncate(u64, magnitude);

        // (int128_t)/<->( ( (uint128_t)( val_high << 64 )u ) + (uint128_t)val_low/u )
        if (is_signed) try writer.writeAll("(int128_t)");
        if (is_neg) try writer.writeByte('-');

        assert(high > 0);
        try writer.print("(((uint128_t)0x{x}u<<64)", .{high});

        if (low > 0)
            try writer.print("+(uint128_t)0x{x}u", .{low});

        return writer.writeByte(')');
    }

    fn renderBigIntConst(
        dg: *DeclGen,
        writer: anytype,
        val: BigIntConst,
        signed: bool,
    ) error{ OutOfMemory, AnalysisFail }!void {
        if (signed) {
            try renderInt128(writer, val.to(i128) catch {
                return dg.fail("TODO implement integer constants larger than 128 bits", .{});
            });
        } else {
            try renderInt128(writer, val.to(u128) catch {
                return dg.fail("TODO implement integer constants larger than 128 bits", .{});
            });
        }
    }

    fn renderValue(
        dg: *DeclGen,
        writer: anytype,
        ty: Type,
        val: Value,
    ) error{ OutOfMemory, AnalysisFail }!void {
        if (val.isUndefDeep()) {
            switch (ty.zigTypeTag()) {
                // Using '{}' for integer and floats seemed to error C compilers (both GCC and Clang)
                // with 'error: expected expression' (including when built with 'zig cc')
                .Int => {
                    const c_bits = toCIntBits(ty.intInfo(dg.module.getTarget()).bits) orelse
                        return dg.fail("TODO: C backend: implement integer types larger than 128 bits", .{});
                    switch (c_bits) {
                        8 => return writer.writeAll("0xaau"),
                        16 => return writer.writeAll("0xaaaau"),
                        32 => return writer.writeAll("0xaaaaaaaau"),
                        64 => return writer.writeAll("0xaaaaaaaaaaaaaaaau"),
                        128 => return renderInt128(writer, @as(u128, 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa)),
                        else => unreachable,
                    }
                },
                .Float => {
                    switch (ty.floatBits(dg.module.getTarget())) {
                        32 => return writer.writeAll("zig_bitcast_f32_u32(0xaaaaaaaau)"),
                        64 => return writer.writeAll("zig_bitcast_f64_u64(0xaaaaaaaaaaaaaaaau)"),
                        else => return dg.fail("TODO float types > 64 bits are not support in renderValue() as of now", .{}),
                    }
                },

                else => {
                    // This should lower to 0xaa bytes in safe modes, and for unsafe modes should
                    // lower to leaving variables uninitialized (that might need to be implemented
                    // outside of this function).
                    return writer.writeAll("{}");
                },
            }
        }
        switch (ty.zigTypeTag()) {
            .Int => switch (val.tag()) {
                .int_big_positive => try dg.renderBigIntConst(writer, val.castTag(.int_big_positive).?.asBigInt(), ty.isSignedInt()),
                .int_big_negative => try dg.renderBigIntConst(writer, val.castTag(.int_big_negative).?.asBigInt(), true),
                else => {
                    if (ty.isSignedInt())
                        return writer.print("{d}", .{val.toSignedInt()});
                    return writer.print("{d}u", .{val.toUnsignedInt()});
                },
            },
            .Float => {
                if (ty.floatBits(dg.module.getTarget()) <= 64) {
                    if (std.math.isNan(val.toFloat(f64)) or std.math.isInf(val.toFloat(f64))) {
                        // just generate a bit cast (exactly like we do in airBitcast)
                        switch (ty.tag()) {
                            .f32 => return writer.print("zig_bitcast_f32_u32(0x{x})", .{@bitCast(u32, val.toFloat(f32))}),
                            .f64 => return writer.print("zig_bitcast_f64_u64(0x{x})", .{@bitCast(u64, val.toFloat(f64))}),
                            else => return dg.fail("TODO float types > 64 bits are not support in renderValue() as of now", .{}),
                        }
                    } else {
                        return writer.print("{x}", .{val.toFloat(f64)});
                    }
                }
                return dg.fail("TODO: C backend: implement lowering large float values", .{});
            },
            .Pointer => switch (val.tag()) {
                .null_value => try writer.writeAll("NULL"),
                // Technically this should produce NULL but the integer literal 0 will always coerce
                // to the assigned pointer type. Note this is just a hack to fix warnings from ordered comparisons (<, >, etc)
                // between pointers and 0, which is an extension to begin with.
                .zero => try writer.writeByte('0'),
                .decl_ref => {
                    const decl = val.castTag(.decl_ref).?.data;
                    return dg.renderDeclValue(writer, ty, val, decl);
                },
                .variable => {
                    const decl = val.castTag(.variable).?.data.owner_decl;
                    return dg.renderDeclValue(writer, ty, val, decl);
                },
                .slice => {
                    const slice = val.castTag(.slice).?.data;
                    var buf: Type.SlicePtrFieldTypeBuffer = undefined;

                    try writer.writeByte('(');
                    try dg.renderType(writer, ty);
                    try writer.writeAll("){");
                    try dg.renderValue(writer, ty.slicePtrFieldType(&buf), slice.ptr);
                    try writer.writeAll(", ");
                    try dg.renderValue(writer, Type.usize, slice.len);
                    try writer.writeAll("}");
                },
                .function => {
                    const func = val.castTag(.function).?.data;
                    try dg.renderDeclName(func.owner_decl, writer);
                },
                .extern_fn => {
                    const decl = val.castTag(.extern_fn).?.data;
                    try dg.renderDeclName(decl, writer);
                },
                .int_u64, .one => {
                    try writer.writeAll("((");
                    try dg.renderType(writer, ty);
                    try writer.print(")0x{x}u)", .{val.toUnsignedInt()});
                },
                else => unreachable,
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
                        const len = ty.arrayLen();
                        const elem_ty = ty.elemType();
                        while (index < len) : (index += 1) {
                            if (index != 0) try writer.writeAll(",");
                            const elem_val = try val.elemValue(&arena.allocator, index);
                            try dg.renderValue(writer, elem_ty, elem_val);
                        }
                        if (ty.sentinel()) |sentinel_val| {
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
                const payload_type = ty.optionalChild(&opt_buf);
                if (ty.isPtrLikeOptional()) {
                    return dg.renderValue(writer, payload_type, val);
                }
                const target = dg.module.getTarget();
                if (payload_type.abiSize(target) == 0) {
                    const is_null = val.castTag(.opt_payload) == null;
                    return writer.print("{}", .{is_null});
                }
                try writer.writeByte('(');
                try dg.renderType(writer, ty);
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
                const error_type = ty.errorUnionSet();
                const payload_type = ty.errorUnionPayload();

                if (!payload_type.hasCodeGenBits()) {
                    // We use the error type directly as the type.
                    const err_val = if (val.errorUnionIsPayload()) Value.initTag(.zero) else val;
                    return dg.renderValue(writer, error_type, err_val);
                }

                try writer.writeByte('(');
                try dg.renderType(writer, ty);
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
                        switch (ty.tag()) {
                            .enum_simple => return writer.print("{d}", .{field_index}),
                            .enum_full, .enum_nonexhaustive => {
                                const enum_full = ty.cast(Type.Payload.EnumFull).?.data;
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
                        const int_tag_ty = ty.intTagType(&int_tag_ty_buffer);
                        return dg.renderValue(writer, int_tag_ty, val);
                    },
                }
            },
            .Fn => switch (val.tag()) {
                .function => {
                    const decl = val.castTag(.function).?.data.owner_decl;
                    return dg.renderDeclValue(writer, ty, val, decl);
                },
                .extern_fn => {
                    const decl = val.castTag(.extern_fn).?.data;
                    return dg.renderDeclValue(writer, ty, val, decl);
                },
                else => unreachable,
            },
            .Struct => {
                const field_vals = val.castTag(.@"struct").?.data;

                try writer.writeAll("(");
                try dg.renderType(writer, ty);
                try writer.writeAll("){");

                for (field_vals) |field_val, i| {
                    const field_ty = ty.structFieldType(i);
                    if (!field_ty.hasCodeGenBits()) continue;

                    if (i != 0) try writer.writeAll(",");
                    try dg.renderValue(writer, field_ty, field_val);
                }

                try writer.writeAll("}");
            },

            .ComptimeInt => unreachable,
            .ComptimeFloat => unreachable,
            .Type => unreachable,
            .EnumLiteral => unreachable,
            .Void => unreachable,
            .NoReturn => unreachable,
            .Undefined => unreachable,
            .Null => unreachable,
            .BoundFn => unreachable,
            .Opaque => unreachable,

            .Union,
            .Frame,
            .AnyFrame,
            .Vector,
            => |tag| return dg.fail("TODO: C backend: implement value of type {s}", .{
                @tagName(tag),
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
        const return_ty = dg.decl.ty.fnReturnType();
        if (return_ty.hasCodeGenBits()) {
            try dg.renderType(w, return_ty);
        } else if (return_ty.zigTypeTag() == .NoReturn) {
            try w.writeAll("zig_noreturn void");
        } else {
            try w.writeAll("void");
        }
        try w.writeAll(" ");
        try dg.renderDeclName(dg.decl, w);
        try w.writeAll("(");
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

    fn renderPtrToFnTypedef(dg: *DeclGen, t: Type, fn_ty: Type) error{ OutOfMemory, AnalysisFail }![]const u8 {
        var buffer = std.ArrayList(u8).init(dg.typedefs.allocator);
        defer buffer.deinit();
        const bw = buffer.writer();

        const fn_info = fn_ty.fnInfo();

        try bw.writeAll("typedef ");
        try dg.renderType(bw, fn_info.return_type);
        try bw.writeAll(" (*");

        const name_start = buffer.items.len;
        // TODO: typeToCIdentifier truncates to 128 bytes, we probably don't want to do this
        try bw.print("zig_F_{s})(", .{typeToCIdentifier(t)});
        const name_end = buffer.items.len - 2;

        const param_len = fn_info.param_types.len;
        const is_var_args = fn_info.is_var_args;
        if (param_len == 0 and !is_var_args)
            try bw.writeAll("void")
        else {
            var index: usize = 0;
            while (index < param_len) : (index += 1) {
                if (index > 0) {
                    try bw.writeAll(", ");
                }
                try dg.renderType(bw, fn_info.param_types[index]);
            }
        }
        if (is_var_args) {
            if (param_len != 0) try bw.writeAll(", ");
            try bw.writeAll("...");
        }
        try bw.writeAll(");\n");

        const rendered = buffer.toOwnedSlice();
        errdefer dg.typedefs.allocator.free(rendered);
        const name = rendered[name_start..name_end];

        try dg.typedefs.ensureUnusedCapacity(1);
        dg.typedefs.putAssumeCapacityNoClobber(
            try t.copy(dg.typedefs_arena),
            .{ .name = name, .rendered = rendered },
        );

        return name;
    }

    fn renderSliceTypedef(dg: *DeclGen, t: Type) error{ OutOfMemory, AnalysisFail }![]const u8 {
        var buffer = std.ArrayList(u8).init(dg.typedefs.allocator);
        defer buffer.deinit();
        const bw = buffer.writer();

        try bw.writeAll("typedef struct { ");
        const elem_type = t.elemType();
        try dg.renderType(bw, elem_type);
        if (t.isConstPtr()) {
            try bw.writeAll(" const");
        }
        if (t.isVolatilePtr()) {
            try bw.writeAll(" volatile");
        }
        try bw.writeAll(" *");
        try bw.writeAll("ptr; size_t len; } ");
        const name_index = buffer.items.len;
        if (t.isConstPtr()) {
            try bw.print("zig_L_{s};\n", .{typeToCIdentifier(elem_type)});
        } else {
            try bw.print("zig_M_{s};\n", .{typeToCIdentifier(elem_type)});
        }

        const rendered = buffer.toOwnedSlice();
        errdefer dg.typedefs.allocator.free(rendered);
        const name = rendered[name_index .. rendered.len - 2];

        try dg.typedefs.ensureUnusedCapacity(1);
        dg.typedefs.putAssumeCapacityNoClobber(
            try t.copy(dg.typedefs_arena),
            .{ .name = name, .rendered = rendered },
        );

        return name;
    }

    fn renderStructTypedef(dg: *DeclGen, t: Type) error{ OutOfMemory, AnalysisFail }![]const u8 {
        const struct_obj = t.castTag(.@"struct").?.data; // Handle 0 bit types elsewhere.
        const fqn = try struct_obj.getFullyQualifiedName(dg.typedefs.allocator);
        defer dg.typedefs.allocator.free(fqn);

        var buffer = std.ArrayList(u8).init(dg.typedefs.allocator);
        defer buffer.deinit();

        try buffer.appendSlice("typedef struct {\n");
        {
            var it = struct_obj.fields.iterator();
            while (it.next()) |entry| {
                const field_ty = entry.value_ptr.ty;
                const name: CValue = .{ .bytes = entry.key_ptr.* };
                try buffer.append(' ');
                try dg.renderTypeAndName(buffer.writer(), field_ty, name, .Mut);
                try buffer.appendSlice(";\n");
            }
        }
        try buffer.appendSlice("} ");

        const name_start = buffer.items.len;
        try buffer.writer().print("zig_S_{s};\n", .{fmtIdent(fqn)});

        const rendered = buffer.toOwnedSlice();
        errdefer dg.typedefs.allocator.free(rendered);
        const name = rendered[name_start .. rendered.len - 2];

        try dg.typedefs.ensureUnusedCapacity(1);
        dg.typedefs.putAssumeCapacityNoClobber(
            try t.copy(dg.typedefs_arena),
            .{ .name = name, .rendered = rendered },
        );

        return name;
    }

    fn renderErrorUnionTypedef(dg: *DeclGen, t: Type) error{ OutOfMemory, AnalysisFail }![]const u8 {
        const child_type = t.errorUnionPayload();
        const err_set_type = t.errorUnionSet();

        var buffer = std.ArrayList(u8).init(dg.typedefs.allocator);
        defer buffer.deinit();
        const bw = buffer.writer();

        try bw.writeAll("typedef struct { ");
        try dg.renderType(bw, child_type);
        try bw.writeAll(" payload; uint16_t error; } ");
        const name_index = buffer.items.len;
        if (err_set_type.castTag(.error_set_inferred)) |inf_err_set_payload| {
            const func = inf_err_set_payload.data.func;
            try bw.writeAll("zig_E_");
            try dg.renderDeclName(func.owner_decl, bw);
            try bw.writeAll(";\n");
        } else {
            try bw.print("zig_E_{s}_{s};\n", .{
                typeToCIdentifier(err_set_type), typeToCIdentifier(child_type),
            });
        }

        const rendered = buffer.toOwnedSlice();
        errdefer dg.typedefs.allocator.free(rendered);
        const name = rendered[name_index .. rendered.len - 2];

        try dg.typedefs.ensureUnusedCapacity(1);
        dg.typedefs.putAssumeCapacityNoClobber(
            try t.copy(dg.typedefs_arena),
            .{ .name = name, .rendered = rendered },
        );

        return name;
    }

    fn renderOptionalTypedef(dg: *DeclGen, t: Type, child_type: Type) error{ OutOfMemory, AnalysisFail }![]const u8 {
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
        dg.typedefs.putAssumeCapacityNoClobber(
            try t.copy(dg.typedefs_arena),
            .{ .name = name, .rendered = rendered },
        );

        return name;
    }

    fn renderType(dg: *DeclGen, w: anytype, t: Type) error{ OutOfMemory, AnalysisFail }!void {
        const target = dg.module.getTarget();

        switch (t.zigTypeTag()) {
            .NoReturn => {
                try w.writeAll("zig_noreturn void");
            },
            .Void => try w.writeAll("void"),
            .Bool => try w.writeAll("bool"),
            .Int => {
                switch (t.tag()) {
                    .u1, .u8 => try w.writeAll("uint8_t"),
                    .i8 => try w.writeAll("int8_t"),
                    .u16 => try w.writeAll("uint16_t"),
                    .i16 => try w.writeAll("int16_t"),
                    .u32 => try w.writeAll("uint32_t"),
                    .i32 => try w.writeAll("int32_t"),
                    .u64 => try w.writeAll("uint64_t"),
                    .i64 => try w.writeAll("int64_t"),
                    .u128 => try w.writeAll("uint128_t"),
                    .i128 => try w.writeAll("int128_t"),
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
                        const info = t.intInfo(target);
                        const sign_prefix = switch (info.signedness) {
                            .signed => "",
                            .unsigned => "u",
                        };
                        const c_bits = toCIntBits(info.bits) orelse
                            return dg.fail("TODO: C backend: implement integer types larger than 128 bits", .{});
                        try w.print("{s}int{d}_t", .{ sign_prefix, c_bits });
                    },
                    else => unreachable,
                }
            },
            .Float => {
                switch (t.tag()) {
                    .f32 => try w.writeAll("float"),
                    .f64 => try w.writeAll("double"),
                    .c_longdouble => try w.writeAll("long double"),
                    .f16 => return dg.fail("TODO: C backend: implement float type f16", .{}),
                    .f128 => return dg.fail("TODO: C backend: implement float type f128", .{}),
                    else => unreachable,
                }
            },
            .Pointer => {
                if (t.isSlice()) {
                    const name = dg.getTypedefName(t) orelse
                        try dg.renderSliceTypedef(t);

                    return w.writeAll(name);
                }

                if (t.castPtrToFn()) |fn_ty| {
                    const name = dg.getTypedefName(t) orelse
                        try dg.renderPtrToFnTypedef(t, fn_ty);

                    return w.writeAll(name);
                }

                try dg.renderType(w, t.elemType());
                if (t.isConstPtr()) {
                    try w.writeAll(" const");
                }
                if (t.isVolatilePtr()) {
                    try w.writeAll(" volatile");
                }
                return w.writeAll(" *");
            },
            .Array => {
                // We are referencing the array so it will decay to a C pointer.
                // NB: arrays are not really types in C so they are either specified in the declaration
                // or are already pointed to; our only job is to render the element type.
                return dg.renderType(w, t.elemType());
            },
            .Optional => {
                var opt_buf: Type.Payload.ElemType = undefined;
                const child_type = t.optionalChild(&opt_buf);

                if (t.isPtrLikeOptional()) {
                    return dg.renderType(w, child_type);
                }

                if (child_type.abiSize(target) == 0) {
                    return w.writeAll("bool");
                }

                const name = dg.getTypedefName(t) orelse
                    try dg.renderOptionalTypedef(t, child_type);

                return w.writeAll(name);
            },
            .ErrorSet => {
                comptime std.debug.assert(Type.initTag(.anyerror).abiSize(builtin.target) == 2);
                return w.writeAll("uint16_t");
            },
            .ErrorUnion => {
                if (t.errorUnionPayload().abiSize(target) == 0) {
                    return dg.renderType(w, t.errorUnionSet());
                }

                const name = dg.getTypedefName(t) orelse
                    try dg.renderErrorUnionTypedef(t);

                return w.writeAll(name);
            },
            .Struct => {
                const name = dg.getTypedefName(t) orelse
                    try dg.renderStructTypedef(t);

                return w.writeAll(name);
            },
            .Enum => {
                // For enums, we simply use the integer tag type.
                var int_tag_ty_buffer: Type.Payload.Bits = undefined;
                const int_tag_ty = t.intTagType(&int_tag_ty_buffer);

                try dg.renderType(w, int_tag_ty);
            },

            .Union,
            .Frame,
            .AnyFrame,
            .Vector,
            .Opaque,
            => |tag| return dg.fail("TODO: C backend: implement value of type {s}", .{
                @tagName(tag),
            }),

            .Fn => unreachable, // This is a function body, not a function pointer.

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

    fn renderTypeAndName(
        dg: *DeclGen,
        w: anytype,
        ty: Type,
        name: CValue,
        mutability: Mutability,
    ) error{ OutOfMemory, AnalysisFail }!void {
        var suffix = std.ArrayList(u8).init(dg.gpa);
        defer suffix.deinit();

        var render_ty = ty;
        while (render_ty.zigTypeTag() == .Array) {
            const sentinel_bit = @boolToInt(render_ty.sentinel() != null);
            const c_len = render_ty.arrayLen() + sentinel_bit;
            try suffix.writer().print("[{d}]", .{c_len});
            render_ty = render_ty.elemType();
        }

        try dg.renderType(w, render_ty);

        const const_prefix = switch (mutability) {
            .Const => "const ",
            .Mut => "",
        };
        try w.print(" {s}", .{const_prefix});
        try dg.writeCValue(w, name);
        try w.writeAll(suffix.items);
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

    fn writeCValue(dg: DeclGen, w: anytype, c_value: CValue) !void {
        switch (c_value) {
            .none => unreachable,
            .local => |i| return w.print("t{d}", .{i}),
            .local_ref => |i| return w.print("&t{d}", .{i}),
            .constant => unreachable,
            .arg => |i| return w.print("a{d}", .{i}),
            .decl => |decl| return dg.renderDeclName(decl, w),
            .decl_ref => |decl| {
                try w.writeByte('&');
                return dg.renderDeclName(decl, w);
            },
            .bytes => |bytes| return w.writeAll(bytes),
        }
    }

    fn renderDeclName(dg: DeclGen, decl: *Decl, writer: anytype) !void {
        if (dg.module.decl_exports.get(decl)) |exports| {
            return writer.writeAll(exports[0].options.name);
        } else if (decl.val.tag() == .extern_fn) {
            return writer.writeAll(mem.spanZ(decl.name));
        } else {
            const gpa = dg.module.gpa;
            const name = try decl.getFullyQualifiedName(gpa);
            defer gpa.free(name);
            return writer.print("{}", .{fmtIdent(name)});
        }
    }
};

pub fn genFunc(f: *Function) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const o = &f.object;
    const is_global = o.dg.module.decl_exports.contains(f.func.owner_decl);
    const fwd_decl_writer = o.dg.fwd_decl.writer();
    if (is_global) {
        try fwd_decl_writer.writeAll("ZIG_EXTERN_C ");
    }
    try o.dg.renderFunctionSignature(fwd_decl_writer, is_global);
    try fwd_decl_writer.writeAll(";\n");

    try o.indent_writer.insertNewline();
    try o.dg.renderFunctionSignature(o.writer(), is_global);

    try o.writer().writeByte(' ');
    const main_body = f.air.getMainBody();
    try genBody(f, main_body);

    try o.indent_writer.insertNewline();
}

pub fn genDecl(o: *Object) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const tv: TypedValue = .{
        .ty = o.dg.decl.ty,
        .val = o.dg.decl.val,
    };
    if (tv.val.tag() == .extern_fn) {
        const writer = o.writer();
        try writer.writeAll("ZIG_EXTERN_C ");
        try o.dg.renderFunctionSignature(writer, true);
        try writer.writeAll(";\n");
    } else if (tv.val.castTag(.variable)) |var_payload| {
        const variable: *Module.Var = var_payload.data;
        const is_global = o.dg.declIsGlobal(tv) or variable.is_extern;
        const fwd_decl_writer = o.dg.fwd_decl.writer();
        if (is_global) {
            try fwd_decl_writer.writeAll("ZIG_EXTERN_C ");
        }
        if (variable.is_threadlocal) {
            try fwd_decl_writer.writeAll("zig_threadlocal ");
        }
        try o.dg.renderType(fwd_decl_writer, o.dg.decl.ty);
        try fwd_decl_writer.writeAll(" ");
        if (is_global) {
            try fwd_decl_writer.writeAll(mem.span(o.dg.decl.name));
        } else {
            try o.dg.renderDeclName(o.dg.decl, fwd_decl_writer);
        }
        try fwd_decl_writer.writeAll(";\n");

        if (variable.init.isUndefDeep()) {
            return;
        }

        try o.indent_writer.insertNewline();
        const w = o.writer();
        try o.dg.renderType(w, o.dg.decl.ty);
        try w.writeAll(" ");
        if (is_global) {
            try w.writeAll(mem.span(o.dg.decl.name));
        } else {
            try o.dg.renderDeclName(o.dg.decl, w);
        }
        try w.writeAll(" = ");
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
        try o.dg.renderTypeAndName(writer, tv.ty, decl_c_value, .Mut);

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

fn genBody(f: *Function, body: []const Air.Inst.Index) error{ AnalysisFail, OutOfMemory }!void {
    const writer = f.object.writer();
    if (body.len == 0) {
        try writer.writeAll("{}");
        return;
    }

    try writer.writeAll("{\n");
    f.object.indent_writer.pushIndent();

    const air_tags = f.air.instructions.items(.tag);

    for (body) |inst| {
        const result_value = switch (air_tags[inst]) {
            // zig fmt: off
            .constant => unreachable, // excluded from function bodies
            .const_ty => unreachable, // excluded from function bodies
            .arg      => airArg(f),

            .breakpoint => try airBreakpoint(f),
            .unreach    => try airUnreach(f),
            .fence      => try airFence(f, inst),

            // TODO use a different strategy for add that communicates to the optimizer
            // that wrapping is UB.
            .add => try airBinOp (f, inst, " + "),
            .ptr_add => try airPtrAddSub (f, inst, " + "),
            // TODO use a different strategy for sub that communicates to the optimizer
            // that wrapping is UB.
            .sub => try airBinOp (f, inst, " - "),
            .ptr_sub => try airPtrAddSub (f, inst, " - "),
            // TODO use a different strategy for mul that communicates to the optimizer
            // that wrapping is UB.
            .mul           => try airBinOp (f, inst, " * "),
            // TODO use a different strategy for div that communicates to the optimizer
            // that wrapping is UB.
            .div_float, .div_exact, .div_trunc => try airBinOp( f, inst, " / "),
            .div_floor                         => try airBinOp( f, inst, " divfloor "),
            .rem           => try airBinOp( f, inst, " % "),
            .mod           => try airBinOp( f, inst, " mod "), // TODO implement modulus division

            .addwrap => try airWrapOp(f, inst, " + ", "addw_"),
            .subwrap => try airWrapOp(f, inst, " - ", "subw_"),
            .mulwrap => try airWrapOp(f, inst, " * ", "mulw_"),

            .add_sat => try airSatOp(f, inst, "adds_"),
            .sub_sat => try airSatOp(f, inst, "subs_"),
            .mul_sat => try airSatOp(f, inst, "muls_"),
            .shl_sat => try airSatOp(f, inst, "shls_"),

            .min => try airMinMax(f, inst, "<"),
            .max => try airMinMax(f, inst, ">"),

            .slice => try airSlice(f, inst),

            .cmp_eq  => try airBinOp(f, inst, " == "),
            .cmp_gt  => try airBinOp(f, inst, " > "),
            .cmp_gte => try airBinOp(f, inst, " >= "),
            .cmp_lt  => try airBinOp(f, inst, " < "),
            .cmp_lte => try airBinOp(f, inst, " <= "),
            .cmp_neq => try airBinOp(f, inst, " != "),

            // bool_and and bool_or are non-short-circuit operations
            .bool_and        => try airBinOp(f, inst, " & "),
            .bool_or         => try airBinOp(f, inst, " | "),
            .bit_and         => try airBinOp(f, inst, " & "),
            .bit_or          => try airBinOp(f, inst, " | "),
            .xor             => try airBinOp(f, inst, " ^ "),
            .shr             => try airBinOp(f, inst, " >> "),
            .shl, .shl_exact => try airBinOp(f, inst, " << "),
            .not             => try airNot  (f, inst),

            .optional_payload         => try airOptionalPayload(f, inst),
            .optional_payload_ptr     => try airOptionalPayload(f, inst),
            .optional_payload_ptr_set => try airOptionalPayloadPtrSet(f, inst),

            .is_err          => try airIsErr(f, inst, "", ".", "!="),
            .is_non_err      => try airIsErr(f, inst, "", ".", "=="),
            .is_err_ptr      => try airIsErr(f, inst, "*", "->", "!="),
            .is_non_err_ptr  => try airIsErr(f, inst, "*", "->", "=="),

            .is_null         => try airIsNull(f, inst, "==", ""),
            .is_non_null     => try airIsNull(f, inst, "!=", ""),
            .is_null_ptr     => try airIsNull(f, inst, "==", "[0]"),
            .is_non_null_ptr => try airIsNull(f, inst, "!=", "[0]"),

            .alloc            => try airAlloc(f, inst),
            .ret_ptr          => try airRetPtr(f, inst),
            .assembly         => try airAsm(f, inst),
            .block            => try airBlock(f, inst),
            .bitcast          => try airBitcast(f, inst),
            .call             => try airCall(f, inst),
            .dbg_stmt         => try airDbgStmt(f, inst),
            .intcast          => try airIntCast(f, inst),
            .trunc            => try airTrunc(f, inst),
            .bool_to_int      => try airBoolToInt(f, inst),
            .load             => try airLoad(f, inst),
            .ret              => try airRet(f, inst),
            .ret_load         => try airRetLoad(f, inst),
            .store            => try airStore(f, inst),
            .loop             => try airLoop(f, inst),
            .cond_br          => try airCondBr(f, inst),
            .br               => try airBr(f, inst),
            .switch_br        => try airSwitchBr(f, inst),
            .wrap_optional    => try airWrapOptional(f, inst),
            .struct_field_ptr => try airStructFieldPtr(f, inst),
            .array_to_slice   => try airArrayToSlice(f, inst),
            .cmpxchg_weak     => try airCmpxchg(f, inst, "weak"),
            .cmpxchg_strong   => try airCmpxchg(f, inst, "strong"),
            .atomic_rmw       => try airAtomicRmw(f, inst),
            .atomic_load      => try airAtomicLoad(f, inst),
            .memset           => try airMemset(f, inst),
            .memcpy           => try airMemcpy(f, inst),
            .set_union_tag    => try airSetUnionTag(f, inst),
            .get_union_tag    => try airGetUnionTag(f, inst),
            .clz              => try airBuiltinCall(f, inst, "clz"),
            .ctz              => try airBuiltinCall(f, inst, "ctz"),
            .popcount         => try airBuiltinCall(f, inst, "popcount"),

            .int_to_float,
            .float_to_int,
            .fptrunc,
            .fpext,
            => try airSimpleCast(f, inst),

            .ptrtoint => try airPtrToInt(f, inst),

            .atomic_store_unordered => try airAtomicStore(f, inst, toMemoryOrder(.Unordered)),
            .atomic_store_monotonic => try airAtomicStore(f, inst, toMemoryOrder(.Monotonic)),
            .atomic_store_release   => try airAtomicStore(f, inst, toMemoryOrder(.Release)),
            .atomic_store_seq_cst   => try airAtomicStore(f, inst, toMemoryOrder(.SeqCst)),

            .struct_field_ptr_index_0 => try airStructFieldPtrIndex(f, inst, 0),
            .struct_field_ptr_index_1 => try airStructFieldPtrIndex(f, inst, 1),
            .struct_field_ptr_index_2 => try airStructFieldPtrIndex(f, inst, 2),
            .struct_field_ptr_index_3 => try airStructFieldPtrIndex(f, inst, 3),

            .struct_field_val => try airStructFieldVal(f, inst),
            .slice_ptr        => try airSliceField(f, inst, ".ptr;\n"),
            .slice_len        => try airSliceField(f, inst, ".len;\n"),

            .ptr_slice_len_ptr => try airPtrSliceFieldPtr(f, inst, ".len;\n"),
            .ptr_slice_ptr_ptr => try airPtrSliceFieldPtr(f, inst, ".ptr;\n"),

            .ptr_elem_val       => try airPtrElemVal(f, inst),
            .ptr_elem_ptr       => try airPtrElemPtr(f, inst),
            .slice_elem_val     => try airSliceElemVal(f, inst),
            .slice_elem_ptr     => try airSliceElemPtr(f, inst),
            .array_elem_val     => try airArrayElemVal(f, inst),

            .unwrap_errunion_payload     => try airUnwrapErrUnionPay(f, inst),
            .unwrap_errunion_err         => try airUnwrapErrUnionErr(f, inst),
            .unwrap_errunion_payload_ptr => try airUnwrapErrUnionPay(f, inst),
            .unwrap_errunion_err_ptr     => try airUnwrapErrUnionErr(f, inst),
            .wrap_errunion_payload       => try airWrapErrUnionPay(f, inst),
            .wrap_errunion_err           => try airWrapErrUnionErr(f, inst),
            // zig fmt: on
        };
        switch (result_value) {
            .none => {},
            else => try f.value_map.putNoClobber(inst, result_value),
        }
    }

    f.object.indent_writer.popIndent();
    try writer.writeAll("}");
}

fn airSliceField(f: *Function, inst: Air.Inst.Index, suffix: []const u8) !CValue {
    if (f.liveness.isUnused(inst)) return CValue.none;

    const inst_ty = f.air.typeOfIndex(inst);
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    const operand = try f.resolveInst(ty_op.operand);
    const writer = f.object.writer();
    const local = try f.allocLocal(inst_ty, .Const);
    try writer.writeAll(" = ");
    try f.writeCValue(writer, operand);
    try writer.writeAll(suffix);
    return local;
}

fn airPtrSliceFieldPtr(f: *Function, inst: Air.Inst.Index, suffix: []const u8) !CValue {
    if (f.liveness.isUnused(inst))
        return CValue.none;

    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    const operand = try f.resolveInst(ty_op.operand);
    const writer = f.object.writer();

    _ = writer;
    _ = operand;
    _ = suffix;

    return f.fail("TODO: C backend: airPtrSliceFieldPtr", .{});
}

fn airPtrElemVal(f: *Function, inst: Air.Inst.Index) !CValue {
    const bin_op = f.air.instructions.items(.data)[inst].bin_op;
    const ptr_ty = f.air.typeOf(bin_op.lhs);
    if (!ptr_ty.isVolatilePtr() and f.liveness.isUnused(inst)) return CValue.none;

    const ptr = try f.resolveInst(bin_op.lhs);
    const index = try f.resolveInst(bin_op.rhs);
    const writer = f.object.writer();
    const local = try f.allocLocal(f.air.typeOfIndex(inst), .Const);
    try writer.writeAll(" = ");
    try f.writeCValue(writer, ptr);
    try writer.writeByte('[');
    try f.writeCValue(writer, index);
    try writer.writeAll("];\n");
    return local;
}

fn airPtrElemPtr(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst)) return CValue.none;

    const ty_pl = f.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = f.air.extraData(Air.Bin, ty_pl.payload).data;

    const ptr = try f.resolveInst(bin_op.lhs);
    const index = try f.resolveInst(bin_op.rhs);
    const writer = f.object.writer();
    const local = try f.allocLocal(f.air.typeOfIndex(inst), .Const);
    try writer.writeAll(" = &");
    try f.writeCValue(writer, ptr);
    try writer.writeByte('[');
    try f.writeCValue(writer, index);
    try writer.writeAll("];\n");
    return local;
}

fn airSliceElemVal(f: *Function, inst: Air.Inst.Index) !CValue {
    const bin_op = f.air.instructions.items(.data)[inst].bin_op;
    const slice_ty = f.air.typeOf(bin_op.lhs);
    if (!slice_ty.isVolatilePtr() and f.liveness.isUnused(inst)) return CValue.none;

    const slice = try f.resolveInst(bin_op.lhs);
    const index = try f.resolveInst(bin_op.rhs);
    const writer = f.object.writer();
    const local = try f.allocLocal(f.air.typeOfIndex(inst), .Const);
    try writer.writeAll(" = ");
    try f.writeCValue(writer, slice);
    try writer.writeAll(".ptr[");
    try f.writeCValue(writer, index);
    try writer.writeAll("];\n");
    return local;
}

fn airSliceElemPtr(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst)) return CValue.none;

    const ty_pl = f.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = f.air.extraData(Air.Bin, ty_pl.payload).data;

    const slice = try f.resolveInst(bin_op.lhs);
    const index = try f.resolveInst(bin_op.rhs);
    const writer = f.object.writer();
    const local = try f.allocLocal(f.air.typeOfIndex(inst), .Const);
    try writer.writeAll(" = &");
    try f.writeCValue(writer, slice);
    try writer.writeAll(".ptr[");
    try f.writeCValue(writer, index);
    try writer.writeAll("];\n");
    return local;
}

fn airArrayElemVal(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst)) return CValue.none;

    const bin_op = f.air.instructions.items(.data)[inst].bin_op;
    const array = try f.resolveInst(bin_op.lhs);
    const index = try f.resolveInst(bin_op.rhs);
    const writer = f.object.writer();
    const local = try f.allocLocal(f.air.typeOfIndex(inst), .Const);
    try writer.writeAll(" = ");
    try f.writeCValue(writer, array);
    try writer.writeAll("[");
    try f.writeCValue(writer, index);
    try writer.writeAll("];\n");
    return local;
}

fn airAlloc(f: *Function, inst: Air.Inst.Index) !CValue {
    const writer = f.object.writer();
    const inst_ty = f.air.typeOfIndex(inst);

    // First line: the variable used as data storage.
    const elem_type = inst_ty.elemType();
    const mutability: Mutability = if (inst_ty.isConstPtr()) .Const else .Mut;
    const local = try f.allocLocal(elem_type, mutability);
    try writer.writeAll(";\n");

    // Arrays are already pointers so they don't need to be referenced.
    if (elem_type.zigTypeTag() == .Array)
        return CValue{ .local = local.local };

    return CValue{ .local_ref = local.local };
}

fn airRetPtr(f: *Function, inst: Air.Inst.Index) !CValue {
    const writer = f.object.writer();
    const inst_ty = f.air.typeOfIndex(inst);

    // First line: the variable used as data storage.
    const elem_type = inst_ty.elemType();
    const local = try f.allocLocal(elem_type, .Mut);
    try writer.writeAll(";\n");

    return CValue{ .local_ref = local.local };
}

fn airArg(f: *Function) CValue {
    const i = f.next_arg_index;
    f.next_arg_index += 1;
    return .{ .arg = i };
}

fn airLoad(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    const is_volatile = f.air.typeOf(ty_op.operand).isVolatilePtr();
    if (!is_volatile and f.liveness.isUnused(inst))
        return CValue.none;
    const inst_ty = f.air.typeOfIndex(inst);
    if (inst_ty.zigTypeTag() == .Array)
        return f.fail("TODO: C backend: implement airLoad for arrays", .{});
    const operand = try f.resolveInst(ty_op.operand);
    const writer = f.object.writer();
    const local = try f.allocLocal(inst_ty, .Const);
    switch (operand) {
        .local_ref => |i| {
            const wrapped: CValue = .{ .local = i };
            try writer.writeAll(" = ");
            try f.writeCValue(writer, wrapped);
            try writer.writeAll(";\n");
        },
        .decl_ref => |decl| {
            const wrapped: CValue = .{ .decl = decl };
            try writer.writeAll(" = ");
            try f.writeCValue(writer, wrapped);
            try writer.writeAll(";\n");
        },
        else => {
            try writer.writeAll(" = *");
            try f.writeCValue(writer, operand);
            try writer.writeAll(";\n");
        },
    }
    return local;
}

fn airRet(f: *Function, inst: Air.Inst.Index) !CValue {
    const un_op = f.air.instructions.items(.data)[inst].un_op;
    const writer = f.object.writer();
    if (f.air.typeOf(un_op).hasCodeGenBits()) {
        const operand = try f.resolveInst(un_op);
        try writer.writeAll("return ");
        try f.writeCValue(writer, operand);
        try writer.writeAll(";\n");
    } else {
        try writer.writeAll("return;\n");
    }
    return CValue.none;
}

fn airRetLoad(f: *Function, inst: Air.Inst.Index) !CValue {
    const un_op = f.air.instructions.items(.data)[inst].un_op;
    const writer = f.object.writer();
    const ptr_ty = f.air.typeOf(un_op);
    const ret_ty = ptr_ty.childType();
    if (!ret_ty.hasCodeGenBits()) {
        try writer.writeAll("return;\n");
    }
    const ptr = try f.resolveInst(un_op);
    try writer.writeAll("return *");
    try f.writeCValue(writer, ptr);
    try writer.writeAll(";\n");
    return CValue.none;
}

fn airIntCast(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst))
        return CValue.none;

    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    const operand = try f.resolveInst(ty_op.operand);

    const writer = f.object.writer();
    const inst_ty = f.air.typeOfIndex(inst);
    const local = try f.allocLocal(inst_ty, .Const);
    try writer.writeAll(" = (");
    try f.renderType(writer, inst_ty);
    try writer.writeAll(")");
    try f.writeCValue(writer, operand);
    try writer.writeAll(";\n");
    return local;
}

fn airTrunc(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst)) return CValue.none;

    const inst_ty = f.air.typeOfIndex(inst);
    const local = try f.allocLocal(inst_ty, .Const);
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    const writer = f.object.writer();
    const operand = try f.resolveInst(ty_op.operand);
    const target = f.object.dg.module.getTarget();
    const dest_int_info = inst_ty.intInfo(target);
    const dest_bits = dest_int_info.bits;

    try writer.writeAll(" = ");

    if (dest_bits >= 8 and std.math.isPowerOfTwo(dest_bits)) {
        try f.writeCValue(writer, operand);
        try writer.writeAll(";\n");
        return local;
    }

    switch (dest_int_info.signedness) {
        .unsigned => {
            try f.writeCValue(writer, operand);
            const mask = (@as(u65, 1) << @intCast(u7, dest_bits)) - 1;
            try writer.print(" & {d}ULL;\n", .{mask});
            return local;
        },
        .signed => {
            const operand_ty = f.air.typeOf(ty_op.operand);
            const c_bits = toCIntBits(operand_ty.intInfo(target).bits) orelse
                return f.fail("TODO: C backend: implement integer types larger than 128 bits", .{});
            const shift_rhs = c_bits - dest_bits;
            try writer.print("(int{d}_t)((uint{d}_t)", .{ c_bits, c_bits });
            try f.writeCValue(writer, operand);
            try writer.print(" << {d}) >> {d};\n", .{ shift_rhs, shift_rhs });
            return local;
        },
    }
}

fn airBoolToInt(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst))
        return CValue.none;
    const un_op = f.air.instructions.items(.data)[inst].un_op;
    const writer = f.object.writer();
    const inst_ty = f.air.typeOfIndex(inst);
    const operand = try f.resolveInst(un_op);
    const local = try f.allocLocal(inst_ty, .Const);
    try writer.writeAll(" = ");
    try f.writeCValue(writer, operand);
    try writer.writeAll(";\n");
    return local;
}

fn airStoreUndefined(f: *Function, dest_ptr: CValue, dest_type: Type) !CValue {
    const is_debug_build = f.object.dg.module.optimizeMode() == .Debug;
    if (!is_debug_build)
        return CValue.none;

    const writer = f.object.writer();
    switch (dest_ptr) {
        .local_ref => |i| {
            const dest: CValue = .{ .local = i };
            try writer.writeAll("memset(&");
            try f.writeCValue(writer, dest);
            try writer.writeAll(", 0xaa, sizeof(");
            try f.writeCValue(writer, dest);
            try writer.writeAll("));\n");
        },
        .decl_ref => |decl| {
            const dest: CValue = .{ .decl = decl };
            try writer.writeAll("memset(&");
            try f.writeCValue(writer, dest);
            try writer.writeAll(", 0xaa, sizeof(");
            try f.writeCValue(writer, dest);
            try writer.writeAll("));\n");
        },
        else => {
            const indirection = if (dest_type.childType().zigTypeTag() == .Array) "" else "*";

            try writer.writeAll("memset(");
            try f.writeCValue(writer, dest_ptr);
            try writer.print(", 0xaa, sizeof({s}", .{indirection});
            try f.writeCValue(writer, dest_ptr);
            try writer.writeAll("));\n");
        },
    }
    return CValue.none;
}

fn airStore(f: *Function, inst: Air.Inst.Index) !CValue {
    // *a = b;
    const bin_op = f.air.instructions.items(.data)[inst].bin_op;
    const dest_ptr = try f.resolveInst(bin_op.lhs);
    const src_val = try f.resolveInst(bin_op.rhs);
    const lhs_type = f.air.typeOf(bin_op.lhs);

    // TODO Sema should emit a different instruction when the store should
    // possibly do the safety 0xaa bytes for undefined.
    const src_val_is_undefined =
        if (f.air.value(bin_op.rhs)) |v| v.isUndefDeep() else false;
    if (src_val_is_undefined)
        return try airStoreUndefined(f, dest_ptr, lhs_type);

    // Don't check this for airStoreUndefined as that will work for arrays already
    if (lhs_type.childType().zigTypeTag() == .Array)
        return f.fail("TODO: C backend: implement airStore for arrays", .{});

    const writer = f.object.writer();
    switch (dest_ptr) {
        .local_ref => |i| {
            const dest: CValue = .{ .local = i };
            try f.writeCValue(writer, dest);
            try writer.writeAll(" = ");
            try f.writeCValue(writer, src_val);
            try writer.writeAll(";\n");
        },
        .decl_ref => |decl| {
            const dest: CValue = .{ .decl = decl };
            try f.writeCValue(writer, dest);
            try writer.writeAll(" = ");
            try f.writeCValue(writer, src_val);
            try writer.writeAll(";\n");
        },
        else => {
            try writer.writeAll("*");
            try f.writeCValue(writer, dest_ptr);
            try writer.writeAll(" = ");
            try f.writeCValue(writer, src_val);
            try writer.writeAll(";\n");
        },
    }
    return CValue.none;
}

fn airWrapOp(
    f: *Function,
    inst: Air.Inst.Index,
    str_op: [*:0]const u8,
    fn_op: [*:0]const u8,
) !CValue {
    if (f.liveness.isUnused(inst))
        return CValue.none;

    const bin_op = f.air.instructions.items(.data)[inst].bin_op;
    const inst_ty = f.air.typeOfIndex(inst);
    const int_info = inst_ty.intInfo(f.object.dg.module.getTarget());
    const bits = int_info.bits;

    // if it's an unsigned int with non-arbitrary bit size then we can just add
    if (int_info.signedness == .unsigned) {
        const ok_bits = switch (bits) {
            8, 16, 32, 64, 128 => true,
            else => false,
        };
        if (ok_bits or inst_ty.tag() != .int_unsigned) {
            return try airBinOp(f, inst, str_op);
        }
    }

    if (bits > 64) {
        return f.fail("TODO: C backend: airWrapOp for large integers", .{});
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

    const lhs = try f.resolveInst(bin_op.lhs);
    const rhs = try f.resolveInst(bin_op.rhs);
    const w = f.object.writer();

    const ret = try f.allocLocal(inst_ty, .Mut);
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
    try f.writeCValue(w, lhs);
    try w.writeAll(", ");
    try f.writeCValue(w, rhs);

    if (int_info.signedness == .signed) {
        try w.print(", {s}", .{min});
    }

    try w.print(", {s});", .{max});
    try f.object.indent_writer.insertNewline();

    return ret;
}

fn airSatOp(f: *Function, inst: Air.Inst.Index, fn_op: [*:0]const u8) !CValue {
    if (f.liveness.isUnused(inst))
        return CValue.none;

    const bin_op = f.air.instructions.items(.data)[inst].bin_op;
    const inst_ty = f.air.typeOfIndex(inst);
    const int_info = inst_ty.intInfo(f.object.dg.module.getTarget());
    const bits = int_info.bits;

    switch (bits) {
        8, 16, 32, 64, 128 => {},
        else => return f.object.dg.fail("TODO: C backend: airSatOp for non power of 2 integers", .{}),
    }

    // if it's an unsigned int with non-arbitrary bit size then we can just add
    if (bits > 64) {
        return f.object.dg.fail("TODO: C backend: airSatOp for large integers", .{});
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
                // compute the type minimum based on the bitcount (bits)
                const val = -1 * std.math.pow(i65, 2, @intCast(i65, bits - 1));
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
            const val = std.math.pow(u65, 2, pow_bits) - 1;
            break :blk std.fmt.bufPrint(&max_buf, "{}", .{val}) catch |err| switch (err) {
                error.NoSpaceLeft => unreachable,
                else => |e| return e,
            };
        },
    };

    const lhs = try f.resolveInst(bin_op.lhs);
    const rhs = try f.resolveInst(bin_op.rhs);
    const w = f.object.writer();

    const ret = try f.allocLocal(inst_ty, .Mut);
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
    try f.writeCValue(w, lhs);
    try w.writeAll(", ");
    try f.writeCValue(w, rhs);

    if (int_info.signedness == .signed) {
        try w.print(", {s}", .{min});
    }

    try w.print(", {s});", .{max});
    try f.object.indent_writer.insertNewline();

    return ret;
}

fn airNot(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst))
        return CValue.none;

    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    const op = try f.resolveInst(ty_op.operand);

    const writer = f.object.writer();
    const inst_ty = f.air.typeOfIndex(inst);
    const local = try f.allocLocal(inst_ty, .Const);

    try writer.writeAll(" = ");
    if (inst_ty.zigTypeTag() == .Bool)
        try writer.writeAll("!")
    else
        try writer.writeAll("~");
    try f.writeCValue(writer, op);
    try writer.writeAll(";\n");

    return local;
}

fn airBinOp(f: *Function, inst: Air.Inst.Index, operator: [*:0]const u8) !CValue {
    if (f.liveness.isUnused(inst))
        return CValue.none;

    const bin_op = f.air.instructions.items(.data)[inst].bin_op;
    const lhs = try f.resolveInst(bin_op.lhs);
    const rhs = try f.resolveInst(bin_op.rhs);

    const writer = f.object.writer();
    const inst_ty = f.air.typeOfIndex(inst);
    const local = try f.allocLocal(inst_ty, .Const);

    try writer.writeAll(" = ");
    try f.writeCValue(writer, lhs);
    try writer.print("{s}", .{operator});
    try f.writeCValue(writer, rhs);
    try writer.writeAll(";\n");

    return local;
}

fn airPtrAddSub(f: *Function, inst: Air.Inst.Index, operator: [*:0]const u8) !CValue {
    if (f.liveness.isUnused(inst))
        return CValue.none;

    const bin_op = f.air.instructions.items(.data)[inst].bin_op;
    const lhs = try f.resolveInst(bin_op.lhs);
    const rhs = try f.resolveInst(bin_op.rhs);

    const writer = f.object.writer();
    const inst_ty = f.air.typeOfIndex(inst);
    const local = try f.allocLocal(inst_ty, .Const);

    // We must convert to and from integer types to prevent UB if the operation results in a NULL pointer,
    // or if LHS is NULL. The operation is only UB if the result is NULL and then dereferenced.
    try writer.writeAll(" = (");
    try f.renderType(writer, inst_ty);
    try writer.writeAll(")(((uintptr_t)");
    try f.writeCValue(writer, lhs);
    try writer.print("){s}(", .{operator});
    try f.writeCValue(writer, rhs);
    try writer.writeAll("*sizeof(");
    try f.renderType(writer, inst_ty.childType());
    try writer.print(")));\n", .{});

    return local;
}

fn airMinMax(f: *Function, inst: Air.Inst.Index, operator: [*:0]const u8) !CValue {
    if (f.liveness.isUnused(inst)) return CValue.none;

    const bin_op = f.air.instructions.items(.data)[inst].bin_op;
    const lhs = try f.resolveInst(bin_op.lhs);
    const rhs = try f.resolveInst(bin_op.rhs);

    const writer = f.object.writer();
    const inst_ty = f.air.typeOfIndex(inst);
    const local = try f.allocLocal(inst_ty, .Const);

    // (lhs <> rhs) ? lhs : rhs
    try writer.writeAll(" = (");
    try f.writeCValue(writer, lhs);
    try writer.print("{s}", .{operator});
    try f.writeCValue(writer, rhs);
    try writer.writeAll(") ");
    try f.writeCValue(writer, lhs);
    try writer.writeAll(" : ");
    try f.writeCValue(writer, rhs);
    try writer.writeAll(";\n");

    return local;
}

fn airSlice(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst)) return CValue.none;

    const ty_pl = f.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = f.air.extraData(Air.Bin, ty_pl.payload).data;
    const ptr = try f.resolveInst(bin_op.lhs);
    const len = try f.resolveInst(bin_op.rhs);

    const writer = f.object.writer();
    const inst_ty = f.air.typeOfIndex(inst);
    const local = try f.allocLocal(inst_ty, .Const);

    try writer.writeAll(" = {");
    try f.writeCValue(writer, ptr);
    try writer.writeAll(", ");
    try f.writeCValue(writer, len);
    try writer.writeAll("};\n");

    return local;
}

fn airCall(f: *Function, inst: Air.Inst.Index) !CValue {
    const pl_op = f.air.instructions.items(.data)[inst].pl_op;
    const extra = f.air.extraData(Air.Call, pl_op.payload);
    const args = @bitCast([]const Air.Inst.Ref, f.air.extra[extra.end..][0..extra.data.args_len]);
    const callee_ty = f.air.typeOf(pl_op.operand);
    const fn_ty = switch (callee_ty.zigTypeTag()) {
        .Fn => callee_ty,
        .Pointer => callee_ty.childType(),
        else => unreachable,
    };
    const ret_ty = fn_ty.fnReturnType();
    const unused_result = f.liveness.isUnused(inst);
    const writer = f.object.writer();

    var result_local: CValue = .none;
    if (unused_result) {
        if (ret_ty.hasCodeGenBits()) {
            try writer.print("(void)", .{});
        }
    } else {
        result_local = try f.allocLocal(ret_ty, .Const);
        try writer.writeAll(" = ");
    }

    callee: {
        known: {
            const fn_decl = fn_decl: {
                const callee_val = f.air.value(pl_op.operand) orelse break :known;
                break :fn_decl switch (callee_val.tag()) {
                    .extern_fn => callee_val.castTag(.extern_fn).?.data,
                    .function => callee_val.castTag(.function).?.data.owner_decl,
                    .decl_ref => callee_val.castTag(.decl_ref).?.data,
                    else => break :known,
                };
            };
            try f.object.dg.renderDeclName(fn_decl, writer);
            break :callee;
        }
        // Fall back to function pointer call.
        const callee = try f.resolveInst(pl_op.operand);
        try f.writeCValue(writer, callee);
    }

    try writer.writeAll("(");
    for (args) |arg, i| {
        if (i != 0) {
            try writer.writeAll(", ");
        }
        if (f.air.value(arg)) |val| {
            try f.object.dg.renderValue(writer, f.air.typeOf(arg), val);
        } else {
            const val = try f.resolveInst(arg);
            try f.writeCValue(writer, val);
        }
    }
    try writer.writeAll(");\n");
    return result_local;
}

fn airDbgStmt(f: *Function, inst: Air.Inst.Index) !CValue {
    const dbg_stmt = f.air.instructions.items(.data)[inst].dbg_stmt;
    const writer = f.object.writer();
    try writer.print("#line {d}\n", .{dbg_stmt.line + 1});
    return CValue.none;
}

fn airBlock(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_pl = f.air.instructions.items(.data)[inst].ty_pl;
    const extra = f.air.extraData(Air.Block, ty_pl.payload);
    const body = f.air.extra[extra.end..][0..extra.data.body_len];

    const block_id: usize = f.next_block_index;
    f.next_block_index += 1;
    const writer = f.object.writer();

    const inst_ty = f.air.typeOfIndex(inst);
    const result = if (inst_ty.tag() != .void and !f.liveness.isUnused(inst)) blk: {
        // allocate a location for the result
        const local = try f.allocLocal(inst_ty, .Mut);
        try writer.writeAll(";\n");
        break :blk local;
    } else CValue{ .none = {} };

    try f.blocks.putNoClobber(f.object.dg.gpa, inst, .{
        .block_id = block_id,
        .result = result,
    });

    try genBody(f, body);
    try f.object.indent_writer.insertNewline();
    // label must be followed by an expression, add an empty one.
    try writer.print("zig_block_{d}:;\n", .{block_id});
    return result;
}

fn airBr(f: *Function, inst: Air.Inst.Index) !CValue {
    const branch = f.air.instructions.items(.data)[inst].br;
    const block = f.blocks.get(branch.block_inst).?;
    const result = block.result;
    const writer = f.object.writer();

    // If result is .none then the value of the block is unused.
    if (result != .none) {
        const operand = try f.resolveInst(branch.operand);
        try f.writeCValue(writer, result);
        try writer.writeAll(" = ");
        try f.writeCValue(writer, operand);
        try writer.writeAll(";\n");
    }

    try f.object.writer().print("goto zig_block_{d};\n", .{block.block_id});
    return CValue.none;
}

fn airBitcast(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst))
        return CValue.none;

    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    const operand = try f.resolveInst(ty_op.operand);

    const writer = f.object.writer();
    const inst_ty = f.air.typeOfIndex(inst);
    if (inst_ty.zigTypeTag() == .Pointer and
        f.air.typeOf(ty_op.operand).zigTypeTag() == .Pointer)
    {
        const local = try f.allocLocal(inst_ty, .Const);
        try writer.writeAll(" = (");
        try f.renderType(writer, inst_ty);

        try writer.writeAll(")");
        try f.writeCValue(writer, operand);
        try writer.writeAll(";\n");
        return local;
    }

    const local = try f.allocLocal(inst_ty, .Mut);
    try writer.writeAll(";\n");

    try writer.writeAll("memcpy(&");
    try f.writeCValue(writer, local);
    try writer.writeAll(", &");
    try f.writeCValue(writer, operand);
    try writer.writeAll(", sizeof ");
    try f.writeCValue(writer, local);
    try writer.writeAll(");\n");

    return local;
}

fn airBreakpoint(f: *Function) !CValue {
    try f.object.writer().writeAll("zig_breakpoint();\n");
    return CValue.none;
}

fn airFence(f: *Function, inst: Air.Inst.Index) !CValue {
    const atomic_order = f.air.instructions.items(.data)[inst].fence;
    const writer = f.object.writer();

    try writer.writeAll("zig_fence(");
    try writeMemoryOrder(writer, atomic_order);
    try writer.writeAll(");\n");

    return CValue.none;
}

fn airUnreach(f: *Function) !CValue {
    try f.object.writer().writeAll("zig_unreachable();\n");
    return CValue.none;
}

fn airLoop(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_pl = f.air.instructions.items(.data)[inst].ty_pl;
    const loop = f.air.extraData(Air.Block, ty_pl.payload);
    const body = f.air.extra[loop.end..][0..loop.data.body_len];
    try f.object.writer().writeAll("while (true) ");
    try genBody(f, body);
    try f.object.indent_writer.insertNewline();
    return CValue.none;
}

fn airCondBr(f: *Function, inst: Air.Inst.Index) !CValue {
    const pl_op = f.air.instructions.items(.data)[inst].pl_op;
    const cond = try f.resolveInst(pl_op.operand);
    const extra = f.air.extraData(Air.CondBr, pl_op.payload);
    const then_body = f.air.extra[extra.end..][0..extra.data.then_body_len];
    const else_body = f.air.extra[extra.end + then_body.len ..][0..extra.data.else_body_len];
    const writer = f.object.writer();

    try writer.writeAll("if (");
    try f.writeCValue(writer, cond);
    try writer.writeAll(") ");
    try genBody(f, then_body);
    try writer.writeAll(" else ");
    try genBody(f, else_body);
    try f.object.indent_writer.insertNewline();

    return CValue.none;
}

fn airSwitchBr(f: *Function, inst: Air.Inst.Index) !CValue {
    const pl_op = f.air.instructions.items(.data)[inst].pl_op;
    const condition = try f.resolveInst(pl_op.operand);
    const condition_ty = f.air.typeOf(pl_op.operand);
    const switch_br = f.air.extraData(Air.SwitchBr, pl_op.payload);
    const writer = f.object.writer();

    try writer.writeAll("switch (");
    try f.writeCValue(writer, condition);
    try writer.writeAll(") {");
    f.object.indent_writer.pushIndent();

    var extra_index: usize = switch_br.end;
    var case_i: u32 = 0;
    while (case_i < switch_br.data.cases_len) : (case_i += 1) {
        const case = f.air.extraData(Air.SwitchBr.Case, extra_index);
        const items = @bitCast([]const Air.Inst.Ref, f.air.extra[case.end..][0..case.data.items_len]);
        const case_body = f.air.extra[case.end + items.len ..][0..case.data.body_len];
        extra_index = case.end + case.data.items_len + case_body.len;

        for (items) |item| {
            try f.object.indent_writer.insertNewline();
            try writer.writeAll("case ");
            try f.object.dg.renderValue(writer, condition_ty, f.air.value(item).?);
            try writer.writeAll(": ");
        }
        // The case body must be noreturn so we don't need to insert a break.
        try genBody(f, case_body);
    }

    const else_body = f.air.extra[extra_index..][0..switch_br.data.else_body_len];
    try f.object.indent_writer.insertNewline();
    try writer.writeAll("default: ");
    try genBody(f, else_body);
    try f.object.indent_writer.insertNewline();

    f.object.indent_writer.popIndent();
    try writer.writeAll("}\n");
    return CValue.none;
}

fn airAsm(f: *Function, inst: Air.Inst.Index) !CValue {
    const air_datas = f.air.instructions.items(.data);
    const air_extra = f.air.extraData(Air.Asm, air_datas[inst].ty_pl.payload);
    const zir = f.object.dg.decl.getFileScope().zir;
    const extended = zir.instructions.items(.data)[air_extra.data.zir_index].extended;
    const zir_extra = zir.extraData(Zir.Inst.Asm, extended.operand);
    const asm_source = zir.nullTerminatedString(zir_extra.data.asm_source);
    const outputs_len = @truncate(u5, extended.small);
    const args_len = @truncate(u5, extended.small >> 5);
    const clobbers_len = @truncate(u5, extended.small >> 10);
    _ = clobbers_len; // TODO honor these
    const is_volatile = @truncate(u1, extended.small >> 15) != 0;
    const outputs = @bitCast([]const Air.Inst.Ref, f.air.extra[air_extra.end..][0..outputs_len]);
    const args = @bitCast([]const Air.Inst.Ref, f.air.extra[air_extra.end + outputs.len ..][0..args_len]);

    if (outputs_len > 1) {
        return f.fail("TODO implement codegen for asm with more than 1 output", .{});
    }

    if (f.liveness.isUnused(inst) and !is_volatile)
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

    const writer = f.object.writer();
    for (args) |arg| {
        const input = zir.extraData(Zir.Inst.Asm.Input, extra_i);
        extra_i = input.end;
        const constraint = zir.nullTerminatedString(input.data.constraint);
        if (constraint[0] == '{' and constraint[constraint.len - 1] == '}') {
            const reg = constraint[1 .. constraint.len - 1];
            const arg_c_value = try f.resolveInst(arg);
            try writer.writeAll("register ");
            try f.renderType(writer, f.air.typeOf(arg));

            try writer.print(" {s}_constant __asm__(\"{s}\") = ", .{ reg, reg });
            try f.writeCValue(writer, arg_c_value);
            try writer.writeAll(";\n");
        } else {
            return f.fail("TODO non-explicit inline asm regs", .{});
        }
    }
    const volatile_string: []const u8 = if (is_volatile) "volatile " else "";
    try writer.print("__asm {s}(\"{s}\"", .{ volatile_string, asm_source });
    if (output_constraint) |_| {
        return f.fail("TODO: CBE inline asm output", .{});
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

    if (f.liveness.isUnused(inst))
        return CValue.none;

    return f.fail("TODO: C backend: inline asm expression result used", .{});
}

fn airIsNull(
    f: *Function,
    inst: Air.Inst.Index,
    operator: [*:0]const u8,
    deref_suffix: [*:0]const u8,
) !CValue {
    if (f.liveness.isUnused(inst))
        return CValue.none;

    const un_op = f.air.instructions.items(.data)[inst].un_op;
    const writer = f.object.writer();
    const operand = try f.resolveInst(un_op);
    const target = f.object.dg.module.getTarget();

    const local = try f.allocLocal(Type.initTag(.bool), .Const);
    try writer.writeAll(" = (");
    try f.writeCValue(writer, operand);

    const ty = f.air.typeOf(un_op);
    var opt_buf: Type.Payload.ElemType = undefined;
    const payload_type = if (ty.zigTypeTag() == .Pointer)
        ty.childType().optionalChild(&opt_buf)
    else
        ty.optionalChild(&opt_buf);

    if (ty.isPtrLikeOptional()) {
        // operand is a regular pointer, test `operand !=/== NULL`
        try writer.print("){s} {s} NULL;\n", .{ deref_suffix, operator });
    } else if (payload_type.abiSize(target) == 0) {
        try writer.print("){s} {s} true;\n", .{ deref_suffix, operator });
    } else {
        try writer.print("){s}.is_null {s} true;\n", .{ deref_suffix, operator });
    }
    return local;
}

fn airOptionalPayload(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst))
        return CValue.none;

    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    const writer = f.object.writer();
    const operand = try f.resolveInst(ty_op.operand);
    const operand_ty = f.air.typeOf(ty_op.operand);

    const opt_ty = if (operand_ty.zigTypeTag() == .Pointer)
        operand_ty.elemType()
    else
        operand_ty;

    if (opt_ty.isPtrLikeOptional()) {
        // the operand is just a regular pointer, no need to do anything special.
        // *?*T -> **T and ?*T -> *T are **T -> **T and *T -> *T in C
        return operand;
    }

    const inst_ty = f.air.typeOfIndex(inst);
    const maybe_deref = if (operand_ty.zigTypeTag() == .Pointer) "->" else ".";
    const maybe_addrof = if (inst_ty.zigTypeTag() == .Pointer) "&" else "";

    const local = try f.allocLocal(inst_ty, .Const);
    try writer.print(" = {s}(", .{maybe_addrof});
    try f.writeCValue(writer, operand);

    try writer.print("){s}payload;\n", .{maybe_deref});
    return local;
}

fn airOptionalPayloadPtrSet(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    const writer = f.object.writer();
    const operand = try f.resolveInst(ty_op.operand);
    const operand_ty = f.air.typeOf(ty_op.operand);

    const opt_ty = operand_ty.elemType();

    if (opt_ty.isPtrLikeOptional()) {
        // The payload and the optional are the same value.
        // Setting to non-null will be done when the payload is set.
        return operand;
    }

    try writer.writeAll("(");
    try f.writeCValue(writer, operand);
    try writer.writeAll(")->is_null = false;\n");

    const inst_ty = f.air.typeOfIndex(inst);
    const local = try f.allocLocal(inst_ty, .Const);
    try writer.writeAll(" = &(");
    try f.writeCValue(writer, operand);

    try writer.writeAll(")->payload;\n");
    return local;
}

fn airStructFieldPtr(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst))
        // TODO this @as is needed because of a stage1 bug
        return @as(CValue, CValue.none);

    const ty_pl = f.air.instructions.items(.data)[inst].ty_pl;
    const extra = f.air.extraData(Air.StructField, ty_pl.payload).data;
    const struct_ptr = try f.resolveInst(extra.struct_operand);
    const struct_ptr_ty = f.air.typeOf(extra.struct_operand);
    return structFieldPtr(f, inst, struct_ptr_ty, struct_ptr, extra.field_index);
}

fn airStructFieldPtrIndex(f: *Function, inst: Air.Inst.Index, index: u8) !CValue {
    if (f.liveness.isUnused(inst))
        // TODO this @as is needed because of a stage1 bug
        return @as(CValue, CValue.none);

    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    const struct_ptr = try f.resolveInst(ty_op.operand);
    const struct_ptr_ty = f.air.typeOf(ty_op.operand);
    return structFieldPtr(f, inst, struct_ptr_ty, struct_ptr, index);
}

fn structFieldPtr(f: *Function, inst: Air.Inst.Index, struct_ptr_ty: Type, struct_ptr: CValue, index: u32) !CValue {
    const writer = f.object.writer();
    const struct_obj = struct_ptr_ty.elemType().castTag(.@"struct").?.data;
    const field_name = struct_obj.fields.keys()[index];
    const field_val = struct_obj.fields.values()[index];
    const addrof = if (field_val.ty.zigTypeTag() == .Array) "" else "&";

    const inst_ty = f.air.typeOfIndex(inst);
    const local = try f.allocLocal(inst_ty, .Const);
    switch (struct_ptr) {
        .local_ref => |i| {
            try writer.print(" = {s}t{d}.{};\n", .{ addrof, i, fmtIdent(field_name) });
        },
        else => {
            try writer.print(" = {s}", .{addrof});
            try f.writeCValue(writer, struct_ptr);
            try writer.print("->{};\n", .{fmtIdent(field_name)});
        },
    }
    return local;
}

fn airStructFieldVal(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst))
        return CValue.none;

    const ty_pl = f.air.instructions.items(.data)[inst].ty_pl;
    const extra = f.air.extraData(Air.StructField, ty_pl.payload).data;
    const writer = f.object.writer();
    const struct_byval = try f.resolveInst(extra.struct_operand);
    const struct_ty = f.air.typeOf(extra.struct_operand);
    const struct_obj = struct_ty.castTag(.@"struct").?.data;
    const field_name = struct_obj.fields.keys()[extra.field_index];

    const inst_ty = f.air.typeOfIndex(inst);
    const local = try f.allocLocal(inst_ty, .Const);
    try writer.writeAll(" = ");
    try f.writeCValue(writer, struct_byval);
    try writer.print(".{};\n", .{fmtIdent(field_name)});
    return local;
}

// *(E!T) -> E NOT *E
fn airUnwrapErrUnionErr(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst))
        return CValue.none;

    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    const inst_ty = f.air.typeOfIndex(inst);
    const writer = f.object.writer();
    const operand = try f.resolveInst(ty_op.operand);
    const operand_ty = f.air.typeOf(ty_op.operand);

    const payload_ty = operand_ty.errorUnionPayload();
    if (!payload_ty.hasCodeGenBits()) {
        if (operand_ty.zigTypeTag() == .Pointer) {
            const local = try f.allocLocal(inst_ty, .Const);
            try writer.writeAll(" = *");
            try f.writeCValue(writer, operand);
            try writer.writeAll(";\n");
            return local;
        } else {
            return operand;
        }
    }

    const maybe_deref = if (operand_ty.zigTypeTag() == .Pointer) "->" else ".";

    const local = try f.allocLocal(inst_ty, .Const);
    try writer.writeAll(" = (");
    try f.writeCValue(writer, operand);

    try writer.print("){s}error;\n", .{maybe_deref});
    return local;
}

fn airUnwrapErrUnionPay(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst))
        return CValue.none;

    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    const writer = f.object.writer();
    const operand = try f.resolveInst(ty_op.operand);
    const operand_ty = f.air.typeOf(ty_op.operand);

    const payload_ty = operand_ty.errorUnionPayload();
    if (!payload_ty.hasCodeGenBits()) {
        return CValue.none;
    }

    const inst_ty = f.air.typeOfIndex(inst);
    const maybe_deref = if (operand_ty.zigTypeTag() == .Pointer) "->" else ".";
    const maybe_addrof = if (inst_ty.zigTypeTag() == .Pointer) "&" else "";

    const local = try f.allocLocal(inst_ty, .Const);
    try writer.print(" = {s}(", .{maybe_addrof});
    try f.writeCValue(writer, operand);

    try writer.print("){s}payload;\n", .{maybe_deref});
    return local;
}

fn airWrapOptional(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst))
        return CValue.none;

    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    const writer = f.object.writer();
    const operand = try f.resolveInst(ty_op.operand);

    const inst_ty = f.air.typeOfIndex(inst);
    if (inst_ty.isPtrLikeOptional()) {
        // the operand is just a regular pointer, no need to do anything special.
        return operand;
    }

    // .wrap_optional is used to convert non-optionals into optionals so it can never be null.
    const local = try f.allocLocal(inst_ty, .Const);
    try writer.writeAll(" = { .is_null = false, .payload =");
    try f.writeCValue(writer, operand);
    try writer.writeAll("};\n");
    return local;
}
fn airWrapErrUnionErr(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst)) return CValue.none;

    const writer = f.object.writer();
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    const operand = try f.resolveInst(ty_op.operand);
    const err_un_ty = f.air.typeOfIndex(inst);
    const payload_ty = err_un_ty.errorUnionPayload();
    if (!payload_ty.hasCodeGenBits()) {
        return operand;
    }

    const local = try f.allocLocal(err_un_ty, .Const);
    try writer.writeAll(" = { .error = ");
    try f.writeCValue(writer, operand);
    try writer.writeAll(" };\n");
    return local;
}

fn airWrapErrUnionPay(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst))
        return CValue.none;

    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    const writer = f.object.writer();
    const operand = try f.resolveInst(ty_op.operand);

    const inst_ty = f.air.typeOfIndex(inst);
    const local = try f.allocLocal(inst_ty, .Const);
    try writer.writeAll(" = { .error = 0, .payload = ");
    try f.writeCValue(writer, operand);
    try writer.writeAll(" };\n");
    return local;
}

fn airIsErr(
    f: *Function,
    inst: Air.Inst.Index,
    deref_prefix: [*:0]const u8,
    deref_suffix: [*:0]const u8,
    op_str: [*:0]const u8,
) !CValue {
    if (f.liveness.isUnused(inst))
        return CValue.none;

    const un_op = f.air.instructions.items(.data)[inst].un_op;
    const writer = f.object.writer();
    const operand = try f.resolveInst(un_op);
    const operand_ty = f.air.typeOf(un_op);
    const local = try f.allocLocal(Type.initTag(.bool), .Const);
    const payload_ty = operand_ty.errorUnionPayload();
    if (!payload_ty.hasCodeGenBits()) {
        try writer.print(" = {s}", .{deref_prefix});
        try f.writeCValue(writer, operand);
        try writer.print(" {s} 0;\n", .{op_str});
    } else {
        try writer.writeAll(" = ");
        try f.writeCValue(writer, operand);
        try writer.print("{s}error {s} 0;\n", .{ deref_suffix, op_str });
    }
    return local;
}

fn airArrayToSlice(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst))
        return CValue.none;

    const inst_ty = f.air.typeOfIndex(inst);
    const local = try f.allocLocal(inst_ty, .Const);
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    const writer = f.object.writer();
    const operand = try f.resolveInst(ty_op.operand);
    const array_len = f.air.typeOf(ty_op.operand).elemType().arrayLen();

    try writer.writeAll(" = { .ptr = ");
    try f.writeCValue(writer, operand);
    try writer.print(", .len = {d} }};\n", .{array_len});
    return local;
}

/// Emits a local variable with the result type and initializes it
/// with the operand.
fn airSimpleCast(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst)) return CValue.none;

    const inst_ty = f.air.typeOfIndex(inst);
    const local = try f.allocLocal(inst_ty, .Const);
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    const writer = f.object.writer();
    const operand = try f.resolveInst(ty_op.operand);

    try writer.writeAll(" = ");
    try f.writeCValue(writer, operand);
    try writer.writeAll(";\n");
    return local;
}

fn airPtrToInt(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst)) return CValue.none;

    const inst_ty = f.air.typeOfIndex(inst);
    const local = try f.allocLocal(inst_ty, .Const);
    const un_op = f.air.instructions.items(.data)[inst].un_op;
    const writer = f.object.writer();
    const operand = try f.resolveInst(un_op);

    try writer.writeAll(" = (");
    try f.renderType(writer, inst_ty);
    try writer.writeAll(")");
    try f.writeCValue(writer, operand);
    try writer.writeAll(";\n");
    return local;
}

fn airBuiltinCall(f: *Function, inst: Air.Inst.Index, fn_name: [*:0]const u8) !CValue {
    if (f.liveness.isUnused(inst)) return CValue.none;

    const inst_ty = f.air.typeOfIndex(inst);
    const local = try f.allocLocal(inst_ty, .Const);
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    const writer = f.object.writer();
    const operand = try f.resolveInst(ty_op.operand);

    // TODO implement the function in zig.h and call it here

    try writer.print(" = {s}(", .{fn_name});
    try f.writeCValue(writer, operand);
    try writer.writeAll(");\n");
    return local;
}

fn airCmpxchg(f: *Function, inst: Air.Inst.Index, flavor: [*:0]const u8) !CValue {
    const ty_pl = f.air.instructions.items(.data)[inst].ty_pl;
    const extra = f.air.extraData(Air.Cmpxchg, ty_pl.payload).data;
    const inst_ty = f.air.typeOfIndex(inst);
    const ptr = try f.resolveInst(extra.ptr);
    const expected_value = try f.resolveInst(extra.expected_value);
    const new_value = try f.resolveInst(extra.new_value);
    const local = try f.allocLocal(inst_ty, .Const);
    const writer = f.object.writer();

    try writer.print(" = zig_cmpxchg_{s}(", .{flavor});
    try f.writeCValue(writer, ptr);
    try writer.writeAll(", ");
    try f.writeCValue(writer, expected_value);
    try writer.writeAll(", ");
    try f.writeCValue(writer, new_value);
    try writer.writeAll(", ");
    try writeMemoryOrder(writer, extra.successOrder());
    try writer.writeAll(", ");
    try writeMemoryOrder(writer, extra.failureOrder());
    try writer.writeAll(");\n");

    return local;
}

fn airAtomicRmw(f: *Function, inst: Air.Inst.Index) !CValue {
    const pl_op = f.air.instructions.items(.data)[inst].pl_op;
    const extra = f.air.extraData(Air.AtomicRmw, pl_op.payload).data;
    const inst_ty = f.air.typeOfIndex(inst);
    const ptr = try f.resolveInst(pl_op.operand);
    const operand = try f.resolveInst(extra.operand);
    const local = try f.allocLocal(inst_ty, .Const);
    const writer = f.object.writer();

    try writer.print(" = zig_atomicrmw_{s}(", .{toAtomicRmwSuffix(extra.op())});
    try f.writeCValue(writer, ptr);
    try writer.writeAll(", ");
    try f.writeCValue(writer, operand);
    try writer.writeAll(", ");
    try writeMemoryOrder(writer, extra.ordering());
    try writer.writeAll(");\n");

    return local;
}

fn airAtomicLoad(f: *Function, inst: Air.Inst.Index) !CValue {
    const atomic_load = f.air.instructions.items(.data)[inst].atomic_load;
    const ptr = try f.resolveInst(atomic_load.ptr);
    const ptr_ty = f.air.typeOf(atomic_load.ptr);
    if (!ptr_ty.isVolatilePtr() and f.liveness.isUnused(inst))
        return CValue.none;

    const inst_ty = f.air.typeOfIndex(inst);
    const local = try f.allocLocal(inst_ty, .Const);
    const writer = f.object.writer();

    try writer.writeAll(" = zig_atomic_load(");
    try f.writeCValue(writer, ptr);
    try writer.writeAll(", ");
    try writeMemoryOrder(writer, atomic_load.order);
    try writer.writeAll(");\n");

    return local;
}

fn airAtomicStore(f: *Function, inst: Air.Inst.Index, order: [*:0]const u8) !CValue {
    const bin_op = f.air.instructions.items(.data)[inst].bin_op;
    const ptr = try f.resolveInst(bin_op.lhs);
    const element = try f.resolveInst(bin_op.rhs);
    const inst_ty = f.air.typeOfIndex(inst);
    const local = try f.allocLocal(inst_ty, .Const);
    const writer = f.object.writer();

    try writer.writeAll(" = zig_atomic_store(");
    try f.writeCValue(writer, ptr);
    try writer.writeAll(", ");
    try f.writeCValue(writer, element);
    try writer.print(", {s});\n", .{order});

    return local;
}

fn airMemset(f: *Function, inst: Air.Inst.Index) !CValue {
    const pl_op = f.air.instructions.items(.data)[inst].pl_op;
    const extra = f.air.extraData(Air.Bin, pl_op.payload).data;
    const dest_ptr = try f.resolveInst(pl_op.operand);
    const value = try f.resolveInst(extra.lhs);
    const len = try f.resolveInst(extra.rhs);
    const writer = f.object.writer();

    try writer.writeAll("memset(");
    try f.writeCValue(writer, dest_ptr);
    try writer.writeAll(", ");
    try f.writeCValue(writer, value);
    try writer.writeAll(", ");
    try f.writeCValue(writer, len);
    try writer.writeAll(");\n");

    return CValue.none;
}

fn airMemcpy(f: *Function, inst: Air.Inst.Index) !CValue {
    const pl_op = f.air.instructions.items(.data)[inst].pl_op;
    const extra = f.air.extraData(Air.Bin, pl_op.payload).data;
    const dest_ptr = try f.resolveInst(pl_op.operand);
    const src_ptr = try f.resolveInst(extra.lhs);
    const len = try f.resolveInst(extra.rhs);
    const writer = f.object.writer();

    try writer.writeAll("memcpy(");
    try f.writeCValue(writer, dest_ptr);
    try writer.writeAll(", ");
    try f.writeCValue(writer, src_ptr);
    try writer.writeAll(", ");
    try f.writeCValue(writer, len);
    try writer.writeAll(");\n");

    return CValue.none;
}

fn airSetUnionTag(f: *Function, inst: Air.Inst.Index) !CValue {
    const bin_op = f.air.instructions.items(.data)[inst].bin_op;
    const union_ptr = try f.resolveInst(bin_op.lhs);
    const new_tag = try f.resolveInst(bin_op.rhs);
    const writer = f.object.writer();

    try writer.writeAll("*");
    try f.writeCValue(writer, union_ptr);
    try writer.writeAll(" = ");
    try f.writeCValue(writer, new_tag);
    try writer.writeAll(";\n");

    return CValue.none;
}

fn airGetUnionTag(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst))
        return CValue.none;

    const inst_ty = f.air.typeOfIndex(inst);
    const local = try f.allocLocal(inst_ty, .Const);
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    const writer = f.object.writer();
    const operand = try f.resolveInst(ty_op.operand);

    try writer.writeAll("get_union_tag(");
    try f.writeCValue(writer, operand);
    try writer.writeAll(");\n");
    return local;
}

fn toMemoryOrder(order: std.builtin.AtomicOrder) [:0]const u8 {
    return switch (order) {
        .Unordered => "memory_order_relaxed",
        .Monotonic => "memory_order_consume",
        .Acquire => "memory_order_acquire",
        .Release => "memory_order_release",
        .AcqRel => "memory_order_acq_rel",
        .SeqCst => "memory_order_seq_cst",
    };
}

fn writeMemoryOrder(w: anytype, order: std.builtin.AtomicOrder) !void {
    return w.writeAll(toMemoryOrder(order));
}

fn toAtomicRmwSuffix(order: std.builtin.AtomicRmwOp) []const u8 {
    return switch (order) {
        .Xchg => "xchg",
        .Add => "add",
        .Sub => "sub",
        .And => "and",
        .Nand => "nand",
        .Or => "or",
        .Xor => "xor",
        .Max => "max",
        .Min => "min",
    };
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

fn toCIntBits(zig_bits: u32) ?u32 {
    for (&[_]u8{ 8, 16, 32, 64, 128 }) |c_bits| {
        if (zig_bits <= c_bits) {
            return c_bits;
        }
    }
    return null;
}
