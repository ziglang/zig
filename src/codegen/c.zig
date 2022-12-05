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
const Liveness = @import("../Liveness.zig");
const CType = @import("../type.zig").CType;

const target_util = @import("../target.zig");
const libcFloatPrefix = target_util.libcFloatPrefix;
const libcFloatSuffix = target_util.libcFloatSuffix;
const compilerRtFloatAbbrev = target_util.compilerRtFloatAbbrev;
const compilerRtIntAbbrev = target_util.compilerRtIntAbbrev;

const Mutability = enum { Const, ConstArgument, Mut };
const BigIntLimb = std.math.big.Limb;
const BigInt = std.math.big.int;

pub const CValue = union(enum) {
    none: void,
    local: LocalIndex,
    /// Address of a local.
    local_ref: LocalIndex,
    /// A constant instruction, to be rendered inline.
    constant: Air.Inst.Ref,
    /// Index into the parameters
    arg: usize,
    /// Index into a tuple's fields
    field: usize,
    /// By-value
    decl: Decl.Index,
    decl_ref: Decl.Index,
    /// An undefined value (cannot be dereferenced)
    undef: Type,
    /// Render the slice as an identifier (using fmtIdent)
    identifier: []const u8,
    /// Render these bytes literally.
    /// TODO make this a [*:0]const u8 to save memory
    bytes: []const u8,
};

const BlockData = struct {
    block_id: usize,
    result: CValue,
};

const TypedefKind = enum {
    Forward,
    Complete,
};

pub const CValueMap = std.AutoHashMap(Air.Inst.Ref, CValue);
pub const TypedefMap = std.ArrayHashMap(
    Type,
    struct { name: []const u8, rendered: []u8 },
    Type.HashContext32,
    true,
);

const LoopDepth = u16;
const Local = struct {
    ty: Type,
    alignment: u32,
    /// How many loops the last definition was nested in.
    loop_depth: LoopDepth,
};

const LocalIndex = u16;
const LocalsList = std.ArrayListUnmanaged(LocalIndex);
const LocalsMap = std.ArrayHashMapUnmanaged(Type, LocalsList, Type.HashContext32, true);
const LocalsStack = std.ArrayListUnmanaged(LocalsMap);

const FormatTypeAsCIdentContext = struct {
    ty: Type,
    mod: *Module,
};

const ValueRenderLocation = enum {
    FunctionArgument,
    Initializer,
    Other,
};

const BuiltinInfo = enum {
    None,
    Range,
    Bits,
};

fn formatTypeAsCIdentifier(
    data: FormatTypeAsCIdentContext,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    var stack = std.heap.stackFallback(128, data.mod.gpa);
    const allocator = stack.get();
    const str = std.fmt.allocPrint(allocator, "{}", .{data.ty.fmt(data.mod)}) catch "";
    defer allocator.free(str);
    return formatIdent(str, fmt, options, writer);
}

pub fn typeToCIdentifier(ty: Type, mod: *Module) std.fmt.Formatter(formatTypeAsCIdentifier) {
    return .{ .data = .{
        .ty = ty,
        .mod = mod,
    } };
}

const reserved_idents = std.ComptimeStringMap(void, .{
    .{ "alignas", {
        @setEvalBranchQuota(4000);
    } },
    .{ "alignof", {} },
    .{ "asm", {} },
    .{ "atomic_bool", {} },
    .{ "atomic_char", {} },
    .{ "atomic_char16_t", {} },
    .{ "atomic_char32_t", {} },
    .{ "atomic_int", {} },
    .{ "atomic_int_fast16_t", {} },
    .{ "atomic_int_fast32_t", {} },
    .{ "atomic_int_fast64_t", {} },
    .{ "atomic_int_fast8_t", {} },
    .{ "atomic_int_least16_t", {} },
    .{ "atomic_int_least32_t", {} },
    .{ "atomic_int_least64_t", {} },
    .{ "atomic_int_least8_t", {} },
    .{ "atomic_intmax_t", {} },
    .{ "atomic_intptr_t", {} },
    .{ "atomic_llong", {} },
    .{ "atomic_long", {} },
    .{ "atomic_ptrdiff_t", {} },
    .{ "atomic_schar", {} },
    .{ "atomic_short", {} },
    .{ "atomic_size_t", {} },
    .{ "atomic_uchar", {} },
    .{ "atomic_uint", {} },
    .{ "atomic_uint_fast16_t", {} },
    .{ "atomic_uint_fast32_t", {} },
    .{ "atomic_uint_fast64_t", {} },
    .{ "atomic_uint_fast8_t", {} },
    .{ "atomic_uint_least16_t", {} },
    .{ "atomic_uint_least32_t", {} },
    .{ "atomic_uint_least64_t", {} },
    .{ "atomic_uint_least8_t", {} },
    .{ "atomic_uintmax_t", {} },
    .{ "atomic_uintptr_t", {} },
    .{ "atomic_ullong", {} },
    .{ "atomic_ulong", {} },
    .{ "atomic_ushort", {} },
    .{ "atomic_wchar_t", {} },
    .{ "auto", {} },
    .{ "bool", {} },
    .{ "break", {} },
    .{ "case", {} },
    .{ "char", {} },
    .{ "complex", {} },
    .{ "const", {} },
    .{ "continue", {} },
    .{ "default", {} },
    .{ "do", {} },
    .{ "double", {} },
    .{ "else", {} },
    .{ "enum", {} },
    .{ "extern ", {} },
    .{ "float", {} },
    .{ "for", {} },
    .{ "fortran", {} },
    .{ "goto", {} },
    .{ "if", {} },
    .{ "imaginary", {} },
    .{ "inline", {} },
    .{ "int", {} },
    .{ "int16_t", {} },
    .{ "int32_t", {} },
    .{ "int64_t", {} },
    .{ "int8_t", {} },
    .{ "intptr_t", {} },
    .{ "long", {} },
    .{ "noreturn", {} },
    .{ "register", {} },
    .{ "restrict", {} },
    .{ "return", {} },
    .{ "short", {} },
    .{ "signed", {} },
    .{ "size_t", {} },
    .{ "sizeof", {} },
    .{ "ssize_t", {} },
    .{ "static", {} },
    .{ "static_assert", {} },
    .{ "struct", {} },
    .{ "switch", {} },
    .{ "thread_local", {} },
    .{ "typedef", {} },
    .{ "uint16_t", {} },
    .{ "uint32_t", {} },
    .{ "uint64_t", {} },
    .{ "uint8_t", {} },
    .{ "uintptr_t", {} },
    .{ "union", {} },
    .{ "unsigned", {} },
    .{ "void", {} },
    .{ "volatile", {} },
    .{ "while ", {} },
});

fn isReservedIdent(ident: []const u8) bool {
    if (ident.len >= 2 and ident[0] == '_') {
        switch (ident[1]) {
            'A'...'Z', '_' => return true,
            else => return false,
        }
    } else return reserved_idents.has(ident);
}

fn formatIdent(
    ident: []const u8,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = options;
    const solo = fmt.len != 0 and fmt[0] == ' '; // space means solo; not part of a bigger ident.
    if (solo and isReservedIdent(ident)) {
        try writer.writeAll("zig_e_");
    }
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
    next_block_index: usize = 0,
    object: Object,
    func: *Module.Fn,
    /// All the locals, to be emitted at the top of the function.
    locals: std.ArrayListUnmanaged(Local) = .{},
    /// Which locals are available for reuse, based on Type.
    /// Only locals in the last stack entry are available for reuse,
    /// other entries will become available on loop exit.
    free_locals_stack: LocalsStack = .{},
    free_locals_clone_depth: LoopDepth = 0,
    /// Locals which will not be freed by Liveness. This is used after a
    /// Function body is lowered in order to make `free_locals_stack` have
    /// 100% of the locals within so that it can be used to render the block
    /// of variable declarations at the top of a function, sorted descending
    /// by type alignment.
    /// The value is whether the alloc is static or not.
    allocs: std.AutoArrayHashMapUnmanaged(LocalIndex, bool) = .{},
    /// Needed for memory used by the keys of free_locals_stack entries.
    arena: std.heap.ArenaAllocator,

    fn tyHashCtx(f: Function) Type.HashContext32 {
        return .{ .mod = f.object.dg.module };
    }

    fn resolveInst(f: *Function, inst: Air.Inst.Ref) !CValue {
        const gop = try f.value_map.getOrPut(inst);
        if (gop.found_existing) return gop.value_ptr.*;

        const val = f.air.value(inst).?;
        const ty = f.air.typeOf(inst);

        const result = if (lowersToArray(ty, f.object.dg.module.getTarget())) result: {
            const writer = f.object.code_header.writer();
            const alignment = 0;
            const decl_c_value = try f.allocLocalValue(ty, alignment);
            const gpa = f.object.dg.gpa;
            try f.allocs.put(gpa, decl_c_value.local, true);
            try writer.writeAll("static ");
            try f.object.dg.renderTypeAndName(writer, ty, decl_c_value, .Const, alignment, .Complete);
            try writer.writeAll(" = ");
            try f.object.dg.renderValue(writer, ty, val, .Initializer);
            try writer.writeAll(";\n ");
            break :result decl_c_value;
        } else CValue{ .constant = inst };

        gop.value_ptr.* = result;
        return result;
    }

    fn wantSafety(f: *Function) bool {
        return switch (f.object.dg.module.optimizeMode()) {
            .Debug, .ReleaseSafe => true,
            .ReleaseFast, .ReleaseSmall => false,
        };
    }

    fn getFreeLocals(f: *Function) *LocalsMap {
        return &f.free_locals_stack.items[f.free_locals_stack.items.len - 1];
    }

    /// Skips the reuse logic.
    fn allocLocalValue(f: *Function, ty: Type, alignment: u32) !CValue {
        const gpa = f.object.dg.gpa;
        try f.locals.append(gpa, .{
            .ty = ty,
            .alignment = alignment,
            .loop_depth = @intCast(LoopDepth, f.free_locals_stack.items.len - 1),
        });
        return CValue{ .local = @intCast(LocalIndex, f.locals.items.len - 1) };
    }

    fn allocLocal(f: *Function, inst: Air.Inst.Index, ty: Type) !CValue {
        const result = try f.allocAlignedLocal(ty, .Mut, 0);
        log.debug("%{d}: allocating t{d}", .{ inst, result.local });
        return result;
    }

    /// Only allocates the local; does not print anything.
    fn allocAlignedLocal(f: *Function, ty: Type, mutability: Mutability, alignment: u32) !CValue {
        _ = mutability;

        if (f.getFreeLocals().getPtrContext(ty, f.tyHashCtx())) |locals_list| {
            for (locals_list.items) |local_index, i| {
                const local = &f.locals.items[local_index];
                if (local.alignment >= alignment) {
                    local.loop_depth = @intCast(LoopDepth, f.free_locals_stack.items.len - 1);
                    _ = locals_list.swapRemove(i);
                    return CValue{ .local = local_index };
                }
            }
        }

        return try f.allocLocalValue(ty, alignment);
    }

    fn writeCValue(f: *Function, w: anytype, c_value: CValue, location: ValueRenderLocation) !void {
        switch (c_value) {
            .constant => |inst| {
                const ty = f.air.typeOf(inst);
                const val = f.air.value(inst).?;
                return f.object.dg.renderValue(w, ty, val, location);
            },
            .undef => |ty| return f.object.dg.renderValue(w, ty, Value.undef, location),
            else => return f.object.dg.writeCValue(w, c_value),
        }
    }

    fn writeCValueDeref(f: *Function, w: anytype, c_value: CValue) !void {
        switch (c_value) {
            .constant => |inst| {
                const ty = f.air.typeOf(inst);
                const val = f.air.value(inst).?;
                try w.writeAll("(*");
                try f.object.dg.renderValue(w, ty, val, .Other);
                return w.writeByte(')');
            },
            else => return f.object.dg.writeCValueDeref(w, c_value),
        }
    }

    fn writeCValueMember(f: *Function, w: anytype, c_value: CValue, member: CValue) !void {
        switch (c_value) {
            .constant => |inst| {
                const ty = f.air.typeOf(inst);
                const val = f.air.value(inst).?;
                try f.object.dg.renderValue(w, ty, val, .Other);
                try w.writeByte('.');
                return f.writeCValue(w, member, .Other);
            },
            else => return f.object.dg.writeCValueMember(w, c_value, member),
        }
    }

    fn writeCValueDerefMember(f: *Function, w: anytype, c_value: CValue, member: CValue) !void {
        switch (c_value) {
            .constant => |inst| {
                const ty = f.air.typeOf(inst);
                const val = f.air.value(inst).?;
                try w.writeByte('(');
                try f.object.dg.renderValue(w, ty, val, .Other);
                try w.writeAll(")->");
                return f.writeCValue(w, member, .Other);
            },
            else => return f.object.dg.writeCValueDerefMember(w, c_value, member),
        }
    }

    fn fail(f: *Function, comptime format: []const u8, args: anytype) error{ AnalysisFail, OutOfMemory } {
        return f.object.dg.fail(format, args);
    }

    fn renderType(f: *Function, w: anytype, t: Type) !void {
        return f.object.dg.renderType(w, t, .Complete);
    }

    fn renderTypecast(f: *Function, w: anytype, t: Type) !void {
        return f.object.dg.renderTypecast(w, t);
    }

    fn fmtIntLiteral(f: *Function, ty: Type, val: Value) !std.fmt.Formatter(formatIntLiteral) {
        return f.object.dg.fmtIntLiteral(ty, val);
    }

    pub fn deinit(f: *Function, gpa: mem.Allocator) void {
        f.allocs.deinit(gpa);
        f.locals.deinit(gpa);
        for (f.free_locals_stack.items) |*free_locals| {
            deinitFreeLocalsMap(gpa, free_locals);
        }
        f.free_locals_stack.deinit(gpa);
        f.blocks.deinit(gpa);
        f.value_map.deinit();
        f.object.code.deinit();
        for (f.object.dg.typedefs.values()) |typedef| {
            gpa.free(typedef.rendered);
        }
        f.object.dg.typedefs.deinit();
        f.object.dg.fwd_decl.deinit();
        f.arena.deinit();
    }
};

/// This data is available when outputting .c code for a `Module`.
/// It is not available when generating .h file.
pub const Object = struct {
    dg: DeclGen,
    code: std.ArrayList(u8),
    /// Goes before code. Initialized and deinitialized in `genFunc`.
    code_header: std.ArrayList(u8) = undefined,
    indent_writer: IndentWriter(std.ArrayList(u8).Writer),

    fn writer(o: *Object) IndentWriter(std.ArrayList(u8).Writer).Writer {
        return o.indent_writer.writer();
    }
};

/// This data is available both when outputting .c code and when outputting an .h file.
pub const DeclGen = struct {
    gpa: std.mem.Allocator,
    module: *Module,
    decl: *Decl,
    decl_index: Decl.Index,
    fwd_decl: std.ArrayList(u8),
    error_msg: ?*Module.ErrorMsg,
    /// The key of this map is Type which has references to typedefs_arena.
    typedefs: TypedefMap,
    typedefs_arena: std.mem.Allocator,

    fn fail(dg: *DeclGen, comptime format: []const u8, args: anytype) error{ AnalysisFail, OutOfMemory } {
        @setCold(true);
        const src = LazySrcLoc.nodeOffset(0);
        const src_loc = src.toSrcLoc(dg.decl);
        dg.error_msg = try Module.ErrorMsg.create(dg.gpa, src_loc, format, args);
        return error.AnalysisFail;
    }

    fn getTypedefName(dg: *DeclGen, t: Type) ?[]const u8 {
        if (dg.typedefs.get(t)) |typedef| {
            return typedef.name;
        } else {
            return null;
        }
    }

    fn renderDeclValue(
        dg: *DeclGen,
        writer: anytype,
        ty: Type,
        val: Value,
        decl_index: Decl.Index,
    ) error{ OutOfMemory, AnalysisFail }!void {
        const decl = dg.module.declPtr(decl_index);
        assert(decl.has_tv);

        // Render an undefined pointer if we have a pointer to a zero-bit or comptime type.
        if (ty.isPtrAtRuntime() and !decl.ty.isFnOrHasRuntimeBits()) {
            return dg.writeCValue(writer, CValue{ .undef = ty });
        }

        // Chase function values in order to be able to reference the original function.
        inline for (.{ .function, .extern_fn }) |tag|
            if (decl.val.castTag(tag)) |func|
                if (func.data.owner_decl != decl_index)
                    return dg.renderDeclValue(writer, ty, val, func.data.owner_decl);

        if (ty.isSlice()) {
            try writer.writeByte('(');
            try dg.renderTypecast(writer, ty);
            try writer.writeAll("){ .ptr = ");

            var buf: Type.SlicePtrFieldTypeBuffer = undefined;
            try dg.renderValue(writer, ty.slicePtrFieldType(&buf), val.slicePtr(), .Initializer);

            var len_pl: Value.Payload.U64 = .{
                .base = .{ .tag = .int_u64 },
                .data = val.sliceLen(dg.module),
            };
            const len_val = Value.initPayload(&len_pl.base);
            return writer.print(", .len = {} }}", .{try dg.fmtIntLiteral(Type.usize, len_val)});
        }

        // We shouldn't cast C function pointers as this is UB (when you call
        // them).  The analysis until now should ensure that the C function
        // pointers are compatible.  If they are not, then there is a bug
        // somewhere and we should let the C compiler tell us about it.
        const need_typecast = if (ty.castPtrToFn()) |_| false else !ty.eql(decl.ty, dg.module);
        if (need_typecast) {
            try writer.writeAll("((");
            try dg.renderTypecast(writer, ty);
            try writer.writeByte(')');
        }
        try writer.writeByte('&');
        try dg.renderDeclName(writer, decl_index, 0);
        if (need_typecast) try writer.writeByte(')');
    }

    // Renders a "parent" pointer by recursing to the root decl/variable
    // that its contents are defined with respect to.
    //
    // Used for .elem_ptr, .field_ptr, .opt_payload_ptr, .eu_payload_ptr
    fn renderParentPtr(dg: *DeclGen, writer: anytype, ptr_val: Value, ptr_ty: Type) error{ OutOfMemory, AnalysisFail }!void {
        if (!ptr_ty.isSlice()) {
            try writer.writeByte('(');
            try dg.renderTypecast(writer, ptr_ty);
            try writer.writeByte(')');
        }
        switch (ptr_val.tag()) {
            .decl_ref_mut, .decl_ref, .variable => {
                const decl_index = switch (ptr_val.tag()) {
                    .decl_ref => ptr_val.castTag(.decl_ref).?.data,
                    .decl_ref_mut => ptr_val.castTag(.decl_ref_mut).?.data.decl_index,
                    .variable => ptr_val.castTag(.variable).?.data.owner_decl,
                    else => unreachable,
                };
                try dg.renderDeclValue(writer, ptr_ty, ptr_val, decl_index);
            },
            .field_ptr => {
                const ptr_info = ptr_ty.ptrInfo();
                const field_ptr = ptr_val.castTag(.field_ptr).?.data;
                const container_ty = field_ptr.container_ty;
                const index = field_ptr.field_index;

                var container_ptr_ty_pl: Type.Payload.ElemType = .{
                    .base = .{ .tag = .c_mut_pointer },
                    .data = field_ptr.container_ty,
                };
                const container_ptr_ty = Type.initPayload(&container_ptr_ty_pl.base);

                const FieldInfo = struct { name: []const u8, ty: Type };
                const field_info: FieldInfo = switch (container_ty.zigTypeTag()) {
                    .Struct => switch (container_ty.containerLayout()) {
                        .Auto, .Extern => FieldInfo{
                            .name = container_ty.structFields().keys()[index],
                            .ty = container_ty.structFields().values()[index].ty,
                        },
                        .Packed => if (ptr_info.data.host_size == 0) {
                            const target = dg.module.getTarget();

                            const byte_offset = container_ty.packedStructFieldByteOffset(index, target);
                            var byte_offset_pl = Value.Payload.U64{
                                .base = .{ .tag = .int_u64 },
                                .data = byte_offset,
                            };
                            const byte_offset_val = Value.initPayload(&byte_offset_pl.base);

                            var u8_ptr_pl = ptr_info;
                            u8_ptr_pl.data.pointee_type = Type.u8;
                            const u8_ptr_ty = Type.initPayload(&u8_ptr_pl.base);

                            try writer.writeAll("&((");
                            try dg.renderTypecast(writer, u8_ptr_ty);
                            try writer.writeByte(')');
                            try dg.renderParentPtr(writer, field_ptr.container_ptr, container_ptr_ty);
                            return writer.print(")[{}]", .{try dg.fmtIntLiteral(Type.usize, byte_offset_val)});
                        } else {
                            var host_pl = Type.Payload.Bits{
                                .base = .{ .tag = .int_unsigned },
                                .data = ptr_info.data.host_size * 8,
                            };
                            const host_ty = Type.initPayload(&host_pl.base);

                            try writer.writeByte('(');
                            try dg.renderTypecast(writer, ptr_ty);
                            try writer.writeByte(')');
                            return dg.renderParentPtr(writer, field_ptr.container_ptr, host_ty);
                        },
                    },
                    .Union => switch (container_ty.containerLayout()) {
                        .Auto, .Extern => FieldInfo{
                            .name = container_ty.unionFields().keys()[index],
                            .ty = container_ty.unionFields().values()[index].ty,
                        },
                        .Packed => {
                            return dg.renderParentPtr(writer, field_ptr.container_ptr, ptr_ty);
                        },
                    },
                    .Pointer => field_info: {
                        assert(container_ty.isSlice());
                        break :field_info switch (index) {
                            0 => FieldInfo{ .name = "ptr", .ty = container_ty.childType() },
                            1 => FieldInfo{ .name = "len", .ty = Type.usize },
                            else => unreachable,
                        };
                    },
                    else => unreachable,
                };

                if (field_info.ty.hasRuntimeBitsIgnoreComptime()) {
                    try writer.writeAll("&(");
                    try dg.renderParentPtr(writer, field_ptr.container_ptr, container_ptr_ty);
                    try writer.writeAll(")->");
                    switch (field_ptr.container_ty.tag()) {
                        .union_tagged, .union_safety_tagged => try writer.writeAll("payload."),
                        else => {},
                    }
                    try writer.print("{ }", .{fmtIdent(field_info.name)});
                } else {
                    try dg.renderParentPtr(writer, field_ptr.container_ptr, field_info.ty);
                }
            },
            .elem_ptr => {
                const elem_ptr = ptr_val.castTag(.elem_ptr).?.data;
                var elem_ptr_ty_pl: Type.Payload.ElemType = .{
                    .base = .{ .tag = .c_mut_pointer },
                    .data = elem_ptr.elem_ty,
                };
                const elem_ptr_ty = Type.initPayload(&elem_ptr_ty_pl.base);

                try writer.writeAll("&(");
                try dg.renderParentPtr(writer, elem_ptr.array_ptr, elem_ptr_ty);
                try writer.print(")[{d}]", .{elem_ptr.index});
            },
            .opt_payload_ptr, .eu_payload_ptr => {
                const payload_ptr = ptr_val.cast(Value.Payload.PayloadPtr).?.data;
                var container_ptr_ty_pl: Type.Payload.ElemType = .{
                    .base = .{ .tag = .c_mut_pointer },
                    .data = payload_ptr.container_ty,
                };
                const container_ptr_ty = Type.initPayload(&container_ptr_ty_pl.base);

                try writer.writeAll("&(");
                try dg.renderParentPtr(writer, payload_ptr.container_ptr, container_ptr_ty);
                try writer.writeAll(")->payload");
            },
            else => unreachable,
        }
    }

    fn renderValue(
        dg: *DeclGen,
        writer: anytype,
        ty: Type,
        arg_val: Value,
        location: ValueRenderLocation,
    ) error{ OutOfMemory, AnalysisFail }!void {
        var val = arg_val;
        if (val.castTag(.runtime_value)) |rt| {
            val = rt.data;
        }
        const target = dg.module.getTarget();

        const safety_on = switch (dg.module.optimizeMode()) {
            .Debug, .ReleaseSafe => true,
            .ReleaseFast, .ReleaseSmall => false,
        };

        if (val.isUndefDeep()) {
            switch (ty.zigTypeTag()) {
                .Bool => {
                    if (safety_on) {
                        return writer.writeAll("0xaa");
                    } else {
                        return writer.writeAll("false");
                    }
                },
                .Int, .Enum, .ErrorSet => return writer.print("{x}", .{try dg.fmtIntLiteral(ty, val)}),
                .Float => {
                    const bits = ty.floatBits(target);
                    var int_pl = Type.Payload.Bits{ .base = .{ .tag = .int_signed }, .data = bits };
                    const int_ty = Type.initPayload(&int_pl.base);

                    try writer.writeByte('(');
                    try dg.renderTypecast(writer, ty);
                    try writer.writeAll(")zig_as_");
                    try dg.renderTypeForBuiltinFnName(writer, ty);
                    try writer.writeByte('(');
                    switch (bits) {
                        16 => try writer.print("{x}", .{@bitCast(f16, undefPattern(i16))}),
                        32 => try writer.print("{x}", .{@bitCast(f32, undefPattern(i32))}),
                        64 => try writer.print("{x}", .{@bitCast(f64, undefPattern(i64))}),
                        80 => try writer.print("{x}", .{@bitCast(f80, undefPattern(i80))}),
                        128 => try writer.print("{x}", .{@bitCast(f128, undefPattern(i128))}),
                        else => unreachable,
                    }
                    try writer.writeAll(", ");
                    try dg.renderValue(writer, int_ty, Value.undef, .FunctionArgument);
                    return writer.writeByte(')');
                },
                .Pointer => if (ty.isSlice()) {
                    if (location != .Initializer) {
                        try writer.writeByte('(');
                        try dg.renderTypecast(writer, ty);
                        try writer.writeByte(')');
                    }

                    try writer.writeAll("{(");
                    var buf: Type.SlicePtrFieldTypeBuffer = undefined;
                    const ptr_ty = ty.slicePtrFieldType(&buf);
                    try dg.renderTypecast(writer, ptr_ty);
                    return writer.print("){x}, {0x}}}", .{try dg.fmtIntLiteral(Type.usize, val)});
                } else {
                    try writer.writeAll("((");
                    try dg.renderTypecast(writer, ty);
                    return writer.print("){x})", .{try dg.fmtIntLiteral(Type.usize, val)});
                },
                .Optional => {
                    var opt_buf: Type.Payload.ElemType = undefined;
                    const payload_ty = ty.optionalChild(&opt_buf);

                    if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
                        return dg.renderValue(writer, Type.bool, val, location);
                    }

                    if (ty.optionalReprIsPayload()) {
                        return dg.renderValue(writer, payload_ty, val, location);
                    }

                    if (location != .Initializer) {
                        try writer.writeByte('(');
                        try dg.renderTypecast(writer, ty);
                        try writer.writeByte(')');
                    }

                    try writer.writeAll("{ .payload = ");
                    try dg.renderValue(writer, payload_ty, val, .Initializer);
                    try writer.writeAll(", .is_null = ");
                    try dg.renderValue(writer, Type.bool, val, .Initializer);
                    return writer.writeAll(" }");
                },
                .Struct => switch (ty.containerLayout()) {
                    .Auto, .Extern => {
                        if (location != .Initializer) {
                            try writer.writeByte('(');
                            try dg.renderTypecast(writer, ty);
                            try writer.writeByte(')');
                        }

                        try writer.writeByte('{');
                        var empty = true;
                        for (ty.structFields().values()) |field| {
                            if (!field.ty.hasRuntimeBits()) continue;

                            if (!empty) try writer.writeByte(',');
                            try dg.renderValue(writer, field.ty, val, .Initializer);

                            empty = false;
                        }
                        if (empty) try writer.print("{x}", .{try dg.fmtIntLiteral(Type.u8, Value.undef)});
                        return writer.writeByte('}');
                    },
                    .Packed => return writer.print("{x}", .{try dg.fmtIntLiteral(ty, Value.undef)}),
                },
                .Union => {
                    if (location != .Initializer) {
                        try writer.writeByte('(');
                        try dg.renderTypecast(writer, ty);
                        try writer.writeByte(')');
                    }

                    try writer.writeByte('{');
                    if (ty.unionTagTypeSafety()) |tag_ty| {
                        const layout = ty.unionGetLayout(target);
                        if (layout.tag_size != 0) {
                            try writer.writeAll(" .tag = ");
                            try dg.renderValue(writer, tag_ty, val, .Initializer);
                            try writer.writeByte(',');
                        }
                        try writer.writeAll(" .payload = {");
                    }
                    for (ty.unionFields().values()) |field| {
                        if (!field.ty.hasRuntimeBits()) continue;
                        try dg.renderValue(writer, field.ty, val, .Initializer);
                        break;
                    } else try writer.print("{x}", .{try dg.fmtIntLiteral(Type.u8, Value.undef)});
                    if (ty.unionTagTypeSafety()) |_| try writer.writeByte('}');
                    return writer.writeByte('}');
                },
                .ErrorUnion => {
                    if (location != .Initializer) {
                        try writer.writeByte('(');
                        try dg.renderTypecast(writer, ty);
                        try writer.writeByte(')');
                    }

                    try writer.writeAll("{ .payload = ");
                    try dg.renderValue(writer, ty.errorUnionPayload(), val, .Initializer);
                    return writer.print(", .error = {x} }}", .{
                        try dg.fmtIntLiteral(ty.errorUnionSet(), val),
                    });
                },
                .Array, .Vector => {
                    if (location != .Initializer) {
                        try writer.writeByte('(');
                        try dg.renderTypecast(writer, ty);
                        try writer.writeByte(')');
                    }

                    const ai = ty.arrayInfo();
                    if (ai.elem_type.eql(Type.u8, dg.module)) {
                        try writer.writeByte('"');
                        const c_len = ty.arrayLenIncludingSentinel();
                        var index: usize = 0;
                        while (index < c_len) : (index += 1)
                            try writeStringLiteralChar(writer, 0xaa);
                        return writer.writeByte('"');
                    } else {
                        try writer.writeByte('{');
                        const c_len = ty.arrayLenIncludingSentinel();
                        var index: usize = 0;
                        while (index < c_len) : (index += 1) {
                            if (index > 0) try writer.writeAll(", ");
                            try dg.renderValue(writer, ty.childType(), val, .Initializer);
                        }
                        return writer.writeByte('}');
                    }
                },
                .ComptimeInt,
                .ComptimeFloat,
                .Type,
                .EnumLiteral,
                .Void,
                .NoReturn,
                .Undefined,
                .Null,
                .BoundFn,
                .Opaque,
                => unreachable,

                .Fn,
                .Frame,
                .AnyFrame,
                => |tag| return dg.fail("TODO: C backend: implement value of type {s}", .{
                    @tagName(tag),
                }),
            }
            unreachable;
        }
        switch (ty.zigTypeTag()) {
            .Int => switch (val.tag()) {
                .field_ptr,
                .elem_ptr,
                .opt_payload_ptr,
                .eu_payload_ptr,
                .decl_ref_mut,
                .decl_ref,
                => try dg.renderParentPtr(writer, val, ty),
                else => try writer.print("{}", .{try dg.fmtIntLiteral(ty, val)}),
            },
            .Float => {
                const bits = ty.floatBits(target);
                const f128_val = val.toFloat(f128);

                var int_ty_pl = Type.Payload.Bits{ .base = .{ .tag = .int_signed }, .data = bits };
                const int_ty = Type.initPayload(&int_ty_pl.base);

                assert(bits <= 128);
                var int_val_limbs: [BigInt.calcTwosCompLimbCount(128)]BigIntLimb = undefined;
                var int_val_big = BigInt.Mutable{
                    .limbs = &int_val_limbs,
                    .len = undefined,
                    .positive = undefined,
                };

                switch (bits) {
                    16 => int_val_big.set(@bitCast(i16, val.toFloat(f16))),
                    32 => int_val_big.set(@bitCast(i32, val.toFloat(f32))),
                    64 => int_val_big.set(@bitCast(i64, val.toFloat(f64))),
                    80 => int_val_big.set(@bitCast(i80, val.toFloat(f80))),
                    128 => int_val_big.set(@bitCast(i128, f128_val)),
                    else => unreachable,
                }

                var int_val_pl = Value.Payload.BigInt{
                    .base = .{ .tag = if (int_val_big.positive) .int_big_positive else .int_big_negative },
                    .data = int_val_big.limbs[0..int_val_big.len],
                };
                const int_val = Value.initPayload(&int_val_pl.base);

                try writer.writeByte('(');
                try dg.renderTypecast(writer, ty);
                try writer.writeByte(')');
                if (std.math.isFinite(f128_val)) {
                    try writer.writeAll("zig_as_");
                    try dg.renderTypeForBuiltinFnName(writer, ty);
                    try writer.writeByte('(');
                    switch (bits) {
                        16 => try writer.print("{x}", .{val.toFloat(f16)}),
                        32 => try writer.print("{x}", .{val.toFloat(f32)}),
                        64 => try writer.print("{x}", .{val.toFloat(f64)}),
                        80 => try writer.print("{x}", .{val.toFloat(f80)}),
                        128 => try writer.print("{x}", .{f128_val}),
                        else => unreachable,
                    }
                } else {
                    const operation = if (std.math.isSignalNan(f128_val))
                        "nans"
                    else if (std.math.isNan(f128_val))
                        "nan"
                    else if (std.math.isInf(f128_val))
                        "inf"
                    else
                        unreachable;

                    try writer.writeAll("zig_as_special_");
                    try dg.renderTypeForBuiltinFnName(writer, ty);
                    try writer.writeByte('(');
                    if (std.math.signbit(f128_val)) try writer.writeByte('-');
                    try writer.writeAll(", ");
                    try writer.writeAll(operation);
                    try writer.writeAll(", ");
                    if (std.math.isNan(f128_val)) switch (bits) {
                        // We only actually need to pass the significand, but it will get
                        // properly masked anyway, so just pass the whole value.
                        16 => try writer.print("\"0x{x}\"", .{@bitCast(u16, val.toFloat(f16))}),
                        32 => try writer.print("\"0x{x}\"", .{@bitCast(u32, val.toFloat(f32))}),
                        64 => try writer.print("\"0x{x}\"", .{@bitCast(u64, val.toFloat(f64))}),
                        80 => try writer.print("\"0x{x}\"", .{@bitCast(u80, val.toFloat(f80))}),
                        128 => try writer.print("\"0x{x}\"", .{@bitCast(u128, f128_val)}),
                        else => unreachable,
                    };
                }
                return writer.print(", {x})", .{try dg.fmtIntLiteral(int_ty, int_val)});
            },
            .Pointer => switch (val.tag()) {
                .null_value, .zero => if (ty.isSlice()) {
                    var slice_pl = Value.Payload.Slice{
                        .base = .{ .tag = .slice },
                        .data = .{ .ptr = val, .len = Value.undef },
                    };
                    const slice_val = Value.initPayload(&slice_pl.base);

                    return dg.renderValue(writer, ty, slice_val, location);
                } else {
                    try writer.writeAll("((");
                    try dg.renderTypecast(writer, ty);
                    try writer.writeAll(")NULL)");
                },
                .variable => {
                    const decl = val.castTag(.variable).?.data.owner_decl;
                    return dg.renderDeclValue(writer, ty, val, decl);
                },
                .slice => {
                    if (location != .Initializer) {
                        try writer.writeByte('(');
                        try dg.renderTypecast(writer, ty);
                        try writer.writeByte(')');
                    }

                    const slice = val.castTag(.slice).?.data;
                    var buf: Type.SlicePtrFieldTypeBuffer = undefined;

                    try writer.writeByte('{');
                    try dg.renderValue(writer, ty.slicePtrFieldType(&buf), slice.ptr, .Initializer);
                    try writer.writeAll(", ");
                    try dg.renderValue(writer, Type.usize, slice.len, .Initializer);
                    try writer.writeByte('}');
                },
                .function => {
                    const func = val.castTag(.function).?.data;
                    try dg.renderDeclName(writer, func.owner_decl, 0);
                },
                .extern_fn => {
                    const extern_fn = val.castTag(.extern_fn).?.data;
                    try dg.renderDeclName(writer, extern_fn.owner_decl, 0);
                },
                .int_u64, .one => {
                    try writer.writeAll("((");
                    try dg.renderTypecast(writer, ty);
                    return writer.print("){x})", .{try dg.fmtIntLiteral(Type.usize, val)});
                },
                .field_ptr,
                .elem_ptr,
                .opt_payload_ptr,
                .eu_payload_ptr,
                .decl_ref_mut,
                .decl_ref,
                => try dg.renderParentPtr(writer, val, ty),
                else => unreachable,
            },
            .Array, .Vector => {
                if (location == .FunctionArgument) {
                    try writer.writeByte('(');
                    try dg.renderTypecast(writer, ty);
                    try writer.writeByte(')');
                }

                // First try specific tag representations for more efficiency.
                switch (val.tag()) {
                    .undef, .empty_struct_value, .empty_array => {
                        try writer.writeByte('{');
                        const ai = ty.arrayInfo();
                        if (ai.sentinel) |s| {
                            try dg.renderValue(writer, ai.elem_type, s, .Initializer);
                        } else {
                            try writer.writeByte('0');
                        }
                        try writer.writeByte('}');
                    },
                    .bytes => {
                        try writer.print("{s}", .{fmtStringLiteral(val.castTag(.bytes).?.data)});
                    },
                    .str_lit => {
                        const str_lit = val.castTag(.str_lit).?.data;
                        const bytes = dg.module.string_literal_bytes.items[str_lit.index..][0..str_lit.len];
                        try writer.print("{s}", .{fmtStringLiteral(bytes)});
                    },
                    else => {
                        // Fall back to generic implementation.
                        var arena = std.heap.ArenaAllocator.init(dg.gpa);
                        defer arena.deinit();
                        const arena_allocator = arena.allocator();

                        const ai = ty.arrayInfo();
                        if (ai.elem_type.eql(Type.u8, dg.module)) {
                            try writer.writeByte('"');
                            var index: usize = 0;
                            while (index < ai.len) : (index += 1) {
                                const elem_val = try val.elemValue(dg.module, arena_allocator, index);
                                const elem_val_u8 = @intCast(u8, elem_val.toUnsignedInt(target));
                                try writeStringLiteralChar(writer, elem_val_u8);
                            }
                            if (ai.sentinel) |s| {
                                const s_u8 = @intCast(u8, s.toUnsignedInt(target));
                                try writeStringLiteralChar(writer, s_u8);
                            }
                            try writer.writeByte('"');
                        } else {
                            try writer.writeByte('{');
                            var index: usize = 0;
                            while (index < ai.len) : (index += 1) {
                                if (index != 0) try writer.writeByte(',');
                                const elem_val = try val.elemValue(dg.module, arena_allocator, index);
                                try dg.renderValue(writer, ai.elem_type, elem_val, .Initializer);
                            }
                            if (ai.sentinel) |s| {
                                if (index != 0) try writer.writeByte(',');
                                try dg.renderValue(writer, ai.elem_type, s, .Initializer);
                            }
                            try writer.writeByte('}');
                        }
                    },
                }
            },
            .Bool => {
                if (val.toBool()) {
                    return writer.writeAll("true");
                } else {
                    return writer.writeAll("false");
                }
            },
            .Optional => {
                var opt_buf: Type.Payload.ElemType = undefined;
                const payload_ty = ty.optionalChild(&opt_buf);

                const is_null_val = Value.makeBool(val.tag() == .null_value);
                if (!payload_ty.hasRuntimeBitsIgnoreComptime())
                    return dg.renderValue(writer, Type.bool, is_null_val, location);

                if (ty.optionalReprIsPayload()) {
                    const payload_val = if (val.castTag(.opt_payload)) |pl| pl.data else val;
                    return dg.renderValue(writer, payload_ty, payload_val, location);
                }

                if (location != .Initializer) {
                    try writer.writeByte('(');
                    try dg.renderTypecast(writer, ty);
                    try writer.writeByte(')');
                }

                const payload_val = if (val.castTag(.opt_payload)) |pl| pl.data else Value.undef;

                try writer.writeAll("{ .payload = ");
                try dg.renderValue(writer, payload_ty, payload_val, .Initializer);
                try writer.writeAll(", .is_null = ");
                try dg.renderValue(writer, Type.bool, is_null_val, .Initializer);
                try writer.writeAll(" }");
            },
            .ErrorSet => {
                const error_name = if (val.castTag(.@"error")) |error_pl|
                    error_pl.data.name
                else
                    dg.module.error_name_list.items[0];
                // Error values are already defined by genErrDecls.
                try writer.print("zig_error_{}", .{fmtIdent(error_name)});
            },
            .ErrorUnion => {
                const error_ty = ty.errorUnionSet();
                const payload_ty = ty.errorUnionPayload();

                if (!payload_ty.hasRuntimeBits()) {
                    // We use the error type directly as the type.
                    if (val.errorUnionIsPayload()) {
                        return try writer.writeByte('0');
                    }
                    return dg.renderValue(writer, error_ty, val, location);
                }

                if (location != .Initializer) {
                    try writer.writeByte('(');
                    try dg.renderTypecast(writer, ty);
                    try writer.writeByte(')');
                }

                const payload_val = if (val.castTag(.eu_payload)) |pl| pl.data else Value.undef;
                const error_val = if (val.errorUnionIsPayload()) Value.zero else val;

                try writer.writeAll("{ .payload = ");
                try dg.renderValue(writer, payload_ty, payload_val, .Initializer);
                try writer.writeAll(", .error = ");
                try dg.renderValue(writer, error_ty, error_val, .Initializer);
                try writer.writeAll(" }");
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
                                    return dg.renderValue(writer, enum_full.tag_ty, tag_val, location);
                                } else {
                                    return writer.print("{d}", .{field_index});
                                }
                            },
                            .enum_numbered => {
                                const enum_obj = ty.castTag(.enum_numbered).?.data;
                                if (enum_obj.values.count() != 0) {
                                    const tag_val = enum_obj.values.keys()[field_index];
                                    return dg.renderValue(writer, enum_obj.tag_ty, tag_val, location);
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
                        return dg.renderValue(writer, int_tag_ty, val, location);
                    },
                }
            },
            .Fn => switch (val.tag()) {
                .function => {
                    const decl = val.castTag(.function).?.data.owner_decl;
                    return dg.renderDeclValue(writer, ty, val, decl);
                },
                .extern_fn => {
                    const decl = val.castTag(.extern_fn).?.data.owner_decl;
                    return dg.renderDeclValue(writer, ty, val, decl);
                },
                else => unreachable,
            },
            .Struct => switch (ty.containerLayout()) {
                .Auto, .Extern => {
                    const field_vals = val.castTag(.aggregate).?.data;

                    if (location != .Initializer) {
                        try writer.writeByte('(');
                        try dg.renderTypecast(writer, ty);
                        try writer.writeByte(')');
                    }

                    try writer.writeByte('{');
                    var empty = true;
                    for (field_vals) |field_val, field_index| {
                        const field_ty = ty.structFieldType(field_index);
                        if (!field_ty.hasRuntimeBits()) continue;

                        if (!empty) try writer.writeByte(',');
                        try dg.renderValue(writer, field_ty, field_val, .Initializer);

                        empty = false;
                    }
                    if (empty) try writer.print("{}", .{try dg.fmtIntLiteral(Type.u8, Value.zero)});
                    try writer.writeByte('}');
                },
                .Packed => {
                    const field_vals = val.castTag(.aggregate).?.data;
                    const int_info = ty.intInfo(target);

                    var bit_offset_ty_pl = Type.Payload.Bits{
                        .base = .{ .tag = .int_unsigned },
                        .data = Type.smallestUnsignedBits(int_info.bits - 1),
                    };
                    const bit_offset_ty = Type.initPayload(&bit_offset_ty_pl.base);

                    var bit_offset_val_pl: Value.Payload.U64 = .{ .base = .{ .tag = .int_u64 }, .data = 0 };
                    const bit_offset_val = Value.initPayload(&bit_offset_val_pl.base);

                    try writer.writeByte('(');
                    var empty = true;
                    for (field_vals) |field_val, index| {
                        const field_ty = ty.structFieldType(index);
                        if (!field_ty.hasRuntimeBitsIgnoreComptime()) continue;

                        if (!empty) try writer.writeAll(" | ");
                        try writer.writeByte('(');
                        try dg.renderTypecast(writer, ty);
                        try writer.writeByte(')');
                        try dg.renderValue(writer, field_ty, field_val, .Other);
                        try writer.writeAll(" << ");
                        try dg.renderValue(writer, bit_offset_ty, bit_offset_val, .FunctionArgument);

                        bit_offset_val_pl.data += field_ty.bitSize(target);
                        empty = false;
                    }
                    if (empty) try dg.renderValue(writer, ty, Value.undef, .Initializer);
                    try writer.writeByte(')');
                },
            },
            .Union => {
                const union_obj = val.castTag(.@"union").?.data;

                if (location != .Initializer) {
                    try writer.writeByte('(');
                    try dg.renderTypecast(writer, ty);
                    try writer.writeByte(')');
                }

                const index = ty.unionTagFieldIndex(union_obj.tag, dg.module).?;
                const field_ty = ty.unionFields().values()[index].ty;
                const field_name = ty.unionFields().keys()[index];
                if (ty.containerLayout() == .Packed) {
                    if (field_ty.hasRuntimeBits()) {
                        if (field_ty.isPtrAtRuntime()) {
                            try writer.writeByte('(');
                            try dg.renderTypecast(writer, ty);
                            try writer.writeByte(')');
                        } else if (field_ty.zigTypeTag() == .Float) {
                            try writer.writeByte('(');
                            try dg.renderTypecast(writer, ty);
                            try writer.writeByte(')');
                        }
                        try dg.renderValue(writer, field_ty, union_obj.val, .Initializer);
                    } else {
                        try writer.writeAll("0");
                    }
                    return;
                }

                try writer.writeByte('{');
                if (ty.unionTagTypeSafety()) |tag_ty| {
                    const layout = ty.unionGetLayout(target);
                    if (layout.tag_size != 0) {
                        try writer.writeAll(".tag = ");
                        try dg.renderValue(writer, tag_ty, union_obj.tag, .Initializer);
                        try writer.writeAll(", ");
                    }
                    try writer.writeAll(".payload = {");
                }

                var it = ty.unionFields().iterator();
                if (field_ty.hasRuntimeBits()) {
                    try writer.print(".{ } = ", .{fmtIdent(field_name)});
                    try dg.renderValue(writer, field_ty, union_obj.val, .Initializer);
                } else while (it.next()) |field| {
                    if (!field.value_ptr.ty.hasRuntimeBits()) continue;
                    try writer.print(".{ } = ", .{fmtIdent(field.key_ptr.*)});
                    try dg.renderValue(writer, field.value_ptr.ty, Value.undef, .Initializer);
                    break;
                } else try writer.writeAll(".empty_union = 0");
                if (ty.unionTagTypeSafety()) |_| try writer.writeByte('}');
                try writer.writeByte('}');
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

            .Frame,
            .AnyFrame,
            => |tag| return dg.fail("TODO: C backend: implement value of type {s}", .{
                @tagName(tag),
            }),
        }
    }

    fn renderFunctionSignature(dg: *DeclGen, w: anytype, kind: TypedefKind, export_index: u32) !void {
        const fn_info = dg.decl.ty.fnInfo();
        if (fn_info.cc == .Naked) try w.writeAll("zig_naked ");
        if (dg.decl.val.castTag(.function)) |func_payload|
            if (func_payload.data.is_cold) try w.writeAll("zig_cold ");

        const target = dg.module.getTarget();
        var ret_buf: LowerFnRetTyBuffer = undefined;
        const ret_ty = lowerFnRetTy(fn_info.return_type, &ret_buf, target);

        try dg.renderType(w, ret_ty, kind);
        try w.writeByte(' ');
        try dg.renderDeclName(w, dg.decl_index, export_index);
        try w.writeByte('(');

        var index: usize = 0;
        for (fn_info.param_types) |param_type| {
            if (!param_type.hasRuntimeBitsIgnoreComptime()) continue;
            if (index > 0) try w.writeAll(", ");
            const name = CValue{ .arg = index };
            try dg.renderTypeAndName(w, param_type, name, .ConstArgument, 0, kind);
            index += 1;
        }

        if (fn_info.is_var_args) {
            if (index > 0) try w.writeAll(", ");
            try w.writeAll("...");
        } else if (index == 0) {
            try dg.renderType(w, Type.void, kind);
        }
        try w.writeByte(')');
        if (fn_info.alignment > 0) try w.print(" zig_align_fn({})", .{fn_info.alignment});
    }

    fn renderPtrToFnTypedef(dg: *DeclGen, t: Type) error{ OutOfMemory, AnalysisFail }![]const u8 {
        var buffer = std.ArrayList(u8).init(dg.typedefs.allocator);
        defer buffer.deinit();
        const bw = buffer.writer();

        const fn_info = t.fnInfo();

        const target = dg.module.getTarget();
        var ret_buf: LowerFnRetTyBuffer = undefined;
        const ret_ty = lowerFnRetTy(fn_info.return_type, &ret_buf, target);

        try bw.writeAll("typedef ");
        try dg.renderType(bw, ret_ty, .Forward);
        try bw.writeAll(" (*");
        const name_begin = buffer.items.len;
        try bw.print("zig_F_{}", .{typeToCIdentifier(t, dg.module)});
        const name_end = buffer.items.len;
        try bw.writeAll(")(");

        const param_len = fn_info.param_types.len;

        var params_written: usize = 0;
        var index: usize = 0;
        while (index < param_len) : (index += 1) {
            const param_ty = fn_info.param_types[index];
            if (!param_ty.hasRuntimeBitsIgnoreComptime()) continue;
            if (params_written > 0) {
                try bw.writeAll(", ");
            }
            try dg.renderTypeAndName(bw, param_ty, .{ .bytes = "" }, .Mut, 0, .Forward);
            params_written += 1;
        }

        if (fn_info.is_var_args) {
            if (params_written != 0) try bw.writeAll(", ");
            try bw.writeAll("...");
        } else if (params_written == 0) {
            try dg.renderType(bw, Type.void, .Forward);
        }
        try bw.writeAll(");\n");

        const rendered = try buffer.toOwnedSlice();
        errdefer dg.typedefs.allocator.free(rendered);
        const name = rendered[name_begin..name_end];

        try dg.typedefs.ensureUnusedCapacity(1);
        dg.typedefs.putAssumeCapacityNoClobber(
            try t.copy(dg.typedefs_arena),
            .{ .name = name, .rendered = rendered },
        );

        return name;
    }

    fn renderSliceTypedef(dg: *DeclGen, t: Type) error{ OutOfMemory, AnalysisFail }![]const u8 {
        std.debug.assert(t.sentinel() == null); // expected canonical type

        var buffer = std.ArrayList(u8).init(dg.typedefs.allocator);
        defer buffer.deinit();
        const bw = buffer.writer();

        var ptr_ty_buf: Type.SlicePtrFieldTypeBuffer = undefined;
        const ptr_ty = t.slicePtrFieldType(&ptr_ty_buf);
        const ptr_name = CValue{ .identifier = "ptr" };
        const len_ty = Type.usize;
        const len_name = CValue{ .identifier = "len" };

        try bw.writeAll("typedef struct {\n ");
        try dg.renderTypeAndName(bw, ptr_ty, ptr_name, .Mut, 0, .Complete);
        try bw.writeAll(";\n ");
        try dg.renderTypeAndName(bw, len_ty, len_name, .Mut, 0, .Complete);

        try bw.writeAll(";\n} ");
        const name_begin = buffer.items.len;
        try bw.print("zig_{c}_{}", .{
            @as(u8, if (t.isConstPtr()) 'L' else 'M'),
            typeToCIdentifier(t.childType(), dg.module),
        });
        const name_end = buffer.items.len;
        try bw.writeAll(";\n");

        const rendered = try buffer.toOwnedSlice();
        errdefer dg.typedefs.allocator.free(rendered);
        const name = rendered[name_begin..name_end];

        try dg.typedefs.ensureUnusedCapacity(1);
        dg.typedefs.putAssumeCapacityNoClobber(
            try t.copy(dg.typedefs_arena),
            .{ .name = name, .rendered = rendered },
        );

        return name;
    }

    fn renderFwdTypedef(dg: *DeclGen, t: Type) error{ OutOfMemory, AnalysisFail }![]const u8 {
        // The forward declaration for T is stored with a key of *const T.
        const child_ty = t.childType();

        var buffer = std.ArrayList(u8).init(dg.typedefs.allocator);
        defer buffer.deinit();
        const bw = buffer.writer();

        const tag = switch (child_ty.zigTypeTag()) {
            .Struct, .ErrorUnion, .Optional => "struct",
            .Union => if (child_ty.unionTagTypeSafety()) |_| "struct" else "union",
            else => unreachable,
        };
        try bw.writeAll("typedef ");
        try bw.writeAll(tag);
        const name_begin = buffer.items.len + " ".len;
        try bw.writeAll(" zig_");
        switch (child_ty.zigTypeTag()) {
            .Struct, .Union => {
                var fqn_buf = std.ArrayList(u8).init(dg.typedefs.allocator);
                defer fqn_buf.deinit();

                const owner_decl_index = child_ty.getOwnerDecl();
                const owner_decl = dg.module.declPtr(owner_decl_index);
                try owner_decl.renderFullyQualifiedName(dg.module, fqn_buf.writer());

                try bw.print("S_{}__{d}", .{ fmtIdent(fqn_buf.items), @enumToInt(owner_decl_index) });
            },
            .ErrorUnion => {
                try bw.print("E_{}", .{typeToCIdentifier(child_ty.errorUnionPayload(), dg.module)});
            },
            .Optional => {
                var opt_buf: Type.Payload.ElemType = undefined;
                try bw.print("Q_{}", .{typeToCIdentifier(child_ty.optionalChild(&opt_buf), dg.module)});
            },
            else => unreachable,
        }
        const name_end = buffer.items.len;
        try buffer.ensureUnusedCapacity(" ".len + (name_end - name_begin) + ";\n".len);
        buffer.appendAssumeCapacity(' ');
        buffer.appendSliceAssumeCapacity(buffer.items[name_begin..name_end]);
        buffer.appendSliceAssumeCapacity(";\n");

        const rendered = try buffer.toOwnedSlice();
        errdefer dg.typedefs.allocator.free(rendered);
        const name = rendered[name_begin..name_end];

        try dg.typedefs.ensureUnusedCapacity(1);
        dg.typedefs.putAssumeCapacityNoClobber(
            try t.copy(dg.typedefs_arena),
            .{ .name = name, .rendered = rendered },
        );

        return name;
    }

    fn renderStructTypedef(dg: *DeclGen, t: Type) error{ OutOfMemory, AnalysisFail }![]const u8 {
        var ptr_pl = Type.Payload.ElemType{ .base = .{ .tag = .single_const_pointer }, .data = t };
        const ptr_ty = Type.initPayload(&ptr_pl.base);
        const name = dg.getTypedefName(ptr_ty) orelse
            try dg.renderFwdTypedef(ptr_ty);

        var buffer = std.ArrayList(u8).init(dg.typedefs.allocator);
        defer buffer.deinit();

        try buffer.appendSlice("struct ");
        try buffer.appendSlice(name);
        try buffer.appendSlice(" {\n");
        {
            var it = t.structFields().iterator();
            var empty = true;
            while (it.next()) |field| {
                const field_ty = field.value_ptr.ty;
                if (!field_ty.hasRuntimeBits()) continue;

                const alignment = field.value_ptr.abi_align;
                const field_name = CValue{ .identifier = field.key_ptr.* };
                try buffer.append(' ');
                try dg.renderTypeAndName(buffer.writer(), field_ty, field_name, .Mut, alignment, .Complete);
                try buffer.appendSlice(";\n");

                empty = false;
            }
            if (empty) try buffer.appendSlice(" char empty_struct;\n");
        }
        try buffer.appendSlice("};\n");

        const rendered = try buffer.toOwnedSlice();
        errdefer dg.typedefs.allocator.free(rendered);

        try dg.typedefs.ensureUnusedCapacity(1);
        dg.typedefs.putAssumeCapacityNoClobber(
            try t.copy(dg.typedefs_arena),
            .{ .name = name, .rendered = rendered },
        );

        return name;
    }

    fn renderTupleTypedef(dg: *DeclGen, t: Type) error{ OutOfMemory, AnalysisFail }![]const u8 {
        var buffer = std.ArrayList(u8).init(dg.typedefs.allocator);
        defer buffer.deinit();

        try buffer.appendSlice("typedef struct {\n");
        {
            const fields = t.tupleFields();
            var field_id: usize = 0;
            for (fields.types) |field_ty, i| {
                if (!field_ty.hasRuntimeBits() or fields.values[i].tag() != .unreachable_value) continue;

                try buffer.append(' ');
                try dg.renderTypeAndName(buffer.writer(), field_ty, .{ .field = field_id }, .Mut, 0, .Complete);
                try buffer.appendSlice(";\n");

                field_id += 1;
            }
            if (field_id == 0) try buffer.appendSlice(" char empty_tuple;\n");
        }
        const name_begin = buffer.items.len + "} ".len;
        try buffer.writer().print("}} zig_T_{}_{d};\n", .{ typeToCIdentifier(t, dg.module), @truncate(u16, t.hash(dg.module)) });
        const name_end = buffer.items.len - ";\n".len;

        const rendered = try buffer.toOwnedSlice();
        errdefer dg.typedefs.allocator.free(rendered);
        const name = rendered[name_begin..name_end];

        try dg.typedefs.ensureUnusedCapacity(1);
        dg.typedefs.putAssumeCapacityNoClobber(
            try t.copy(dg.typedefs_arena),
            .{ .name = name, .rendered = rendered },
        );

        return name;
    }

    fn renderUnionTypedef(dg: *DeclGen, t: Type) error{ OutOfMemory, AnalysisFail }![]const u8 {
        var ptr_pl = Type.Payload.ElemType{ .base = .{ .tag = .single_const_pointer }, .data = t };
        const ptr_ty = Type.initPayload(&ptr_pl.base);
        const name = dg.getTypedefName(ptr_ty) orelse
            try dg.renderFwdTypedef(ptr_ty);

        var buffer = std.ArrayList(u8).init(dg.typedefs.allocator);
        defer buffer.deinit();

        try buffer.appendSlice(if (t.unionTagTypeSafety()) |_| "struct " else "union ");
        try buffer.appendSlice(name);
        try buffer.appendSlice(" {\n");

        const indent = if (t.unionTagTypeSafety()) |tag_ty| indent: {
            const target = dg.module.getTarget();
            const layout = t.unionGetLayout(target);
            if (layout.tag_size != 0) {
                try buffer.append(' ');
                try dg.renderTypeAndName(buffer.writer(), tag_ty, .{ .identifier = "tag" }, .Mut, 0, .Complete);
                try buffer.appendSlice(";\n");
            }
            try buffer.appendSlice(" union {\n");
            break :indent "  ";
        } else " ";

        {
            var it = t.unionFields().iterator();
            var empty = true;
            while (it.next()) |field| {
                const field_ty = field.value_ptr.ty;
                if (!field_ty.hasRuntimeBits()) continue;

                const alignment = field.value_ptr.abi_align;
                const field_name = CValue{ .identifier = field.key_ptr.* };
                try buffer.appendSlice(indent);
                try dg.renderTypeAndName(buffer.writer(), field_ty, field_name, .Mut, alignment, .Complete);
                try buffer.appendSlice(";\n");

                empty = false;
            }
            if (empty) {
                try buffer.appendSlice(indent);
                try buffer.appendSlice("char empty_union;\n");
            }
        }

        if (t.unionTagTypeSafety()) |_| try buffer.appendSlice(" } payload;\n");
        try buffer.appendSlice("};\n");

        const rendered = try buffer.toOwnedSlice();
        errdefer dg.typedefs.allocator.free(rendered);

        try dg.typedefs.ensureUnusedCapacity(1);
        dg.typedefs.putAssumeCapacityNoClobber(
            try t.copy(dg.typedefs_arena),
            .{ .name = name, .rendered = rendered },
        );

        return name;
    }

    fn renderErrorUnionTypedef(dg: *DeclGen, t: Type) error{ OutOfMemory, AnalysisFail }![]const u8 {
        assert(t.errorUnionSet().tag() == .anyerror);

        var ptr_pl = Type.Payload.ElemType{ .base = .{ .tag = .single_const_pointer }, .data = t };
        const ptr_ty = Type.initPayload(&ptr_pl.base);
        const name = dg.getTypedefName(ptr_ty) orelse
            try dg.renderFwdTypedef(ptr_ty);

        var buffer = std.ArrayList(u8).init(dg.typedefs.allocator);
        defer buffer.deinit();
        const bw = buffer.writer();

        const payload_ty = t.errorUnionPayload();
        const payload_name = CValue{ .identifier = "payload" };
        const error_ty = t.errorUnionSet();
        const error_name = CValue{ .identifier = "error" };

        const target = dg.module.getTarget();
        const payload_align = payload_ty.abiAlignment(target);
        const error_align = error_ty.abiAlignment(target);
        try bw.writeAll("struct ");
        try bw.writeAll(name);
        try bw.writeAll(" {\n ");
        if (error_align > payload_align) {
            try dg.renderTypeAndName(bw, payload_ty, payload_name, .Mut, 0, .Complete);
            try bw.writeAll(";\n ");
            try dg.renderTypeAndName(bw, error_ty, error_name, .Mut, 0, .Complete);
        } else {
            try dg.renderTypeAndName(bw, error_ty, error_name, .Mut, 0, .Complete);
            try bw.writeAll(";\n ");
            try dg.renderTypeAndName(bw, payload_ty, payload_name, .Mut, 0, .Complete);
        }
        try bw.writeAll(";\n};\n");

        const rendered = try buffer.toOwnedSlice();
        errdefer dg.typedefs.allocator.free(rendered);

        try dg.typedefs.ensureUnusedCapacity(1);
        dg.typedefs.putAssumeCapacityNoClobber(
            try t.copy(dg.typedefs_arena),
            .{ .name = name, .rendered = rendered },
        );

        return name;
    }

    fn renderArrayTypedef(dg: *DeclGen, t: Type) error{ OutOfMemory, AnalysisFail }![]const u8 {
        const info = t.arrayInfo();
        std.debug.assert(info.sentinel == null); // expected canonical type

        var buffer = std.ArrayList(u8).init(dg.typedefs.allocator);
        defer buffer.deinit();
        const bw = buffer.writer();

        try bw.writeAll("typedef ");
        try dg.renderType(bw, info.elem_type, .Complete);

        const name_begin = buffer.items.len + " ".len;
        try bw.print(" zig_A_{}_{d}", .{ typeToCIdentifier(info.elem_type, dg.module), info.len });
        const name_end = buffer.items.len;

        const c_len = if (info.len > 0) info.len else 1;
        var c_len_pl: Value.Payload.U64 = .{ .base = .{ .tag = .int_u64 }, .data = c_len };
        const c_len_val = Value.initPayload(&c_len_pl.base);
        try bw.print("[{}];\n", .{try dg.fmtIntLiteral(Type.usize, c_len_val)});

        const rendered = try buffer.toOwnedSlice();
        errdefer dg.typedefs.allocator.free(rendered);
        const name = rendered[name_begin..name_end];

        try dg.typedefs.ensureUnusedCapacity(1);
        dg.typedefs.putAssumeCapacityNoClobber(
            try t.copy(dg.typedefs_arena),
            .{ .name = name, .rendered = rendered },
        );

        return name;
    }

    fn renderOptionalTypedef(dg: *DeclGen, t: Type) error{ OutOfMemory, AnalysisFail }![]const u8 {
        var ptr_pl = Type.Payload.ElemType{ .base = .{ .tag = .single_const_pointer }, .data = t };
        const ptr_ty = Type.initPayload(&ptr_pl.base);
        const name = dg.getTypedefName(ptr_ty) orelse
            try dg.renderFwdTypedef(ptr_ty);

        var buffer = std.ArrayList(u8).init(dg.typedefs.allocator);
        defer buffer.deinit();
        const bw = buffer.writer();

        var opt_buf: Type.Payload.ElemType = undefined;
        const child_ty = t.optionalChild(&opt_buf);

        try bw.writeAll("struct ");
        try bw.writeAll(name);
        try bw.writeAll(" {\n");
        try dg.renderTypeAndName(bw, child_ty, .{ .identifier = "payload" }, .Mut, 0, .Complete);
        try bw.writeAll(";\n ");
        try dg.renderTypeAndName(bw, Type.bool, .{ .identifier = "is_null" }, .Mut, 0, .Complete);
        try bw.writeAll(";\n};\n");

        const rendered = try buffer.toOwnedSlice();
        errdefer dg.typedefs.allocator.free(rendered);

        try dg.typedefs.ensureUnusedCapacity(1);
        dg.typedefs.putAssumeCapacityNoClobber(
            try t.copy(dg.typedefs_arena),
            .{ .name = name, .rendered = rendered },
        );

        return name;
    }

    fn renderOpaqueTypedef(dg: *DeclGen, t: Type) error{ OutOfMemory, AnalysisFail }![]const u8 {
        const opaque_ty = t.cast(Type.Payload.Opaque).?.data;
        const unqualified_name = dg.module.declPtr(opaque_ty.owner_decl).name;
        const fqn = try opaque_ty.getFullyQualifiedName(dg.module);
        defer dg.typedefs.allocator.free(fqn);

        var buffer = std.ArrayList(u8).init(dg.typedefs.allocator);
        defer buffer.deinit();

        try buffer.writer().print("typedef struct { } ", .{fmtIdent(std.mem.span(unqualified_name))});

        const name_begin = buffer.items.len;
        try buffer.writer().print("zig_O_{}", .{fmtIdent(fqn)});
        const name_end = buffer.items.len;
        try buffer.appendSlice(";\n");

        const rendered = try buffer.toOwnedSlice();
        errdefer dg.typedefs.allocator.free(rendered);
        const name = rendered[name_begin..name_end];

        try dg.typedefs.ensureUnusedCapacity(1);
        dg.typedefs.putAssumeCapacityNoClobber(
            try t.copy(dg.typedefs_arena),
            .{ .name = name, .rendered = rendered },
        );

        return name;
    }

    /// Renders a type as a single identifier, generating intermediate typedefs
    /// if necessary.
    ///
    /// This is guaranteed to be valid in both typedefs and declarations/definitions.
    ///
    /// There are three type formats in total that we support rendering:
    ///   | Function            | Example 1 (*u8) | Example 2 ([10]*u8) |
    ///   |---------------------|-----------------|---------------------|
    ///   | `renderTypecast`    | "uint8_t *"     | "uint8_t *[10]"     |
    ///   | `renderTypeAndName` | "uint8_t *name" | "uint8_t *name[10]" |
    ///   | `renderType`        | "uint8_t *"     | "zig_A_uint8_t_10"  |
    ///
    fn renderType(
        dg: *DeclGen,
        w: anytype,
        t: Type,
        kind: TypedefKind,
    ) error{ OutOfMemory, AnalysisFail }!void {
        const target = dg.module.getTarget();

        switch (t.zigTypeTag()) {
            .Void => try w.writeAll("void"),
            .Bool => try w.writeAll("bool"),
            .NoReturn, .Float => {
                try w.writeAll("zig_");
                try t.print(w, dg.module);
            },
            .Int => {
                if (t.isNamedInt()) {
                    try w.writeAll("zig_");
                    try t.print(w, dg.module);
                } else {
                    return renderTypeUnnamed(dg, w, t, kind);
                }
            },
            .ErrorSet => {
                return renderTypeUnnamed(dg, w, t, kind);
            },
            .Pointer => {
                const ptr_info = t.ptrInfo().data;
                if (ptr_info.size == .Slice) {
                    var slice_pl = Type.Payload.ElemType{
                        .base = .{ .tag = if (t.ptrIsMutable()) .mut_slice else .const_slice },
                        .data = ptr_info.pointee_type,
                    };
                    const slice_ty = Type.initPayload(&slice_pl.base);

                    const name = dg.getTypedefName(slice_ty) orelse
                        try dg.renderSliceTypedef(slice_ty);

                    return w.writeAll(name);
                }

                if (ptr_info.pointee_type.zigTypeTag() == .Fn) {
                    const name = dg.getTypedefName(ptr_info.pointee_type) orelse
                        try dg.renderPtrToFnTypedef(ptr_info.pointee_type);

                    return w.writeAll(name);
                }

                if (ptr_info.host_size != 0) {
                    var host_pl = Type.Payload.Bits{
                        .base = .{ .tag = .int_unsigned },
                        .data = ptr_info.host_size * 8,
                    };
                    const host_ty = Type.initPayload(&host_pl.base);

                    try dg.renderType(w, host_ty, .Forward);
                } else if (t.isCPtr() and ptr_info.pointee_type.eql(Type.u8, dg.module) and
                    (dg.decl.val.tag() == .extern_fn or
                    std.mem.eql(u8, std.mem.span(dg.decl.name), "main")))
                {
                    // This is a hack, since the c compiler expects a lot of external
                    // library functions to have char pointers in their signatures, but
                    // u8 and i8 produce unsigned char and signed char respectively,
                    // which in C are (not very usefully) different than char.
                    try w.writeAll("char");
                } else try dg.renderType(w, switch (ptr_info.pointee_type.tag()) {
                    .anyopaque => Type.void,
                    else => ptr_info.pointee_type,
                }, .Forward);
                if (t.isConstPtr()) try w.writeAll(" const");
                if (t.isVolatilePtr()) try w.writeAll(" volatile");
                return w.writeAll(" *");
            },
            .Array, .Vector => {
                var array_pl = Type.Payload.Array{ .base = .{ .tag = .array }, .data = .{
                    .len = t.arrayLenIncludingSentinel(),
                    .elem_type = t.childType(),
                } };
                const array_ty = Type.initPayload(&array_pl.base);

                const name = dg.getTypedefName(array_ty) orelse
                    try dg.renderArrayTypedef(array_ty);

                return w.writeAll(name);
            },
            .Optional => {
                var opt_buf: Type.Payload.ElemType = undefined;
                const child_ty = t.optionalChild(&opt_buf);

                if (!child_ty.hasRuntimeBitsIgnoreComptime())
                    return dg.renderType(w, Type.bool, kind);

                if (t.optionalReprIsPayload())
                    return dg.renderType(w, child_ty, kind);

                switch (kind) {
                    .Complete => {
                        const name = dg.getTypedefName(t) orelse
                            try dg.renderOptionalTypedef(t);

                        try w.writeAll(name);
                    },
                    .Forward => {
                        var ptr_pl = Type.Payload.ElemType{
                            .base = .{ .tag = .single_const_pointer },
                            .data = t,
                        };
                        const ptr_ty = Type.initPayload(&ptr_pl.base);

                        const name = dg.getTypedefName(ptr_ty) orelse
                            try dg.renderFwdTypedef(ptr_ty);

                        try w.writeAll(name);
                    },
                }
            },
            .ErrorUnion => {
                const payload_ty = t.errorUnionPayload();

                if (!payload_ty.hasRuntimeBitsIgnoreComptime())
                    return dg.renderType(w, Type.anyerror, kind);

                var error_union_pl = Type.Payload.ErrorUnion{
                    .data = .{ .error_set = Type.anyerror, .payload = payload_ty },
                };
                const error_union_ty = Type.initPayload(&error_union_pl.base);

                switch (kind) {
                    .Complete => {
                        const name = dg.getTypedefName(error_union_ty) orelse
                            try dg.renderErrorUnionTypedef(error_union_ty);

                        try w.writeAll(name);
                    },
                    .Forward => {
                        var ptr_pl = Type.Payload.ElemType{
                            .base = .{ .tag = .single_const_pointer },
                            .data = error_union_ty,
                        };
                        const ptr_ty = Type.initPayload(&ptr_pl.base);

                        const name = dg.getTypedefName(ptr_ty) orelse
                            try dg.renderFwdTypedef(ptr_ty);

                        try w.writeAll(name);
                    },
                }
            },
            .Struct, .Union => |tag| if (t.containerLayout() == .Packed) {
                if (t.castTag(.@"struct")) |struct_obj| {
                    try dg.renderType(w, struct_obj.data.backing_int_ty, kind);
                } else {
                    var buf: Type.Payload.Bits = .{
                        .base = .{ .tag = .int_unsigned },
                        .data = @intCast(u16, t.bitSize(target)),
                    };
                    try dg.renderType(w, Type.initPayload(&buf.base), kind);
                }
            } else if (t.isSimpleTupleOrAnonStruct()) {
                const ExpectedContents = struct { types: [8]Type, values: [8]Value };
                var stack align(@alignOf(ExpectedContents)) =
                    std.heap.stackFallback(@sizeOf(ExpectedContents), dg.gpa);
                const allocator = stack.get();

                var tuple_storage = std.MultiArrayList(struct { type: Type, value: Value }){};
                defer tuple_storage.deinit(allocator);
                try tuple_storage.ensureTotalCapacity(allocator, t.structFieldCount());

                const fields = t.tupleFields();
                for (fields.values) |value, index|
                    if (value.tag() == .unreachable_value)
                        tuple_storage.appendAssumeCapacity(.{
                            .type = fields.types[index],
                            .value = value,
                        });

                const tuple_slice = tuple_storage.slice();
                var tuple_pl = Type.Payload.Tuple{ .data = .{
                    .types = tuple_slice.items(.type),
                    .values = tuple_slice.items(.value),
                } };
                const tuple_ty = Type.initPayload(&tuple_pl.base);

                const name = dg.getTypedefName(tuple_ty) orelse
                    try dg.renderTupleTypedef(tuple_ty);

                try w.writeAll(name);
            } else switch (kind) {
                .Complete => {
                    const name = dg.getTypedefName(t) orelse switch (tag) {
                        .Struct => try dg.renderStructTypedef(t),
                        .Union => try dg.renderUnionTypedef(t),
                        else => unreachable,
                    };

                    try w.writeAll(name);
                },
                .Forward => {
                    var ptr_pl = Type.Payload.ElemType{
                        .base = .{ .tag = .single_const_pointer },
                        .data = t,
                    };
                    const ptr_ty = Type.initPayload(&ptr_pl.base);

                    const name = dg.getTypedefName(ptr_ty) orelse
                        try dg.renderFwdTypedef(ptr_ty);

                    try w.writeAll(name);
                },
            },
            .Enum => {
                // For enums, we simply use the integer tag type.
                var int_tag_buf: Type.Payload.Bits = undefined;
                const int_tag_ty = t.intTagType(&int_tag_buf);

                try dg.renderType(w, int_tag_ty, kind);
            },
            .Opaque => switch (t.tag()) {
                .@"opaque" => {
                    const name = dg.getTypedefName(t) orelse
                        try dg.renderOpaqueTypedef(t);

                    try w.writeAll(name);
                },
                else => unreachable,
            },

            .Frame,
            .AnyFrame,
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

    fn renderTypeUnnamed(
        dg: *DeclGen,
        w: anytype,
        t: Type,
        kind: TypedefKind,
    ) error{ OutOfMemory, AnalysisFail }!void {
        const target = dg.module.getTarget();
        const int_info = t.intInfo(target);
        if (toCIntBits(int_info.bits)) |c_bits|
            return w.print("zig_{c}{d}", .{ signAbbrev(int_info.signedness), c_bits })
        else if (loweredArrayInfo(t, target)) |array_info| {
            assert(array_info.sentinel == null);
            var array_pl = Type.Payload.Array{
                .base = .{ .tag = .array },
                .data = .{ .len = array_info.len, .elem_type = array_info.elem_type },
            };
            const array_ty = Type.initPayload(&array_pl.base);

            return dg.renderType(w, array_ty, kind);
        } else return dg.fail("C backend: Unable to lower unnamed integer type {}", .{
            t.fmt(dg.module),
        });
    }

    /// Renders a type in C typecast format.
    ///
    /// This is guaranteed to be valid in a typecast expression, but not
    /// necessarily in a variable/field declaration.
    ///
    /// There are three type formats in total that we support rendering:
    ///   | Function            | Example 1 (*u8) | Example 2 ([10]*u8) |
    ///   |---------------------|-----------------|---------------------|
    ///   | `renderTypecast`    | "uint8_t *"     | "uint8_t *[10]"     |
    ///   | `renderTypeAndName` | "uint8_t *name" | "uint8_t *name[10]" |
    ///   | `renderType`        | "uint8_t *"     | "zig_A_uint8_t_10"  |
    ///
    fn renderTypecast(dg: *DeclGen, w: anytype, ty: Type) error{ OutOfMemory, AnalysisFail }!void {
        return renderTypeAndName(dg, w, ty, .{ .bytes = "" }, .Mut, 0, .Complete);
    }

    /// Renders a type and name in field declaration/definition format.
    ///
    /// There are three type formats in total that we support rendering:
    ///   | Function            | Example 1 (*u8) | Example 2 ([10]*u8) |
    ///   |---------------------|-----------------|---------------------|
    ///   | `renderTypecast`    | "uint8_t *"     | "uint8_t *[10]"     |
    ///   | `renderTypeAndName` | "uint8_t *name" | "uint8_t *name[10]" |
    ///   | `renderType`        | "uint8_t *"     | "zig_A_uint8_t_10"  |
    ///
    fn renderTypeAndName(
        dg: *DeclGen,
        w: anytype,
        ty: Type,
        name: CValue,
        mutability: Mutability,
        alignment: u32,
        kind: TypedefKind,
    ) error{ OutOfMemory, AnalysisFail }!void {
        var suffix = std.ArrayList(u8).init(dg.gpa);
        defer suffix.deinit();
        const suffix_writer = suffix.writer();

        // Any top-level array types are rendered here as a suffix, which
        // avoids creating typedefs for every array type
        const target = dg.module.getTarget();
        var render_ty = ty;
        var depth: u32 = 0;
        while (loweredArrayInfo(render_ty, target)) |array_info| {
            const c_len = array_info.len + @boolToInt(array_info.sentinel != null);
            var c_len_pl: Value.Payload.U64 = .{ .base = .{ .tag = .int_u64 }, .data = c_len };
            const c_len_val = Value.initPayload(&c_len_pl.base);

            try suffix_writer.writeByte('[');
            if (mutability == .ConstArgument and depth == 0) try suffix_writer.writeAll("static const ");
            try suffix.writer().print("{}]", .{try dg.fmtIntLiteral(Type.usize, c_len_val)});
            render_ty = array_info.elem_type;
            depth += 1;
        }

        if (alignment != 0 and alignment > ty.abiAlignment(target)) {
            try w.print("zig_align({}) ", .{alignment});
        }
        try dg.renderType(w, render_ty, kind);

        const const_prefix = switch (mutability) {
            .Const, .ConstArgument => "const ",
            .Mut => "",
        };
        try w.print(" {s}", .{const_prefix});
        try dg.writeCValue(w, name);
        try w.writeAll(suffix.items);
    }

    fn renderTagNameFn(dg: *DeclGen, enum_ty: Type) error{ OutOfMemory, AnalysisFail }![]const u8 {
        var buffer = std.ArrayList(u8).init(dg.typedefs.allocator);
        defer buffer.deinit();
        const bw = buffer.writer();

        const name_slice_ty = Type.initTag(.const_slice_u8_sentinel_0);

        try buffer.appendSlice("static ");
        try dg.renderType(bw, name_slice_ty, .Complete);
        const name_begin = buffer.items.len + " ".len;
        try bw.print(" zig_tagName_{}_{d}(", .{ typeToCIdentifier(enum_ty, dg.module), @enumToInt(enum_ty.getOwnerDecl()) });
        const name_end = buffer.items.len - "(".len;
        try dg.renderTypeAndName(bw, enum_ty, .{ .identifier = "tag" }, .Const, 0, .Complete);
        try buffer.appendSlice(") {\n switch (tag) {\n");
        for (enum_ty.enumFields().keys()) |name, index| {
            const name_z = try dg.typedefs.allocator.dupeZ(u8, name);
            defer dg.typedefs.allocator.free(name_z);
            const name_bytes = name_z[0 .. name_z.len + 1];

            var tag_pl: Value.Payload.U32 = .{
                .base = .{ .tag = .enum_field_index },
                .data = @intCast(u32, index),
            };
            const tag_val = Value.initPayload(&tag_pl.base);

            var int_pl: Value.Payload.U64 = undefined;
            const int_val = tag_val.enumToInt(enum_ty, &int_pl);

            var name_ty_pl = Type.Payload.Len{ .base = .{ .tag = .array_u8_sentinel_0 }, .data = name.len };
            const name_ty = Type.initPayload(&name_ty_pl.base);

            var name_pl = Value.Payload.Bytes{ .base = .{ .tag = .bytes }, .data = name_bytes };
            const name_val = Value.initPayload(&name_pl.base);

            var len_pl = Value.Payload.U64{ .base = .{ .tag = .int_u64 }, .data = name.len };
            const len_val = Value.initPayload(&len_pl.base);

            try bw.print("  case {}: {{\n   static ", .{try dg.fmtIntLiteral(enum_ty, int_val)});
            try dg.renderTypeAndName(bw, name_ty, .{ .identifier = "name" }, .Const, 0, .Complete);
            try buffer.appendSlice(" = ");
            try dg.renderValue(bw, name_ty, name_val, .Initializer);
            try buffer.appendSlice(";\n   return (");
            try dg.renderTypecast(bw, name_slice_ty);
            try bw.print("){{{}, {}}};\n", .{
                fmtIdent("name"), try dg.fmtIntLiteral(Type.usize, len_val),
            });

            try buffer.appendSlice("  }\n");
        }
        try buffer.appendSlice(" }\n while (");
        try dg.renderValue(bw, Type.bool, Value.true, .Other);
        try buffer.appendSlice(") ");
        _ = try airBreakpoint(bw);
        try buffer.appendSlice("}\n");

        const rendered = try buffer.toOwnedSlice();
        errdefer dg.typedefs.allocator.free(rendered);
        const name = rendered[name_begin..name_end];

        try dg.typedefs.ensureUnusedCapacity(1);
        dg.typedefs.putAssumeCapacityNoClobber(
            try enum_ty.copy(dg.typedefs_arena),
            .{ .name = name, .rendered = rendered },
        );

        return name;
    }

    fn getTagNameFn(dg: *DeclGen, enum_ty: Type) ![]const u8 {
        return dg.getTypedefName(enum_ty) orelse
            try dg.renderTagNameFn(enum_ty);
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

    fn writeCValue(dg: *DeclGen, w: anytype, c_value: CValue) !void {
        switch (c_value) {
            .none => unreachable,
            .local => |i| return w.print("t{d}", .{i}),
            .local_ref => |i| return w.print("&t{d}", .{i}),
            .constant => unreachable,
            .arg => |i| return w.print("a{d}", .{i}),
            .field => |i| return w.print("f{d}", .{i}),
            .decl => |decl| return dg.renderDeclName(w, decl, 0),
            .decl_ref => |decl| {
                try w.writeByte('&');
                return dg.renderDeclName(w, decl, 0);
            },
            .undef => |ty| return dg.renderValue(w, ty, Value.undef, .Other),
            .identifier => |ident| return w.print("{ }", .{fmtIdent(ident)}),
            .bytes => |bytes| return w.writeAll(bytes),
        }
    }

    fn writeCValueDeref(dg: *DeclGen, w: anytype, c_value: CValue) !void {
        switch (c_value) {
            .none => unreachable,
            .local => |i| return w.print("(*t{d})", .{i}),
            .local_ref => |i| return w.print("t{d}", .{i}),
            .constant => unreachable,
            .arg => |i| return w.print("(*a{d})", .{i}),
            .field => |i| return w.print("f{d}", .{i}),
            .decl => |decl| {
                try w.writeAll("(*");
                try dg.renderDeclName(w, decl, 0);
                return w.writeByte(')');
            },
            .decl_ref => |decl| return dg.renderDeclName(w, decl, 0),
            .undef => unreachable,
            .identifier => |ident| return w.print("(*{ })", .{fmtIdent(ident)}),
            .bytes => |bytes| {
                try w.writeAll("(*");
                try w.writeAll(bytes);
                return w.writeByte(')');
            },
        }
    }

    fn writeCValueMember(dg: *DeclGen, writer: anytype, c_value: CValue, member: CValue) !void {
        try dg.writeCValue(writer, c_value);
        try writer.writeByte('.');
        try dg.writeCValue(writer, member);
    }

    fn writeCValueDerefMember(dg: *DeclGen, writer: anytype, c_value: CValue, member: CValue) !void {
        switch (c_value) {
            .none, .constant, .field, .undef => unreachable,
            .local, .arg, .decl, .identifier, .bytes => {
                try dg.writeCValue(writer, c_value);
                try writer.writeAll("->");
            },
            .local_ref, .decl_ref => {
                try dg.writeCValueDeref(writer, c_value);
                try writer.writeByte('.');
            },
        }
        try dg.writeCValue(writer, member);
    }

    fn renderDeclName(dg: *DeclGen, writer: anytype, decl_index: Decl.Index, export_index: u32) !void {
        const decl = dg.module.declPtr(decl_index);
        dg.module.markDeclAlive(decl);

        if (dg.module.decl_exports.get(decl_index)) |exports| {
            return writer.writeAll(exports.items[export_index].options.name);
        } else if (decl.isExtern()) {
            return writer.writeAll(mem.sliceTo(decl.name, 0));
        } else if (dg.module.test_functions.get(decl_index)) |_| {
            const gpa = dg.gpa;
            const name = try decl.getFullyQualifiedName(dg.module);
            defer gpa.free(name);
            return writer.print("{}_{d}", .{ fmtIdent(name), @enumToInt(decl_index) });
        } else {
            const gpa = dg.gpa;
            const name = try decl.getFullyQualifiedName(dg.module);
            defer gpa.free(name);
            return writer.print("{}", .{fmtIdent(name)});
        }
    }

    fn renderTypeForBuiltinFnName(dg: *DeclGen, writer: anytype, ty: Type) !void {
        const target = dg.module.getTarget();
        if (ty.isAbiInt()) {
            const int_info = ty.intInfo(target);
            const c_bits = toCIntBits(int_info.bits) orelse
                return dg.fail("TODO: C backend: implement integer types larger than 128 bits", .{});
            try writer.print("{c}{d}", .{ signAbbrev(int_info.signedness), c_bits });
        } else if (ty.isRuntimeFloat()) {
            try ty.print(writer, dg.module);
        } else return dg.fail("TODO: CBE: implement renderTypeForBuiltinFnName for type {}", .{
            ty.fmt(dg.module),
        });
    }

    fn renderBuiltinInfo(dg: *DeclGen, writer: anytype, ty: Type, info: BuiltinInfo) !void {
        const target = dg.module.getTarget();
        switch (info) {
            .None => {},
            .Range => {
                var arena = std.heap.ArenaAllocator.init(dg.gpa);
                defer arena.deinit();

                const ExpectedContents = union { u: Value.Payload.U64, i: Value.Payload.I64 };
                var stack align(@alignOf(ExpectedContents)) =
                    std.heap.stackFallback(@sizeOf(ExpectedContents), arena.allocator());

                const int_info = ty.intInfo(target);
                if (int_info.signedness == .signed) {
                    const min_val = try ty.minInt(stack.get(), target);
                    try writer.print(", {x}", .{try dg.fmtIntLiteral(ty, min_val)});
                }

                const max_val = try ty.maxInt(stack.get(), target);
                try writer.print(", {x}", .{try dg.fmtIntLiteral(ty, max_val)});
            },
            .Bits => {
                var bits_pl = Value.Payload.U64{
                    .base = .{ .tag = .int_u64 },
                    .data = ty.bitSize(target),
                };
                const bits_val = Value.initPayload(&bits_pl.base);
                try writer.print(", {}", .{try dg.fmtIntLiteral(Type.u8, bits_val)});
            },
        }
    }

    fn fmtIntLiteral(
        dg: *DeclGen,
        ty: Type,
        val: Value,
    ) !std.fmt.Formatter(formatIntLiteral) {
        const int_info = ty.intInfo(dg.module.getTarget());
        const c_bits = toCIntBits(int_info.bits);
        if (c_bits == null or c_bits.? > 128)
            return dg.fail("TODO implement integer constants larger than 128 bits", .{});
        return std.fmt.Formatter(formatIntLiteral){ .data = .{
            .ty = ty,
            .val = val,
            .mod = dg.module,
        } };
    }
};

pub fn genGlobalAsm(mod: *Module, code: *std.ArrayList(u8)) !void {
    var it = mod.global_assembly.valueIterator();
    while (it.next()) |asm_source| {
        try code.writer().print("__asm({s});\n", .{fmtStringLiteral(asm_source.*)});
    }
}

pub fn genErrDecls(o: *Object) !void {
    const writer = o.writer();

    try writer.writeAll("enum {\n");
    o.indent_writer.pushIndent();
    var max_name_len: usize = 0;
    for (o.dg.module.error_name_list.items) |name, value| {
        max_name_len = std.math.max(name.len, max_name_len);
        var err_pl = Value.Payload.Error{ .data = .{ .name = name } };
        try o.dg.renderValue(writer, Type.anyerror, Value.initPayload(&err_pl.base), .Other);
        try writer.print(" = {d}u,\n", .{value});
    }
    o.indent_writer.popIndent();
    try writer.writeAll("};\n");

    const name_prefix = "zig_errorName";
    const name_buf = try o.dg.gpa.alloc(u8, name_prefix.len + "_".len + max_name_len + 1);
    defer o.dg.gpa.free(name_buf);

    std.mem.copy(u8, name_buf, name_prefix ++ "_");
    for (o.dg.module.error_name_list.items) |name| {
        std.mem.copy(u8, name_buf[name_prefix.len + "_".len ..], name);
        name_buf[name_prefix.len + "_".len + name.len] = 0;

        const identifier = name_buf[0 .. name_prefix.len + "_".len + name.len :0];
        const name_z = identifier[name_prefix.len + "_".len ..];

        var name_ty_pl = Type.Payload.Len{ .base = .{ .tag = .array_u8_sentinel_0 }, .data = name.len };
        const name_ty = Type.initPayload(&name_ty_pl.base);

        var name_pl = Value.Payload.Bytes{ .base = .{ .tag = .bytes }, .data = name_z };
        const name_val = Value.initPayload(&name_pl.base);

        try writer.writeAll("static ");
        try o.dg.renderTypeAndName(writer, name_ty, .{ .identifier = identifier }, .Const, 0, .Complete);
        try writer.writeAll(" = ");
        try o.dg.renderValue(writer, name_ty, name_val, .Initializer);
        try writer.writeAll(";\n");
    }

    var name_array_ty_pl = Type.Payload.Array{ .base = .{ .tag = .array }, .data = .{
        .len = o.dg.module.error_name_list.items.len,
        .elem_type = Type.initTag(.const_slice_u8_sentinel_0),
    } };
    const name_array_ty = Type.initPayload(&name_array_ty_pl.base);

    try writer.writeAll("static ");
    try o.dg.renderTypeAndName(writer, name_array_ty, .{ .identifier = name_prefix }, .Const, 0, .Complete);
    try writer.writeAll(" = {");
    for (o.dg.module.error_name_list.items) |name, value| {
        if (value != 0) try writer.writeByte(',');

        var len_pl = Value.Payload.U64{ .base = .{ .tag = .int_u64 }, .data = name.len };
        const len_val = Value.initPayload(&len_pl.base);

        try writer.print("{{" ++ name_prefix ++ "_{}, {}}}", .{
            fmtIdent(name), try o.dg.fmtIntLiteral(Type.usize, len_val),
        });
    }
    try writer.writeAll("};\n");
}

fn genExports(o: *Object) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const fwd_decl_writer = o.dg.fwd_decl.writer();
    if (o.dg.module.decl_exports.get(o.dg.decl_index)) |exports| for (exports.items[1..]) |@"export", i| {
        try fwd_decl_writer.writeAll("zig_export(");
        try o.dg.renderFunctionSignature(fwd_decl_writer, .Forward, @intCast(u32, 1 + i));
        try fwd_decl_writer.print(", {s}, {s});\n", .{
            fmtStringLiteral(exports.items[0].options.name),
            fmtStringLiteral(@"export".options.name),
        });
    };
}

pub fn genFunc(f: *Function) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const o = &f.object;
    const gpa = o.dg.gpa;
    const tv: TypedValue = .{
        .ty = o.dg.decl.ty,
        .val = o.dg.decl.val,
    };

    o.code_header = std.ArrayList(u8).init(gpa);
    defer o.code_header.deinit();

    const is_global = o.dg.declIsGlobal(tv);
    const fwd_decl_writer = o.dg.fwd_decl.writer();
    try fwd_decl_writer.writeAll(if (is_global) "zig_extern " else "static ");
    try o.dg.renderFunctionSignature(fwd_decl_writer, .Forward, 0);
    try fwd_decl_writer.writeAll(";\n");
    try genExports(o);

    try o.indent_writer.insertNewline();
    if (!is_global) try o.writer().writeAll("static ");
    try o.dg.renderFunctionSignature(o.writer(), .Complete, 0);
    try o.writer().writeByte(' ');

    // In case we need to use the header, populate it with a copy of the function
    // signature here. We anticipate a brace, newline, and space.
    try o.code_header.ensureUnusedCapacity(o.code.items.len + 3);
    o.code_header.appendSliceAssumeCapacity(o.code.items);
    o.code_header.appendSliceAssumeCapacity("{\n ");
    const empty_header_len = o.code_header.items.len;

    f.free_locals_stack.clearRetainingCapacity();
    try f.free_locals_stack.append(gpa, .{});

    const main_body = f.air.getMainBody();
    try genBody(f, main_body);

    try o.indent_writer.insertNewline();

    // Take advantage of the free_locals map to bucket locals per type. All
    // locals corresponding to AIR instructions should be in there due to
    // Liveness analysis, however, locals from alloc instructions will be
    // missing. These are added now to complete the map. Then we can sort by
    // alignment, descending.
    const free_locals = f.getFreeLocals();
    const values = f.allocs.values();
    for (f.allocs.keys()) |local_index, i| {
        if (values[i]) continue; // static
        const local = f.locals.items[local_index];
        log.debug("inserting local {d} into free_locals", .{local_index});
        const gop = try free_locals.getOrPutContext(gpa, local.ty, f.tyHashCtx());
        if (!gop.found_existing) gop.value_ptr.* = .{};
        try gop.value_ptr.append(gpa, local_index);
    }

    const SortContext = struct {
        target: std.Target,
        keys: []const Type,

        pub fn lessThan(ctx: @This(), a_index: usize, b_index: usize) bool {
            const a_ty = ctx.keys[a_index];
            const b_ty = ctx.keys[b_index];
            return b_ty.abiAlignment(ctx.target) < a_ty.abiAlignment(ctx.target);
        }
    };
    const target = o.dg.module.getTarget();
    free_locals.sort(SortContext{ .target = target, .keys = free_locals.keys() });

    const w = o.code_header.writer();
    for (free_locals.values()) |list| {
        for (list.items) |local_index| {
            const local = f.locals.items[local_index];
            try o.dg.renderTypeAndName(
                w,
                local.ty,
                .{ .local = local_index },
                .Mut,
                local.alignment,
                .Complete,
            );
            try w.writeAll(";\n ");
        }
    }

    // If we have a header to insert, append the body to the header
    // and then return the result, freeing the body.
    if (o.code_header.items.len > empty_header_len) {
        try o.code_header.appendSlice(o.code.items[empty_header_len..]);
        mem.swap(std.ArrayList(u8), &o.code, &o.code_header);
    }
}

pub fn genDecl(o: *Object) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const tv: TypedValue = .{
        .ty = o.dg.decl.ty,
        .val = o.dg.decl.val,
    };
    if (!tv.ty.isFnOrHasRuntimeBitsIgnoreComptime()) return;
    if (tv.val.tag() == .extern_fn) {
        const fwd_decl_writer = o.dg.fwd_decl.writer();
        try fwd_decl_writer.writeAll("zig_extern ");
        try o.dg.renderFunctionSignature(fwd_decl_writer, .Forward, 0);
        try fwd_decl_writer.writeAll(";\n");
        try genExports(o);
    } else if (tv.val.castTag(.variable)) |var_payload| {
        const variable: *Module.Var = var_payload.data;

        const is_global = o.dg.declIsGlobal(tv) or variable.is_extern;
        const fwd_decl_writer = o.dg.fwd_decl.writer();

        const decl_c_value = CValue{ .decl = o.dg.decl_index };

        try fwd_decl_writer.writeAll(if (is_global) "zig_extern " else "static ");
        if (variable.is_threadlocal) try fwd_decl_writer.writeAll("zig_threadlocal ");
        try o.dg.renderTypeAndName(fwd_decl_writer, o.dg.decl.ty, decl_c_value, .Mut, o.dg.decl.@"align", .Complete);
        try fwd_decl_writer.writeAll(";\n");
        try genExports(o);

        if (variable.is_extern) return;

        const w = o.writer();
        if (!is_global) try w.writeAll("static ");
        if (variable.is_threadlocal) try w.writeAll("zig_threadlocal ");
        try o.dg.renderTypeAndName(w, o.dg.decl.ty, decl_c_value, .Mut, o.dg.decl.@"align", .Complete);
        try w.writeAll(" = ");
        try o.dg.renderValue(w, tv.ty, variable.init, .Initializer);
        try w.writeByte(';');
        try o.indent_writer.insertNewline();
    } else {
        const decl_c_value: CValue = .{ .decl = o.dg.decl_index };

        const fwd_decl_writer = o.dg.fwd_decl.writer();
        try fwd_decl_writer.writeAll("static ");
        try o.dg.renderTypeAndName(fwd_decl_writer, tv.ty, decl_c_value, .Mut, o.dg.decl.@"align", .Complete);
        try fwd_decl_writer.writeAll(";\n");

        const writer = o.writer();
        try writer.writeAll("static ");
        // TODO ask the Decl if it is const
        // https://github.com/ziglang/zig/issues/7582
        try o.dg.renderTypeAndName(writer, tv.ty, decl_c_value, .Mut, o.dg.decl.@"align", .Complete);
        try writer.writeAll(" = ");
        try o.dg.renderValue(writer, tv.ty, tv.val, .Initializer);
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
                try writer.writeAll("zig_extern ");
                try dg.renderFunctionSignature(writer, .Complete, 0);
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
    } else {
        try writer.writeAll("{\n");
        f.object.indent_writer.pushIndent();
        try genBodyInner(f, body);
        f.object.indent_writer.popIndent();
        try writer.writeByte('}');
    }
}

fn genBodyInner(f: *Function, body: []const Air.Inst.Index) error{ AnalysisFail, OutOfMemory }!void {
    const air_tags = f.air.instructions.items(.tag);

    for (body) |inst| {
        const result_value = switch (air_tags[inst]) {
            // zig fmt: off
            .constant => unreachable, // excluded from function bodies
            .const_ty => unreachable, // excluded from function bodies
            .arg      => airArg(f),

            .breakpoint => try airBreakpoint(f.object.writer()),
            .ret_addr   => try airRetAddr(f, inst),
            .frame_addr => try airFrameAddress(f, inst),
            .unreach    => try airUnreach(f),
            .fence      => try airFence(f, inst),

            .ptr_add => try airPtrAddSub(f, inst, '+'),
            .ptr_sub => try airPtrAddSub(f, inst, '-'),

            // TODO use a different strategy for add, sub, mul, div
            // that communicates to the optimizer that wrapping is UB.
            .add => try airBinOp(f, inst, "+", "add", .None),
            .sub => try airBinOp(f, inst, "-", "sub", .None),
            .mul => try airBinOp(f, inst, "*", "mul", .None),

            .neg => try airFloatNeg(f, inst),
            .div_float => try airBinBuiltinCall(f, inst, "div", .None),

            .div_trunc, .div_exact => try airBinOp(f, inst, "/", "div_trunc", .None),
            .rem => blk: {
                const bin_op = f.air.instructions.items(.data)[inst].bin_op;
                const lhs_ty = f.air.typeOf(bin_op.lhs);
                // For binary operations @TypeOf(lhs)==@TypeOf(rhs),
                // so we only check one.
                break :blk if (lhs_ty.isInt())
                    try airBinOp(f, inst, "%", "rem", .None)
                else
                    try airBinFloatOp(f, inst, "fmod");
            },
            .div_floor => try airBinBuiltinCall(f, inst, "div_floor", .None),
            .mod       => try airBinBuiltinCall(f, inst, "mod", .None),

            .addwrap => try airBinBuiltinCall(f, inst, "addw", .Bits),
            .subwrap => try airBinBuiltinCall(f, inst, "subw", .Bits),
            .mulwrap => try airBinBuiltinCall(f, inst, "mulw", .Bits),

            .add_sat => try airBinBuiltinCall(f, inst, "adds", .Bits),
            .sub_sat => try airBinBuiltinCall(f, inst, "subs", .Bits),
            .mul_sat => try airBinBuiltinCall(f, inst, "muls", .Bits),
            .shl_sat => try airBinBuiltinCall(f, inst, "shls", .Bits),

            .sqrt        => try airUnFloatOp(f, inst, "sqrt"),
            .sin         => try airUnFloatOp(f, inst, "sin"),
            .cos         => try airUnFloatOp(f, inst, "cos"),
            .tan         => try airUnFloatOp(f, inst, "tan"),
            .exp         => try airUnFloatOp(f, inst, "exp"),
            .exp2        => try airUnFloatOp(f, inst, "exp2"),
            .log         => try airUnFloatOp(f, inst, "log"),
            .log2        => try airUnFloatOp(f, inst, "log2"),
            .log10       => try airUnFloatOp(f, inst, "log10"),
            .fabs        => try airUnFloatOp(f, inst, "fabs"),
            .floor       => try airUnFloatOp(f, inst, "floor"),
            .ceil        => try airUnFloatOp(f, inst, "ceil"),
            .round       => try airUnFloatOp(f, inst, "round"),
            .trunc_float => try airUnFloatOp(f, inst, "trunc"),

            .mul_add => try airMulAdd(f, inst),

            .add_with_overflow => try airOverflow(f, inst, "add", .Bits),
            .sub_with_overflow => try airOverflow(f, inst, "sub", .Bits),
            .mul_with_overflow => try airOverflow(f, inst, "mul", .Bits),
            .shl_with_overflow => try airOverflow(f, inst, "shl", .Bits),

            .min => try airMinMax(f, inst, '<', "fmin"),
            .max => try airMinMax(f, inst, '>', "fmax"),

            .slice => try airSlice(f, inst),

            .cmp_gt  => try airCmpOp(f, inst, ">",  "gt"),
            .cmp_gte => try airCmpOp(f, inst, ">=", "ge"),
            .cmp_lt  => try airCmpOp(f, inst, "<",  "lt"),
            .cmp_lte => try airCmpOp(f, inst, "<=", "le"),

            .cmp_eq  => try airEquality(f, inst,  "((", "==", "eq"),
            .cmp_neq => try airEquality(f, inst, "!((", "!=", "ne"),

            .cmp_vector => return f.fail("TODO: C backend: implement cmp_vector", .{}),
            .cmp_lt_errors_len => try airCmpLtErrorsLen(f, inst),

            // bool_and and bool_or are non-short-circuit operations
            .bool_and, .bit_and => try airBinOp(f, inst, "&",  "and", .None),
            .bool_or,  .bit_or  => try airBinOp(f, inst, "|",  "or",  .None),
            .xor                => try airBinOp(f, inst, "^",  "xor", .None),
            .shr, .shr_exact    => try airBinBuiltinCall(f, inst, "shr", .None),
            .shl,               => try airBinBuiltinCall(f, inst, "shlw", .Bits),
            .shl_exact          => try airBinOp(f, inst, "<<", "shl", .None),
            .not                => try airNot  (f, inst),

            .optional_payload         => try airOptionalPayload(f, inst),
            .optional_payload_ptr     => try airOptionalPayloadPtr(f, inst),
            .optional_payload_ptr_set => try airOptionalPayloadPtrSet(f, inst),
            .wrap_optional            => try airWrapOptional(f, inst),

            .is_err          => try airIsErr(f, inst, false, "!="),
            .is_non_err      => try airIsErr(f, inst, false, "=="),
            .is_err_ptr      => try airIsErr(f, inst, true, "!="),
            .is_non_err_ptr  => try airIsErr(f, inst, true, "=="),

            .is_null         => try airIsNull(f, inst, "==", false),
            .is_non_null     => try airIsNull(f, inst, "!=", false),
            .is_null_ptr     => try airIsNull(f, inst, "==", true),
            .is_non_null_ptr => try airIsNull(f, inst, "!=", true),

            .alloc            => try airAlloc(f, inst),
            .ret_ptr          => try airRetPtr(f, inst),
            .assembly         => try airAsm(f, inst),
            .block            => try airBlock(f, inst),
            .bitcast          => try airBitcast(f, inst),
            .dbg_stmt         => try airDbgStmt(f, inst),
            .intcast          => try airIntCast(f, inst),
            .trunc            => try airTrunc(f, inst),
            .bool_to_int      => try airBoolToInt(f, inst),
            .load             => try airLoad(f, inst),
            .ret              => try airRet(f, inst, false),
            .ret_load         => try airRet(f, inst, true),
            .store            => try airStore(f, inst),
            .loop             => try airLoop(f, inst),
            .cond_br          => try airCondBr(f, inst),
            .br               => try airBr(f, inst),
            .switch_br        => try airSwitchBr(f, inst),
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
            .clz              => try airUnBuiltinCall(f, inst, "clz", .Bits),
            .ctz              => try airUnBuiltinCall(f, inst, "ctz", .Bits),
            .popcount         => try airUnBuiltinCall(f, inst, "popcount", .Bits),
            .byte_swap        => try airUnBuiltinCall(f, inst, "byte_swap", .Bits),
            .bit_reverse      => try airUnBuiltinCall(f, inst, "bit_reverse", .Bits),
            .tag_name         => try airTagName(f, inst),
            .error_name       => try airErrorName(f, inst),
            .splat            => try airSplat(f, inst),
            .select           => try airSelect(f, inst),
            .shuffle          => try airShuffle(f, inst),
            .reduce           => try airReduce(f, inst),
            .aggregate_init   => try airAggregateInit(f, inst),
            .union_init       => try airUnionInit(f, inst),
            .prefetch         => try airPrefetch(f, inst),
            .addrspace_cast   => return f.fail("TODO: C backend: implement addrspace_cast", .{}),

            .@"try"  => try airTry(f, inst),
            .try_ptr => try airTryPtr(f, inst),

            .dbg_var_ptr,
            .dbg_var_val,
            => try airDbgVar(f, inst),

            .dbg_inline_begin,
            .dbg_inline_end,
            => try airDbgInline(f, inst),

            .dbg_block_begin,
            .dbg_block_end,
            => CValue{ .none = {} },

            .call              => try airCall(f, inst, .auto),
            .call_always_tail  => try airCall(f, inst, .always_tail),
            .call_never_tail   => try airCall(f, inst, .never_tail),
            .call_never_inline => try airCall(f, inst, .never_inline),

            .int_to_float,
            .float_to_int,
            .fptrunc,
            .fpext,
            => try airFloatCast(f, inst),

            .ptrtoint => try airPtrToInt(f, inst),

            .atomic_store_unordered => try airAtomicStore(f, inst, toMemoryOrder(.Unordered)),
            .atomic_store_monotonic => try airAtomicStore(f, inst, toMemoryOrder(.Monotonic)),
            .atomic_store_release   => try airAtomicStore(f, inst, toMemoryOrder(.Release)),
            .atomic_store_seq_cst   => try airAtomicStore(f, inst, toMemoryOrder(.SeqCst)),

            .struct_field_ptr_index_0 => try airStructFieldPtrIndex(f, inst, 0),
            .struct_field_ptr_index_1 => try airStructFieldPtrIndex(f, inst, 1),
            .struct_field_ptr_index_2 => try airStructFieldPtrIndex(f, inst, 2),
            .struct_field_ptr_index_3 => try airStructFieldPtrIndex(f, inst, 3),

            .field_parent_ptr => try airFieldParentPtr(f, inst),

            .struct_field_val => try airStructFieldVal(f, inst),
            .slice_ptr        => try airSliceField(f, inst, false, "ptr"),
            .slice_len        => try airSliceField(f, inst, false, "len"),

            .ptr_slice_len_ptr => try airSliceField(f, inst, true, "len"),
            .ptr_slice_ptr_ptr => try airSliceField(f, inst, true, "ptr"),

            .ptr_elem_val       => try airPtrElemVal(f, inst),
            .ptr_elem_ptr       => try airPtrElemPtr(f, inst),
            .slice_elem_val     => try airSliceElemVal(f, inst),
            .slice_elem_ptr     => try airSliceElemPtr(f, inst),
            .array_elem_val     => try airArrayElemVal(f, inst),

            .unwrap_errunion_payload     => try airUnwrapErrUnionPay(f, inst, false),
            .unwrap_errunion_payload_ptr => try airUnwrapErrUnionPay(f, inst, true),
            .unwrap_errunion_err         => try airUnwrapErrUnionErr(f, inst),
            .unwrap_errunion_err_ptr     => try airUnwrapErrUnionErr(f, inst),
            .wrap_errunion_payload       => try airWrapErrUnionPay(f, inst),
            .wrap_errunion_err           => try airWrapErrUnionErr(f, inst),
            .errunion_payload_ptr_set    => try airErrUnionPayloadPtrSet(f, inst),
            .err_return_trace            => try airErrReturnTrace(f, inst),
            .set_err_return_trace        => try airSetErrReturnTrace(f, inst),
            .save_err_return_trace_index => try airSaveErrReturnTraceIndex(f, inst),

            .wasm_memory_size => try airWasmMemorySize(f, inst),
            .wasm_memory_grow => try airWasmMemoryGrow(f, inst),

            .add_optimized,
            .addwrap_optimized,
            .sub_optimized,
            .subwrap_optimized,
            .mul_optimized,
            .mulwrap_optimized,
            .div_float_optimized,
            .div_trunc_optimized,
            .div_floor_optimized,
            .div_exact_optimized,
            .rem_optimized,
            .mod_optimized,
            .neg_optimized,
            .cmp_lt_optimized,
            .cmp_lte_optimized,
            .cmp_eq_optimized,
            .cmp_gte_optimized,
            .cmp_gt_optimized,
            .cmp_neq_optimized,
            .cmp_vector_optimized,
            .reduce_optimized,
            .float_to_int_optimized,
            => return f.fail("TODO implement optimized float mode", .{}),

            .is_named_enum_value => return f.fail("TODO: C backend: implement is_named_enum_value", .{}),
            .error_set_has_value => return f.fail("TODO: C backend: implement error_set_has_value", .{}),
            // zig fmt: on
        };
        if (result_value == .local) {
            log.debug("map %{d} to t{d}", .{ inst, result_value.local });
        }
        switch (result_value) {
            .none => {},
            else => try f.value_map.putNoClobber(Air.indexToRef(inst), result_value),
        }
    }
}

fn airSliceField(f: *Function, inst: Air.Inst.Index, is_ptr: bool, field_name: []const u8) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ty_op.operand});
        return CValue.none;
    }

    const inst_ty = f.air.typeOfIndex(inst);
    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = ");
    if (is_ptr) {
        try writer.writeByte('&');
        try f.writeCValueDerefMember(writer, operand, .{ .identifier = field_name });
    } else try f.writeCValueMember(writer, operand, .{ .identifier = field_name });
    try writer.writeAll(";\n");
    return local;
}

fn airPtrElemVal(f: *Function, inst: Air.Inst.Index) !CValue {
    const inst_ty = f.air.typeOfIndex(inst);
    const bin_op = f.air.instructions.items(.data)[inst].bin_op;
    const ptr_ty = f.air.typeOf(bin_op.lhs);
    if ((!ptr_ty.isVolatilePtr() and f.liveness.isUnused(inst)) or
        !inst_ty.hasRuntimeBitsIgnoreComptime())
    {
        try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
        return CValue.none;
    }

    const ptr = try f.resolveInst(bin_op.lhs);
    const index = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const target = f.object.dg.module.getTarget();
    const is_array = lowersToArray(inst_ty, target);

    const local = try f.allocLocal(inst, inst_ty);
    const writer = f.object.writer();
    if (is_array) {
        try writer.writeAll("memcpy(");
        try f.writeCValue(writer, local, .FunctionArgument);
        try writer.writeAll(", ");
    } else {
        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(" = ");
    }
    try f.writeCValue(writer, ptr, .Other);
    try writer.writeByte('[');
    try f.writeCValue(writer, index, .Other);
    try writer.writeByte(']');
    if (is_array) {
        try writer.writeAll(", sizeof(");
        try f.renderTypecast(writer, inst_ty);
        try writer.writeAll("))");
    }
    try writer.writeAll(";\n");
    return local;
}

fn airPtrElemPtr(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_pl = f.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = f.air.extraData(Air.Bin, ty_pl.payload).data;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
        return CValue.none;
    }

    const ptr_ty = f.air.typeOf(bin_op.lhs);
    const child_ty = ptr_ty.childType();

    const ptr = try f.resolveInst(bin_op.lhs);
    if (!child_ty.hasRuntimeBitsIgnoreComptime()) {
        if (f.liveness.operandDies(inst, 1)) try die(f, inst, bin_op.rhs);
        return ptr;
    }
    const index = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, f.air.typeOfIndex(inst));
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = &(");
    if (ptr_ty.ptrSize() == .One) {
        // It's a pointer to an array, so we need to de-reference.
        try f.writeCValueDeref(writer, ptr);
    } else {
        try f.writeCValue(writer, ptr, .Other);
    }
    try writer.writeAll(")[");
    try f.writeCValue(writer, index, .Other);
    try writer.writeAll("];\n");
    return local;
}

fn airSliceElemVal(f: *Function, inst: Air.Inst.Index) !CValue {
    const inst_ty = f.air.typeOfIndex(inst);
    const bin_op = f.air.instructions.items(.data)[inst].bin_op;
    const slice_ty = f.air.typeOf(bin_op.lhs);
    if ((!slice_ty.isVolatilePtr() and f.liveness.isUnused(inst)) or
        !inst_ty.hasRuntimeBitsIgnoreComptime())
    {
        try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
        return CValue.none;
    }

    const slice = try f.resolveInst(bin_op.lhs);
    const index = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const target = f.object.dg.module.getTarget();
    const is_array = lowersToArray(inst_ty, target);

    const local = try f.allocLocal(inst, inst_ty);
    const writer = f.object.writer();
    if (is_array) {
        try writer.writeAll("memcpy(");
        try f.writeCValue(writer, local, .FunctionArgument);
        try writer.writeAll(", ");
    } else {
        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(" = ");
    }
    try f.writeCValue(writer, slice, .Other);
    try writer.writeAll(".ptr[");
    try f.writeCValue(writer, index, .Other);
    try writer.writeByte(']');
    if (is_array) {
        try writer.writeAll(", sizeof(");
        try f.renderTypecast(writer, inst_ty);
        try writer.writeAll("))");
    }
    try writer.writeAll(";\n");
    return local;
}

fn airSliceElemPtr(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_pl = f.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = f.air.extraData(Air.Bin, ty_pl.payload).data;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
        return CValue.none;
    }

    const slice_ty = f.air.typeOf(bin_op.lhs);
    const child_ty = slice_ty.elemType2();
    const slice = try f.resolveInst(bin_op.lhs);
    const index = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, f.air.typeOfIndex(inst));
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = ");
    if (child_ty.hasRuntimeBitsIgnoreComptime()) try writer.writeByte('&');
    try f.writeCValue(writer, slice, .Other);
    try writer.writeAll(".ptr");
    if (child_ty.hasRuntimeBitsIgnoreComptime()) {
        try writer.writeByte('[');
        try f.writeCValue(writer, index, .Other);
        try writer.writeByte(']');
    }
    try writer.writeAll(";\n");
    return local;
}

fn airArrayElemVal(f: *Function, inst: Air.Inst.Index) !CValue {
    const bin_op = f.air.instructions.items(.data)[inst].bin_op;
    const inst_ty = f.air.typeOfIndex(inst);
    if (f.liveness.isUnused(inst) or !inst_ty.hasRuntimeBitsIgnoreComptime()) {
        try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
        return CValue.none;
    }

    const array = try f.resolveInst(bin_op.lhs);
    const index = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const target = f.object.dg.module.getTarget();
    const is_array = lowersToArray(inst_ty, target);

    const local = try f.allocLocal(inst, inst_ty);
    const writer = f.object.writer();
    if (is_array) {
        try writer.writeAll("memcpy(");
        try f.writeCValue(writer, local, .FunctionArgument);
        try writer.writeAll(", ");
    } else {
        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(" = ");
    }
    try f.writeCValue(writer, array, .Other);
    try writer.writeByte('[');
    try f.writeCValue(writer, index, .Other);
    try writer.writeByte(']');
    if (is_array) {
        try writer.writeAll(", sizeof(");
        try f.renderTypecast(writer, inst_ty);
        try writer.writeAll("))");
    }
    try writer.writeAll(";\n");
    return local;
}

fn airAlloc(f: *Function, inst: Air.Inst.Index) !CValue {
    const inst_ty = f.air.typeOfIndex(inst);

    const elem_type = inst_ty.elemType();
    if (!elem_type.isFnOrHasRuntimeBitsIgnoreComptime()) {
        return CValue{ .undef = inst_ty };
    }

    const mutability: Mutability = if (inst_ty.isConstPtr()) .Const else .Mut;
    const target = f.object.dg.module.getTarget();
    const local = try f.allocAlignedLocal(elem_type, mutability, inst_ty.ptrAlignment(target));
    log.debug("%{d}: allocated unfreeable t{d}", .{ inst, local.local });
    const gpa = f.object.dg.module.gpa;
    try f.allocs.put(gpa, local.local, false);
    return CValue{ .local_ref = local.local };
}

fn airRetPtr(f: *Function, inst: Air.Inst.Index) !CValue {
    const inst_ty = f.air.typeOfIndex(inst);

    const elem_ty = inst_ty.elemType();
    if (!elem_ty.isFnOrHasRuntimeBitsIgnoreComptime()) {
        return CValue{ .undef = inst_ty };
    }

    const mutability: Mutability = if (inst_ty.isConstPtr()) .Const else .Mut;
    const target = f.object.dg.module.getTarget();
    const local = try f.allocAlignedLocal(elem_ty, mutability, inst_ty.ptrAlignment(target));
    log.debug("%{d}: allocated unfreeable t{d}", .{ inst, local.local });
    const gpa = f.object.dg.module.gpa;
    try f.allocs.put(gpa, local.local, false);
    return CValue{ .local_ref = local.local };
}

fn airArg(f: *Function) CValue {
    const i = f.next_arg_index;
    f.next_arg_index += 1;
    return .{ .arg = i };
}

fn airLoad(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    const ptr_info = f.air.typeOf(ty_op.operand).ptrInfo().data;
    const src_ty = ptr_info.pointee_type;

    if (!src_ty.hasRuntimeBitsIgnoreComptime() or
        (!ptr_info.@"volatile" and f.liveness.isUnused(inst)))
    {
        try reap(f, inst, &.{ty_op.operand});
        return CValue.none;
    }

    const operand = try f.resolveInst(ty_op.operand);

    try reap(f, inst, &.{ty_op.operand});

    const target = f.object.dg.module.getTarget();
    const is_aligned = ptr_info.@"align" == 0 or ptr_info.@"align" >= src_ty.abiAlignment(target);
    const is_array = lowersToArray(src_ty, target);
    const need_memcpy = !is_aligned or is_array;
    const writer = f.object.writer();

    const local = try f.allocLocal(inst, src_ty);

    if (need_memcpy) {
        try writer.writeAll("memcpy(");
        if (!is_array) try writer.writeByte('&');
        try f.writeCValue(writer, local, .FunctionArgument);
        try writer.writeAll(", (const char *)");
        try f.writeCValue(writer, operand, .Other);
        try writer.writeAll(", sizeof(");
        try f.renderTypecast(writer, src_ty);
        try writer.writeAll("))");
    } else if (ptr_info.host_size != 0) {
        var host_pl = Type.Payload.Bits{
            .base = .{ .tag = .int_unsigned },
            .data = ptr_info.host_size * 8,
        };
        const host_ty = Type.initPayload(&host_pl.base);

        var bit_offset_ty_pl = Type.Payload.Bits{
            .base = .{ .tag = .int_unsigned },
            .data = Type.smallestUnsignedBits(host_pl.data - 1),
        };
        const bit_offset_ty = Type.initPayload(&bit_offset_ty_pl.base);

        var bit_offset_val_pl: Value.Payload.U64 = .{
            .base = .{ .tag = .int_u64 },
            .data = ptr_info.bit_offset,
        };
        const bit_offset_val = Value.initPayload(&bit_offset_val_pl.base);

        var field_pl = Type.Payload.Bits{
            .base = .{ .tag = .int_unsigned },
            .data = @intCast(u16, src_ty.bitSize(target)),
        };
        const field_ty = Type.initPayload(&field_pl.base);

        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(" = (");
        try f.renderTypecast(writer, src_ty);
        try writer.writeAll(")zig_wrap_");
        try f.object.dg.renderTypeForBuiltinFnName(writer, field_ty);
        try writer.writeAll("((");
        try f.renderTypecast(writer, field_ty);
        try writer.writeAll(")zig_shr_");
        try f.object.dg.renderTypeForBuiltinFnName(writer, host_ty);
        try writer.writeByte('(');
        try f.writeCValueDeref(writer, operand);
        try writer.print(", {})", .{try f.fmtIntLiteral(bit_offset_ty, bit_offset_val)});
        try f.object.dg.renderBuiltinInfo(writer, field_ty, .Bits);
        try writer.writeByte(')');
    } else {
        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(" = ");
        try f.writeCValueDeref(writer, operand);
    }
    try writer.writeAll(";\n");
    return local;
}

fn airRet(f: *Function, inst: Air.Inst.Index, is_ptr: bool) !CValue {
    const un_op = f.air.instructions.items(.data)[inst].un_op;
    const writer = f.object.writer();
    const target = f.object.dg.module.getTarget();
    const op_ty = f.air.typeOf(un_op);
    const ret_ty = if (is_ptr) op_ty.childType() else op_ty;
    var lowered_ret_buf: LowerFnRetTyBuffer = undefined;
    const lowered_ret_ty = lowerFnRetTy(ret_ty, &lowered_ret_buf, target);

    if (lowered_ret_ty.hasRuntimeBitsIgnoreComptime()) {
        var deref = is_ptr;
        const operand = try f.resolveInst(un_op);
        try reap(f, inst, &.{un_op});
        const is_array = lowersToArray(ret_ty, target);
        const ret_val = if (is_array) ret_val: {
            const array_local = try f.allocLocal(inst, try lowered_ret_ty.copy(f.arena.allocator()));
            try writer.writeAll("memcpy(");
            try f.writeCValueMember(writer, array_local, .{ .field = 0 });
            try writer.writeAll(", ");
            if (deref)
                try f.writeCValueDeref(writer, operand)
            else
                try f.writeCValue(writer, operand, .FunctionArgument);
            deref = false;
            try writer.writeAll(", sizeof(");
            try f.renderTypecast(writer, ret_ty);
            try writer.writeAll("));\n");
            break :ret_val array_local;
        } else operand;

        try writer.writeAll("return ");
        if (deref)
            try f.writeCValueDeref(writer, ret_val)
        else
            try f.writeCValue(writer, ret_val, .Other);
        try writer.writeAll(";\n");
        if (is_array) {
            try freeLocal(f, inst, ret_val.local, 0);
        }
    } else {
        try reap(f, inst, &.{un_op});
        if (f.object.dg.decl.ty.fnCallingConvention() != .Naked) {
            // Not even allowed to return void in a naked function.
            try writer.writeAll("return;\n");
        }
    }
    return CValue.none;
}

fn airIntCast(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ty_op.operand});
        return CValue.none;
    }

    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const writer = f.object.writer();
    const inst_ty = f.air.typeOfIndex(inst);
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = (");
    try f.renderTypecast(writer, inst_ty);
    try writer.writeByte(')');
    try f.writeCValue(writer, operand, .Other);
    try writer.writeAll(";\n");
    return local;
}

fn airTrunc(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ty_op.operand});
        return CValue.none;
    }

    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const inst_ty = f.air.typeOfIndex(inst);
    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const target = f.object.dg.module.getTarget();
    const dest_int_info = inst_ty.intInfo(target);
    const dest_bits = dest_int_info.bits;

    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = (");
    try f.renderTypecast(writer, inst_ty);
    try writer.writeByte(')');

    if (dest_bits >= 8 and std.math.isPowerOfTwo(dest_bits)) {
        try f.writeCValue(writer, operand, .Other);
        try writer.writeAll(";\n");
    } else switch (dest_int_info.signedness) {
        .unsigned => {
            var arena = std.heap.ArenaAllocator.init(f.object.dg.gpa);
            defer arena.deinit();

            const ExpectedContents = union { u: Value.Payload.U64, i: Value.Payload.I64 };
            var stack align(@alignOf(ExpectedContents)) =
                std.heap.stackFallback(@sizeOf(ExpectedContents), arena.allocator());

            const mask_val = try inst_ty.maxInt(stack.get(), target);

            try writer.writeByte('(');
            try f.writeCValue(writer, operand, .Other);
            try writer.print(" & {x});\n", .{try f.fmtIntLiteral(inst_ty, mask_val)});
        },
        .signed => {
            const operand_ty = f.air.typeOf(ty_op.operand);
            const c_bits = toCIntBits(operand_ty.intInfo(target).bits) orelse
                return f.fail("TODO: C backend: implement integer types larger than 128 bits", .{});
            var shift_pl = Value.Payload.U64{
                .base = .{ .tag = .int_u64 },
                .data = c_bits - dest_bits,
            };
            const shift_val = Value.initPayload(&shift_pl.base);

            try writer.print("((int{d}_t)((uint{0d}_t)", .{c_bits});
            try f.writeCValue(writer, operand, .Other);
            try writer.print(" << {}) >> {0});\n", .{try f.fmtIntLiteral(Type.u8, shift_val)});
        },
    }
    return local;
}

fn airBoolToInt(f: *Function, inst: Air.Inst.Index) !CValue {
    const un_op = f.air.instructions.items(.data)[inst].un_op;
    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{un_op});
        return CValue.none;
    }
    const operand = try f.resolveInst(un_op);
    try reap(f, inst, &.{un_op});
    const writer = f.object.writer();
    const inst_ty = f.air.typeOfIndex(inst);
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = ");
    try f.writeCValue(writer, operand, .Other);
    try writer.writeAll(";\n");
    return local;
}

fn storeUndefined(f: *Function, lhs_child_ty: Type, dest_ptr: CValue) !CValue {
    if (f.wantSafety()) {
        const writer = f.object.writer();
        try writer.writeAll("memset(");
        try f.writeCValue(writer, dest_ptr, .FunctionArgument);
        try writer.print(", {x}, sizeof(", .{try f.fmtIntLiteral(Type.u8, Value.undef)});
        try f.renderTypecast(writer, lhs_child_ty);
        try writer.writeAll("));\n");
    }
    return CValue.none;
}

fn airStore(f: *Function, inst: Air.Inst.Index) !CValue {
    // *a = b;
    const bin_op = f.air.instructions.items(.data)[inst].bin_op;
    const ptr_info = f.air.typeOf(bin_op.lhs).ptrInfo().data;
    if (!ptr_info.pointee_type.hasRuntimeBitsIgnoreComptime()) {
        try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
        return CValue.none;
    }

    const ptr_val = try f.resolveInst(bin_op.lhs);
    const src_ty = f.air.typeOf(bin_op.rhs);
    const src_val = try f.resolveInst(bin_op.rhs);

    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    // TODO Sema should emit a different instruction when the store should
    // possibly do the safety 0xaa bytes for undefined.
    const src_val_is_undefined =
        if (f.air.value(bin_op.rhs)) |v| v.isUndefDeep() else false;
    if (src_val_is_undefined)
        return try storeUndefined(f, ptr_info.pointee_type, ptr_val);

    const target = f.object.dg.module.getTarget();
    const is_aligned = ptr_info.@"align" == 0 or
        ptr_info.@"align" >= ptr_info.pointee_type.abiAlignment(target);
    const is_array = lowersToArray(ptr_info.pointee_type, target);
    const need_memcpy = !is_aligned or is_array;
    const writer = f.object.writer();

    if (need_memcpy) {
        // For this memcpy to safely work we need the rhs to have the same
        // underlying type as the lhs (i.e. they must both be arrays of the same underlying type).
        assert(src_ty.eql(ptr_info.pointee_type, f.object.dg.module));

        // If the source is a constant, writeCValue will emit a brace initialization
        // so work around this by initializing into new local.
        // TODO this should be done by manually initializing elements of the dest array
        const array_src = if (src_val == .constant) blk: {
            const new_local = try f.allocLocal(inst, src_ty);
            try f.writeCValue(writer, new_local, .Other);
            try writer.writeAll(" = ");
            try f.writeCValue(writer, src_val, .Initializer);
            try writer.writeAll(";\n");

            break :blk new_local;
        } else src_val;

        try writer.writeAll("memcpy((char *)");
        try f.writeCValue(writer, ptr_val, .FunctionArgument);
        try writer.writeAll(", ");
        if (!is_array) try writer.writeByte('&');
        try f.writeCValue(writer, array_src, .FunctionArgument);
        try writer.writeAll(", sizeof(");
        try f.renderTypecast(writer, src_ty);
        try writer.writeAll("))");
        if (src_val == .constant) {
            try freeLocal(f, inst, array_src.local, 0);
        }
    } else if (ptr_info.host_size != 0) {
        const host_bits = ptr_info.host_size * 8;
        var host_pl = Type.Payload.Bits{ .base = .{ .tag = .int_unsigned }, .data = host_bits };
        const host_ty = Type.initPayload(&host_pl.base);

        var bit_offset_ty_pl = Type.Payload.Bits{
            .base = .{ .tag = .int_unsigned },
            .data = Type.smallestUnsignedBits(host_bits - 1),
        };
        const bit_offset_ty = Type.initPayload(&bit_offset_ty_pl.base);

        var bit_offset_val_pl: Value.Payload.U64 = .{
            .base = .{ .tag = .int_u64 },
            .data = ptr_info.bit_offset,
        };
        const bit_offset_val = Value.initPayload(&bit_offset_val_pl.base);

        const src_bits = src_ty.bitSize(target);

        const ExpectedContents = [BigInt.Managed.default_capacity]BigIntLimb;
        var stack align(@alignOf(ExpectedContents)) =
            std.heap.stackFallback(@sizeOf(ExpectedContents), f.object.dg.gpa);

        var mask = try BigInt.Managed.initCapacity(stack.get(), BigInt.calcTwosCompLimbCount(host_bits));
        defer mask.deinit();

        try mask.setTwosCompIntLimit(.max, .unsigned, @intCast(usize, src_bits));
        try mask.shiftLeft(&mask, ptr_info.bit_offset);
        try mask.bitNotWrap(&mask, .unsigned, host_bits);

        var mask_pl = Value.Payload.BigInt{
            .base = .{ .tag = .int_big_positive },
            .data = mask.limbs[0..mask.len()],
        };
        const mask_val = Value.initPayload(&mask_pl.base);

        try f.writeCValueDeref(writer, ptr_val);
        try writer.writeAll(" = zig_or_");
        try f.object.dg.renderTypeForBuiltinFnName(writer, host_ty);
        try writer.writeAll("(zig_and_");
        try f.object.dg.renderTypeForBuiltinFnName(writer, host_ty);
        try writer.writeByte('(');
        try f.writeCValueDeref(writer, ptr_val);
        try writer.print(", {x}), zig_shl_", .{try f.fmtIntLiteral(host_ty, mask_val)});
        try f.object.dg.renderTypeForBuiltinFnName(writer, host_ty);
        try writer.writeAll("((");
        try f.renderTypecast(writer, host_ty);
        try writer.writeByte(')');
        if (src_ty.isPtrAtRuntime()) {
            try writer.writeByte('(');
            try f.renderTypecast(writer, Type.usize);
            try writer.writeByte(')');
        }
        try f.writeCValue(writer, src_val, .Other);
        try writer.print(", {}))", .{try f.fmtIntLiteral(bit_offset_ty, bit_offset_val)});
    } else {
        try f.writeCValueDeref(writer, ptr_val);
        try writer.writeAll(" = ");
        try f.writeCValue(writer, src_val, .Other);
    }
    try writer.writeAll(";\n");
    return CValue.none;
}

fn airOverflow(f: *Function, inst: Air.Inst.Index, operation: []const u8, info: BuiltinInfo) !CValue {
    const ty_pl = f.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = f.air.extraData(Air.Bin, ty_pl.payload).data;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
        return CValue.none;
    }

    const lhs = try f.resolveInst(bin_op.lhs);
    const rhs = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const inst_ty = f.air.typeOfIndex(inst);
    const vector_ty = f.air.typeOf(bin_op.lhs);
    const scalar_ty = vector_ty.scalarType();
    const w = f.object.writer();

    const local = try f.allocLocal(inst, inst_ty);

    switch (vector_ty.zigTypeTag()) {
        .Vector => {
            try w.writeAll("zig_v");
            try w.writeAll(operation);
            try w.writeAll("o_");
            try f.object.dg.renderTypeForBuiltinFnName(w, scalar_ty);
            try w.writeAll("(");
            try f.writeCValueMember(w, local, .{ .field = 1 });
            try w.writeAll(", ");
            try f.writeCValueMember(w, local, .{ .field = 0 });
            try w.print(", {d}, ", .{vector_ty.vectorLen()});
        },
        else => {
            try f.writeCValueMember(w, local, .{ .field = 1 });
            try w.writeAll(" = zig_");
            try w.writeAll(operation);
            try w.writeAll("o_");
            try f.object.dg.renderTypeForBuiltinFnName(w, scalar_ty);
            try w.writeAll("(&");
            try f.writeCValueMember(w, local, .{ .field = 0 });
            try w.writeAll(", ");
        },
    }

    try f.writeCValue(w, lhs, .FunctionArgument);
    try w.writeAll(", ");
    try f.writeCValue(w, rhs, .FunctionArgument);
    try f.object.dg.renderBuiltinInfo(w, scalar_ty, info);
    try w.writeAll(");\n");

    return local;
}

fn airNot(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ty_op.operand});
        return CValue.none;
    }

    const op = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});

    const writer = f.object.writer();
    const inst_ty = f.air.typeOfIndex(inst);
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = ");
    try writer.writeByte(if (inst_ty.tag() == .bool) '!' else '~');
    try f.writeCValue(writer, op, .Other);
    try writer.writeAll(";\n");

    return local;
}

fn airBinOp(
    f: *Function,
    inst: Air.Inst.Index,
    operator: []const u8,
    operation: []const u8,
    info: BuiltinInfo,
) !CValue {
    const bin_op = f.air.instructions.items(.data)[inst].bin_op;
    const operand_ty = f.air.typeOf(bin_op.lhs);
    const target = f.object.dg.module.getTarget();
    if ((operand_ty.isInt() and operand_ty.bitSize(target) > 64) or operand_ty.isRuntimeFloat())
        return try airBinBuiltinCall(f, inst, operation, info);

    const lhs = try f.resolveInst(bin_op.lhs);
    const rhs = try f.resolveInst(bin_op.rhs);

    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    if (f.liveness.isUnused(inst)) return CValue.none;

    const inst_ty = f.air.typeOfIndex(inst);

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = ");
    try f.writeCValue(writer, lhs, .Other);
    try writer.writeByte(' ');
    try writer.writeAll(operator);
    try writer.writeByte(' ');
    try f.writeCValue(writer, rhs, .Other);
    try writer.writeAll(";\n");

    return local;
}

fn airCmpOp(f: *Function, inst: Air.Inst.Index, operator: []const u8, operation: []const u8) !CValue {
    const bin_op = f.air.instructions.items(.data)[inst].bin_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
        return CValue.none;
    }

    const operand_ty = f.air.typeOf(bin_op.lhs);
    const target = f.object.dg.module.getTarget();
    if (operand_ty.isInt() and operand_ty.bitSize(target) > 64)
        return try cmpBuiltinCall(f, inst, operator, "cmp");
    if (operand_ty.isRuntimeFloat())
        return try cmpBuiltinCall(f, inst, operator, operation);

    const inst_ty = f.air.typeOfIndex(inst);
    const lhs = try f.resolveInst(bin_op.lhs);
    const rhs = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = ");
    try f.writeCValue(writer, lhs, .Other);
    try writer.writeByte(' ');
    try writer.writeAll(operator);
    try writer.writeByte(' ');
    try f.writeCValue(writer, rhs, .Other);
    try writer.writeAll(";\n");

    return local;
}

fn airEquality(
    f: *Function,
    inst: Air.Inst.Index,
    negate_prefix: []const u8,
    operator: []const u8,
    operation: []const u8,
) !CValue {
    const bin_op = f.air.instructions.items(.data)[inst].bin_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
        return CValue.none;
    }

    const operand_ty = f.air.typeOf(bin_op.lhs);
    const target = f.object.dg.module.getTarget();
    if (operand_ty.isInt() and operand_ty.bitSize(target) > 64)
        return try cmpBuiltinCall(f, inst, operator, "cmp");
    if (operand_ty.isRuntimeFloat())
        return try cmpBuiltinCall(f, inst, operator, operation);

    const lhs = try f.resolveInst(bin_op.lhs);
    const rhs = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const writer = f.object.writer();
    const inst_ty = f.air.typeOfIndex(inst);
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = ");

    if (operand_ty.zigTypeTag() == .Optional and !operand_ty.isPtrLikeOptional()) {
        // (A && B)  || (C && (A == B))
        // A = lhs.is_null  ;  B = rhs.is_null  ;  C = rhs.payload == lhs.payload

        try writer.writeAll(negate_prefix);
        try f.writeCValue(writer, lhs, .Other);
        try writer.writeAll(".is_null && ");
        try f.writeCValue(writer, rhs, .Other);
        try writer.writeAll(".is_null) || (");
        try f.writeCValue(writer, lhs, .Other);
        try writer.writeAll(".payload == ");
        try f.writeCValue(writer, rhs, .Other);
        try writer.writeAll(".payload && ");
        try f.writeCValue(writer, lhs, .Other);
        try writer.writeAll(".is_null == ");
        try f.writeCValue(writer, rhs, .Other);
        try writer.writeAll(".is_null));\n");

        return local;
    }

    try f.writeCValue(writer, lhs, .Other);
    try writer.writeByte(' ');
    try writer.writeAll(operator);
    try writer.writeByte(' ');
    try f.writeCValue(writer, rhs, .Other);
    try writer.writeAll(";\n");

    return local;
}

fn airCmpLtErrorsLen(f: *Function, inst: Air.Inst.Index) !CValue {
    const un_op = f.air.instructions.items(.data)[inst].un_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{un_op});
        return CValue.none;
    }

    const inst_ty = f.air.typeOfIndex(inst);
    const operand = try f.resolveInst(un_op);
    try reap(f, inst, &.{un_op});

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = ");
    try f.writeCValue(writer, operand, .Other);
    try writer.print(" < sizeof({ }) / sizeof(*{0 });\n", .{fmtIdent("zig_errorName")});
    return local;
}

fn airPtrAddSub(f: *Function, inst: Air.Inst.Index, operator: u8) !CValue {
    const ty_pl = f.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = f.air.extraData(Air.Bin, ty_pl.payload).data;
    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
        return CValue.none;
    }

    const lhs = try f.resolveInst(bin_op.lhs);
    const rhs = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const inst_ty = f.air.typeOfIndex(inst);
    const elem_ty = switch (inst_ty.ptrSize()) {
        .One => blk: {
            const array_ty = inst_ty.childType();
            break :blk array_ty.childType();
        },
        else => inst_ty.childType(),
    };

    // We must convert to and from integer types to prevent UB if the operation
    // results in a NULL pointer, or if LHS is NULL. The operation is only UB
    // if the result is NULL and then dereferenced.
    const local = try f.allocLocal(inst, inst_ty);
    const writer = f.object.writer();
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = (");
    try f.renderTypecast(writer, inst_ty);
    try writer.writeAll(")(((uintptr_t)");
    try f.writeCValue(writer, lhs, .Other);
    try writer.writeAll(") ");
    try writer.writeByte(operator);
    try writer.writeAll(" (");
    try f.writeCValue(writer, rhs, .Other);
    try writer.writeAll("*sizeof(");
    try f.renderTypecast(writer, elem_ty);
    try writer.writeAll(")));\n");

    return local;
}

fn airMinMax(f: *Function, inst: Air.Inst.Index, operator: u8, operation: []const u8) !CValue {
    const bin_op = f.air.instructions.items(.data)[inst].bin_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
        return CValue.none;
    }

    const inst_ty = f.air.typeOfIndex(inst);
    const target = f.object.dg.module.getTarget();
    if (inst_ty.isInt() and inst_ty.bitSize(target) > 64)
        return try airBinBuiltinCall(f, inst, operation[1..], .None);
    if (inst_ty.isRuntimeFloat())
        return try airBinFloatOp(f, inst, operation);

    const lhs = try f.resolveInst(bin_op.lhs);
    const rhs = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);
    // (lhs <> rhs) ? lhs : rhs
    try writer.writeAll(" = (");
    try f.writeCValue(writer, lhs, .Other);
    try writer.writeByte(' ');
    try writer.writeByte(operator);
    try writer.writeByte(' ');
    try f.writeCValue(writer, rhs, .Other);
    try writer.writeAll(") ? ");
    try f.writeCValue(writer, lhs, .Other);
    try writer.writeAll(" : ");
    try f.writeCValue(writer, rhs, .Other);
    try writer.writeAll(";\n");

    return local;
}

fn airSlice(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_pl = f.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = f.air.extraData(Air.Bin, ty_pl.payload).data;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
        return CValue.none;
    }

    const ptr = try f.resolveInst(bin_op.lhs);
    const len = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const writer = f.object.writer();
    const inst_ty = f.air.typeOfIndex(inst);
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(".ptr = (");
    var buf: Type.SlicePtrFieldTypeBuffer = undefined;
    try f.renderTypecast(writer, inst_ty.slicePtrFieldType(&buf));
    try writer.writeByte(')');
    try f.writeCValue(writer, ptr, .Other);
    try writer.writeAll("; ");
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(".len = ");
    try f.writeCValue(writer, len, .Initializer);
    try writer.writeAll(";\n");

    return local;
}

fn airCall(
    f: *Function,
    inst: Air.Inst.Index,
    modifier: std.builtin.CallOptions.Modifier,
) !CValue {
    // Not even allowed to call panic in a naked function.
    if (f.object.dg.decl.ty.fnCallingConvention() == .Naked) return .none;
    const gpa = f.object.dg.gpa;

    switch (modifier) {
        .auto => {},
        .always_tail => return f.fail("TODO: C backend: call with always_tail attribute", .{}),
        .never_tail => return f.fail("TODO: C backend: call with never_tail attribute", .{}),
        .never_inline => return f.fail("TODO: C backend: call with never_inline attribute", .{}),
        else => unreachable,
    }
    const pl_op = f.air.instructions.items(.data)[inst].pl_op;
    const extra = f.air.extraData(Air.Call, pl_op.payload);
    const args = @ptrCast([]const Air.Inst.Ref, f.air.extra[extra.end..][0..extra.data.args_len]);

    const resolved_args = try gpa.alloc(CValue, args.len);
    defer gpa.free(resolved_args);
    for (args) |arg, i| {
        resolved_args[i] = try f.resolveInst(arg);
    }

    const callee = try f.resolveInst(pl_op.operand);

    {
        var bt = iterateBigTomb(f, inst);
        try bt.feed(pl_op.operand);
        for (args) |arg| try bt.feed(arg);
    }

    const callee_ty = f.air.typeOf(pl_op.operand);
    const fn_ty = switch (callee_ty.zigTypeTag()) {
        .Fn => callee_ty,
        .Pointer => callee_ty.childType(),
        else => unreachable,
    };
    const writer = f.object.writer();

    const target = f.object.dg.module.getTarget();
    const ret_ty = fn_ty.fnReturnType();
    var lowered_ret_buf: LowerFnRetTyBuffer = undefined;
    const lowered_ret_ty = lowerFnRetTy(ret_ty, &lowered_ret_buf, target);

    const result_local: CValue = if (!lowered_ret_ty.hasRuntimeBitsIgnoreComptime())
        .none
    else if (f.liveness.isUnused(inst)) r: {
        try writer.writeByte('(');
        try f.renderTypecast(writer, Type.void);
        try writer.writeByte(')');
        break :r .none;
    } else r: {
        const local = try f.allocLocal(inst, try lowered_ret_ty.copy(f.arena.allocator()));
        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(" = ");
        break :r local;
    };

    var is_extern = false;
    var name: [*:0]const u8 = "";
    callee: {
        known: {
            const fn_decl = fn_decl: {
                const callee_val = f.air.value(pl_op.operand) orelse break :known;
                break :fn_decl switch (callee_val.tag()) {
                    .extern_fn => blk: {
                        is_extern = true;
                        break :blk callee_val.castTag(.extern_fn).?.data.owner_decl;
                    },
                    .function => callee_val.castTag(.function).?.data.owner_decl,
                    .decl_ref => callee_val.castTag(.decl_ref).?.data,
                    else => break :known,
                };
            };
            name = f.object.dg.module.declPtr(fn_decl).name;
            try f.object.dg.renderDeclName(writer, fn_decl, 0);
            break :callee;
        }
        // Fall back to function pointer call.
        try f.writeCValue(writer, callee, .Other);
    }

    try writer.writeByte('(');
    var args_written: usize = 0;
    for (args) |arg, arg_i| {
        const ty = f.air.typeOf(arg);
        if (!ty.hasRuntimeBitsIgnoreComptime()) continue;
        if (args_written != 0) {
            try writer.writeAll(", ");
        }
        if ((is_extern or std.mem.eql(u8, std.mem.span(name), "main")) and
            ty.isCPtr() and ty.childType().tag() == .u8)
        {
            // Corresponds with hack in renderType .Pointer case.
            try writer.writeAll("(char");
            if (ty.isConstPtr()) try writer.writeAll(" const");
            if (ty.isVolatilePtr()) try writer.writeAll(" volatile");
            try writer.writeAll(" *)");
        }
        try f.writeCValue(writer, resolved_args[arg_i], .FunctionArgument);
        args_written += 1;
    }
    try writer.writeAll(");\n");

    const result = r: {
        if (result_local == .none or !lowersToArray(ret_ty, target))
            break :r result_local;

        const array_local = try f.allocLocal(inst, ret_ty);
        try writer.writeAll("memcpy(");
        try f.writeCValue(writer, array_local, .FunctionArgument);
        try writer.writeAll(", ");
        try f.writeCValueMember(writer, result_local, .{ .field = 0 });
        try writer.writeAll(", sizeof(");
        try f.renderTypecast(writer, ret_ty);
        try writer.writeAll("));\n");
        try freeLocal(f, inst, result_local.local, 0);
        break :r array_local;
    };

    return result;
}

fn airDbgStmt(f: *Function, inst: Air.Inst.Index) !CValue {
    const dbg_stmt = f.air.instructions.items(.data)[inst].dbg_stmt;
    const writer = f.object.writer();
    // TODO re-evaluate whether to emit these or not. If we naively emit
    // these directives, the output file will report bogus line numbers because
    // every newline after the #line directive adds one to the line.
    // We also don't print the filename yet, so the output is strictly unhelpful.
    // If we wanted to go this route, we would need to go all the way and not output
    // newlines until the next dbg_stmt occurs.
    // Perhaps an additional compilation option is in order?
    //try writer.print("#line {d}\n", .{dbg_stmt.line + 1});
    try writer.print("/* file:{d}:{d} */\n", .{ dbg_stmt.line + 1, dbg_stmt.column + 1 });
    return CValue.none;
}

fn airDbgInline(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_pl = f.air.instructions.items(.data)[inst].ty_pl;
    const writer = f.object.writer();
    const function = f.air.values[ty_pl.payload].castTag(.function).?.data;
    const mod = f.object.dg.module;
    try writer.print("/* dbg func:{s} */\n", .{mod.declPtr(function.owner_decl).name});
    return CValue.none;
}

fn airDbgVar(f: *Function, inst: Air.Inst.Index) !CValue {
    const pl_op = f.air.instructions.items(.data)[inst].pl_op;
    const name = f.air.nullTerminatedString(pl_op.payload);
    const operand = try f.resolveInst(pl_op.operand);
    _ = operand;
    try reap(f, inst, &.{pl_op.operand});
    const writer = f.object.writer();
    try writer.print("/* var:{s} */\n", .{name});
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
    const result = if (inst_ty.tag() != .void and !f.liveness.isUnused(inst))
        try f.allocLocal(inst, inst_ty)
    else
        CValue{ .none = {} };

    try f.blocks.putNoClobber(f.object.dg.gpa, inst, .{
        .block_id = block_id,
        .result = result,
    });

    try genBodyInner(f, body);
    try f.object.indent_writer.insertNewline();
    // label must be followed by an expression, add an empty one.
    try writer.print("zig_block_{d}:;\n", .{block_id});
    return result;
}

fn airTry(f: *Function, inst: Air.Inst.Index) !CValue {
    const pl_op = f.air.instructions.items(.data)[inst].pl_op;
    const extra = f.air.extraData(Air.Try, pl_op.payload);
    const body = f.air.extra[extra.end..][0..extra.data.body_len];
    const err_union_ty = f.air.typeOf(pl_op.operand);
    return lowerTry(f, inst, pl_op.operand, body, err_union_ty, false);
}

fn airTryPtr(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_pl = f.air.instructions.items(.data)[inst].ty_pl;
    const extra = f.air.extraData(Air.TryPtr, ty_pl.payload);
    const body = f.air.extra[extra.end..][0..extra.data.body_len];
    const err_union_ty = f.air.typeOf(extra.data.ptr).childType();
    return lowerTry(f, inst, extra.data.ptr, body, err_union_ty, true);
}

fn lowerTry(
    f: *Function,
    inst: Air.Inst.Index,
    operand: Air.Inst.Ref,
    body: []const Air.Inst.Index,
    err_union_ty: Type,
    operand_is_ptr: bool,
) !CValue {
    const err_union = try f.resolveInst(operand);
    const result_ty = f.air.typeOfIndex(inst);
    const writer = f.object.writer();
    const payload_ty = err_union_ty.errorUnionPayload();
    const payload_has_bits = payload_ty.hasRuntimeBitsIgnoreComptime();

    if (!err_union_ty.errorUnionSet().errorSetIsEmpty()) {
        try writer.writeAll("if (");
        if (!payload_has_bits) {
            if (operand_is_ptr)
                try f.writeCValueDeref(writer, err_union)
            else
                try f.writeCValue(writer, err_union, .Other);
        } else {
            // Reap the operand so that it can be reused inside genBody.
            // Remember we must avoid calling reap() twice for the same operand
            // in this function.
            try reap(f, inst, &.{operand});
            if (operand_is_ptr or isByRef(err_union_ty))
                try f.writeCValueDerefMember(writer, err_union, .{ .identifier = "error" })
            else
                try f.writeCValueMember(writer, err_union, .{ .identifier = "error" });
        }
        try writer.writeByte(')');

        try genBody(f, body);
        try f.object.indent_writer.insertNewline();
    }

    if (!payload_has_bits) {
        if (!operand_is_ptr) {
            return CValue.none;
        } else {
            return err_union;
        }
    }

    try reap(f, inst, &.{operand});

    if (f.liveness.isUnused(inst)) {
        return CValue.none;
    }

    const target = f.object.dg.module.getTarget();
    const is_array = lowersToArray(payload_ty, target);
    const local = try f.allocLocal(inst, result_ty);
    if (is_array) {
        try writer.writeAll("memcpy(");
        try f.writeCValue(writer, local, .FunctionArgument);
        try writer.writeAll(", ");
        try f.writeCValueMember(writer, err_union, .{ .identifier = "payload" });
        try writer.writeAll(", sizeof(");
        try f.renderTypecast(writer, payload_ty);
        try writer.writeAll("));\n");
    } else {
        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(" = ");
        if (operand_is_ptr or isByRef(payload_ty)) {
            try writer.writeByte('&');
            try f.writeCValueDerefMember(writer, err_union, .{ .identifier = "payload" });
        } else try f.writeCValueMember(writer, err_union, .{ .identifier = "payload" });
        try writer.writeAll(";\n");
    }
    return local;
}

fn airBr(f: *Function, inst: Air.Inst.Index) !CValue {
    const branch = f.air.instructions.items(.data)[inst].br;
    const block = f.blocks.get(branch.block_inst).?;
    const result = block.result;
    const writer = f.object.writer();

    // If result is .none then the value of the block is unused.
    if (result != .none) {
        const operand = try f.resolveInst(branch.operand);
        try reap(f, inst, &.{branch.operand});

        const operand_ty = f.air.typeOf(branch.operand);
        const target = f.object.dg.module.getTarget();
        if (lowersToArray(operand_ty, target)) {
            try writer.writeAll("memcpy(");
            try f.writeCValue(writer, result, .FunctionArgument);
            try writer.writeAll(", ");
            try f.writeCValue(writer, operand, .FunctionArgument);
            try writer.writeAll(", sizeof(");
            try f.renderTypecast(writer, operand_ty);
            try writer.writeAll("))");
        } else {
            try f.writeCValue(writer, result, .Other);
            try writer.writeAll(" = ");
            try f.writeCValue(writer, operand, .Other);
        }
        try writer.writeAll(";\n");
    }

    try writer.print("goto zig_block_{d};\n", .{block.block_id});
    return CValue.none;
}

fn airBitcast(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    const dest_ty = f.air.typeOfIndex(inst);
    // No IgnoreComptime until Sema stops giving us garbage Air.
    // https://github.com/ziglang/zig/issues/13410
    if (f.liveness.isUnused(inst) or !dest_ty.hasRuntimeBits()) {
        try reap(f, inst, &.{ty_op.operand});
        return CValue.none;
    }

    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const operand_ty = f.air.typeOf(ty_op.operand);
    const target = f.object.dg.module.getTarget();
    const writer = f.object.writer();

    const local = try f.allocLocal(inst, dest_ty);

    if (operand_ty.isAbiInt() and dest_ty.isAbiInt()) {
        const src_info = dest_ty.intInfo(target);
        const dest_info = operand_ty.intInfo(target);
        if (src_info.signedness == dest_info.signedness and
            src_info.bits == dest_info.bits)
        {
            try f.writeCValue(writer, local, .Other);
            try writer.writeAll(" = ");
            try f.writeCValue(writer, operand, .Other);
            try writer.writeAll(";\n");
            return local;
        }
    }

    if (dest_ty.isPtrAtRuntime() and operand_ty.isPtrAtRuntime()) {
        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(" = (");
        try f.renderTypecast(writer, dest_ty);
        try writer.writeByte(')');
        try f.writeCValue(writer, operand, .Other);
        try writer.writeAll(";\n");
        return local;
    }

    const operand_lval = if (operand == .constant) blk: {
        const operand_local = try f.allocLocal(inst, operand_ty);
        try f.writeCValue(writer, operand_local, .Other);
        try writer.writeAll(" = ");
        try f.writeCValue(writer, operand, .Initializer);
        try writer.writeAll(";\n");
        break :blk operand_local;
    } else operand;

    try writer.writeAll("memcpy(&");
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(", &");
    try f.writeCValue(writer, operand_lval, .Other);
    try writer.writeAll(", sizeof(");
    try f.renderTypecast(writer, dest_ty);
    try writer.writeAll("));\n");

    // Ensure padding bits have the expected value.
    if (dest_ty.isAbiInt()) {
        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(" = zig_wrap_");
        try f.object.dg.renderTypeForBuiltinFnName(writer, dest_ty);
        try writer.writeByte('(');
        try f.writeCValue(writer, local, .Other);
        try f.object.dg.renderBuiltinInfo(writer, dest_ty, .Bits);
        try writer.writeAll(");\n");
    }

    if (operand == .constant) {
        try freeLocal(f, inst, operand_lval.local, 0);
    }

    return local;
}

fn airBreakpoint(writer: anytype) !CValue {
    try writer.writeAll("zig_breakpoint();\n");
    return CValue.none;
}

fn airRetAddr(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst)) return CValue.none;
    const writer = f.object.writer();
    const local = try f.allocLocal(inst, Type.usize);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = (");
    try f.renderTypecast(writer, Type.usize);
    try writer.writeAll(")zig_return_address();\n");
    return local;
}

fn airFrameAddress(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst)) return CValue.none;
    const writer = f.object.writer();
    const local = try f.allocLocal(inst, Type.usize);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = (");
    try f.renderTypecast(writer, Type.usize);
    try writer.writeAll(")zig_frame_address();\n");
    return local;
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
    // Not even allowed to call unreachable in a naked function.
    if (f.object.dg.decl.ty.fnCallingConvention() == .Naked) return .none;

    try f.object.writer().writeAll("zig_unreachable();\n");
    return CValue.none;
}

fn airLoop(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_pl = f.air.instructions.items(.data)[inst].ty_pl;
    const loop = f.air.extraData(Air.Block, ty_pl.payload);
    const body = f.air.extra[loop.end..][0..loop.data.body_len];
    const writer = f.object.writer();

    const gpa = f.object.dg.gpa;
    try f.free_locals_stack.insert(gpa, f.free_locals_stack.items.len - 1, .{});

    try writer.writeAll("for (;;) ");
    try genBody(f, body);
    try writer.writeByte('\n');

    var old_free_locals = f.free_locals_stack.pop();
    defer deinitFreeLocalsMap(gpa, &old_free_locals);
    const new_free_locals = f.getFreeLocals();
    var it = new_free_locals.iterator();
    while (it.next()) |entry| {
        const gop = try old_free_locals.getOrPutContext(gpa, entry.key_ptr.*, f.tyHashCtx());
        if (gop.found_existing) {
            try gop.value_ptr.appendSlice(gpa, entry.value_ptr.items);
        } else {
            gop.value_ptr.* = entry.value_ptr.*;
            entry.value_ptr.* = .{};
        }
    }
    deinitFreeLocalsMap(gpa, new_free_locals);
    new_free_locals.* = old_free_locals.move();

    return CValue.none;
}

fn airCondBr(f: *Function, inst: Air.Inst.Index) !CValue {
    const pl_op = f.air.instructions.items(.data)[inst].pl_op;
    const cond = try f.resolveInst(pl_op.operand);
    try reap(f, inst, &.{pl_op.operand});
    const extra = f.air.extraData(Air.CondBr, pl_op.payload);
    const then_body = f.air.extra[extra.end..][0..extra.data.then_body_len];
    const else_body = f.air.extra[extra.end + then_body.len ..][0..extra.data.else_body_len];
    const liveness_condbr = f.liveness.getCondBr(inst);
    const writer = f.object.writer();

    // Keep using the original for the then branch; use a clone of the value
    // map for the else branch.
    const gpa = f.object.dg.gpa;
    var cloned_map = try f.value_map.clone();
    defer cloned_map.deinit();
    var cloned_frees = try cloneFreeLocalsMap(gpa, f.getFreeLocals());
    defer deinitFreeLocalsMap(gpa, &cloned_frees);

    // Remember how many locals there were before entering the then branch so
    // that we can notice and use them in the else branch. Any new locals must
    // necessarily be free already after the then branch is complete.
    const pre_locals_len = @intCast(LocalIndex, f.locals.items.len);
    const pre_clone_depth = f.free_locals_clone_depth;
    f.free_locals_clone_depth = @intCast(LoopDepth, f.free_locals_stack.items.len);

    for (liveness_condbr.then_deaths) |operand| {
        try die(f, inst, Air.indexToRef(operand));
    }

    try writer.writeAll("if (");
    try f.writeCValue(writer, cond, .Other);
    try writer.writeAll(") ");
    try genBody(f, then_body);
    try writer.writeAll(" else ");
    f.value_map.deinit();
    f.value_map = cloned_map.move();
    const free_locals = f.getFreeLocals();
    deinitFreeLocalsMap(gpa, free_locals);
    free_locals.* = cloned_frees.move();
    f.free_locals_clone_depth = pre_clone_depth;
    for (liveness_condbr.else_deaths) |operand| {
        try die(f, inst, Air.indexToRef(operand));
    }

    try noticeBranchFrees(f, pre_locals_len, inst);

    try genBody(f, else_body);
    try f.object.indent_writer.insertNewline();

    return CValue.none;
}

fn airSwitchBr(f: *Function, inst: Air.Inst.Index) !CValue {
    const pl_op = f.air.instructions.items(.data)[inst].pl_op;
    const condition = try f.resolveInst(pl_op.operand);
    try reap(f, inst, &.{pl_op.operand});
    const condition_ty = f.air.typeOf(pl_op.operand);
    const switch_br = f.air.extraData(Air.SwitchBr, pl_op.payload);
    const writer = f.object.writer();

    try writer.writeAll("switch (");
    if (condition_ty.zigTypeTag() == .Bool) {
        try writer.writeByte('(');
        try f.renderTypecast(writer, Type.u1);
        try writer.writeByte(')');
    } else if (condition_ty.isPtrAtRuntime()) {
        try writer.writeByte('(');
        try f.renderTypecast(writer, Type.usize);
        try writer.writeByte(')');
    }
    try f.writeCValue(writer, condition, .Other);
    try writer.writeAll(") {");
    f.object.indent_writer.pushIndent();

    const gpa = f.object.dg.gpa;
    const liveness = try f.liveness.getSwitchBr(gpa, inst, switch_br.data.cases_len + 1);
    defer gpa.free(liveness.deaths);

    // On the final iteration we do not clone the map. This ensures that
    // lowering proceeds after the switch_br taking into account the
    // mutations to the liveness information.
    const last_case_i = switch_br.data.cases_len - @boolToInt(switch_br.data.else_body_len == 0);

    var extra_index: usize = switch_br.end;
    var case_i: u32 = 0;
    while (case_i < switch_br.data.cases_len) : (case_i += 1) {
        const case = f.air.extraData(Air.SwitchBr.Case, extra_index);
        const items = @ptrCast([]const Air.Inst.Ref, f.air.extra[case.end..][0..case.data.items_len]);
        const case_body = f.air.extra[case.end + items.len ..][0..case.data.body_len];
        extra_index = case.end + case.data.items_len + case_body.len;

        for (items) |item| {
            try f.object.indent_writer.insertNewline();
            try writer.writeAll("case ");
            if (condition_ty.isPtrAtRuntime()) {
                try writer.writeByte('(');
                try f.renderTypecast(writer, Type.usize);
                try writer.writeByte(')');
            }
            try f.object.dg.renderValue(writer, condition_ty, f.air.value(item).?, .Other);
            try writer.writeAll(": ");
        }

        if (case_i != last_case_i) {
            const old_value_map = f.value_map;
            f.value_map = try old_value_map.clone();
            var free_locals = f.getFreeLocals();
            const old_free_locals = free_locals.*;
            free_locals.* = try cloneFreeLocalsMap(gpa, free_locals);

            // Remember how many locals there were before entering each branch so that
            // we can notice and use them in subsequent branches. Any new locals must
            // necessarily be free already after the previous branch is complete.
            const pre_locals_len = @intCast(LocalIndex, f.locals.items.len);
            const pre_clone_depth = f.free_locals_clone_depth;
            f.free_locals_clone_depth = @intCast(LoopDepth, f.free_locals_stack.items.len);

            {
                defer {
                    f.free_locals_clone_depth = pre_clone_depth;
                    f.value_map.deinit();
                    free_locals = f.getFreeLocals();
                    deinitFreeLocalsMap(gpa, free_locals);
                    f.value_map = old_value_map;
                    free_locals.* = old_free_locals;
                }

                for (liveness.deaths[case_i]) |operand| {
                    try die(f, inst, Air.indexToRef(operand));
                }

                try genBody(f, case_body);
            }

            try noticeBranchFrees(f, pre_locals_len, inst);
        } else {
            for (liveness.deaths[case_i]) |operand| {
                try die(f, inst, Air.indexToRef(operand));
            }
            try genBody(f, case_body);
        }

        // The case body must be noreturn so we don't need to insert a break.

    }

    const else_body = f.air.extra[extra_index..][0..switch_br.data.else_body_len];
    try f.object.indent_writer.insertNewline();
    if (else_body.len > 0) {
        for (liveness.deaths[liveness.deaths.len - 1]) |operand| {
            try die(f, inst, Air.indexToRef(operand));
        }
        try writer.writeAll("default: ");
        try genBody(f, else_body);
    } else {
        try writer.writeAll("default: zig_unreachable();");
    }
    try f.object.indent_writer.insertNewline();

    f.object.indent_writer.popIndent();
    try writer.writeAll("}\n");
    return CValue.none;
}

fn asmInputNeedsLocal(constraint: []const u8, value: CValue) bool {
    return switch (constraint[0]) {
        '{' => true,
        'i', 'r' => false,
        else => value == .constant,
    };
}

fn airAsm(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_pl = f.air.instructions.items(.data)[inst].ty_pl;
    const extra = f.air.extraData(Air.Asm, ty_pl.payload);
    const is_volatile = @truncate(u1, extra.data.flags >> 31) != 0;
    const clobbers_len = @truncate(u31, extra.data.flags);
    var extra_i: usize = extra.end;
    const outputs = @ptrCast([]const Air.Inst.Ref, f.air.extra[extra_i..][0..extra.data.outputs_len]);
    extra_i += outputs.len;
    const inputs = @ptrCast([]const Air.Inst.Ref, f.air.extra[extra_i..][0..extra.data.inputs_len]);
    extra_i += inputs.len;

    const result: CValue = r: {
        if (!is_volatile and f.liveness.isUnused(inst)) break :r CValue.none;

        const writer = f.object.writer();
        const inst_ty = f.air.typeOfIndex(inst);
        const local = if (inst_ty.hasRuntimeBitsIgnoreComptime()) local: {
            const local = try f.allocLocal(inst, inst_ty);
            if (f.wantSafety()) {
                try f.writeCValue(writer, local, .Other);
                try writer.writeAll(" = ");
                try f.writeCValue(writer, .{ .undef = inst_ty }, .Initializer);
                try writer.writeAll(";\n");
            }
            break :local local;
        } else .none;

        const locals_begin = @intCast(LocalIndex, f.locals.items.len);
        const constraints_extra_begin = extra_i;
        for (outputs) |output| {
            const extra_bytes = std.mem.sliceAsBytes(f.air.extra[extra_i..]);
            const constraint = std.mem.sliceTo(extra_bytes, 0);
            const name = std.mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
            // This equation accounts for the fact that even if we have exactly 4 bytes
            // for the string, we still use the next u32 for the null terminator.
            extra_i += (constraint.len + name.len + (2 + 3)) / 4;

            if (constraint.len < 2 or constraint[0] != '=' or
                (constraint[1] == '{' and constraint[constraint.len - 1] != '}'))
            {
                return f.fail("CBE: constraint not supported: '{s}'", .{constraint});
            }

            const is_reg = constraint[1] == '{';
            if (is_reg) {
                const output_ty = if (output == .none) inst_ty else f.air.typeOf(output).childType();
                try writer.writeAll("register ");
                const alignment = 0;
                const local_value = try f.allocLocalValue(output_ty, alignment);
                try f.object.dg.renderTypeAndName(
                    writer,
                    output_ty,
                    local_value,
                    .Mut,
                    alignment,
                    .Complete,
                );
                try writer.writeAll(" __asm(\"");
                try writer.writeAll(constraint["={".len .. constraint.len - "}".len]);
                try writer.writeAll("\")");
                if (f.wantSafety()) {
                    try writer.writeAll(" = ");
                    try f.writeCValue(writer, .{ .undef = output_ty }, .Initializer);
                }
                try writer.writeAll(";\n");
            }
        }
        for (inputs) |input| {
            const extra_bytes = std.mem.sliceAsBytes(f.air.extra[extra_i..]);
            const constraint = std.mem.sliceTo(extra_bytes, 0);
            const name = std.mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
            // This equation accounts for the fact that even if we have exactly 4 bytes
            // for the string, we still use the next u32 for the null terminator.
            extra_i += (constraint.len + name.len + (2 + 3)) / 4;

            if (constraint.len < 1 or std.mem.indexOfScalar(u8, "=+&%", constraint[0]) != null or
                (constraint[0] == '{' and constraint[constraint.len - 1] != '}'))
            {
                return f.fail("CBE: constraint not supported: '{s}'", .{constraint});
            }

            const is_reg = constraint[0] == '{';
            const input_val = try f.resolveInst(input);
            if (asmInputNeedsLocal(constraint, input_val)) {
                const input_ty = f.air.typeOf(input);
                if (is_reg) try writer.writeAll("register ");
                const alignment = 0;
                const local_value = try f.allocLocalValue(input_ty, alignment);
                try f.object.dg.renderTypeAndName(
                    writer,
                    input_ty,
                    local_value,
                    .Const,
                    alignment,
                    .Complete,
                );
                if (is_reg) {
                    try writer.writeAll(" __asm(\"");
                    try writer.writeAll(constraint["{".len .. constraint.len - "}".len]);
                    try writer.writeAll("\")");
                }
                try writer.writeAll(" = ");
                try f.writeCValue(writer, input_val, .Initializer);
                try writer.writeAll(";\n");
            }
        }
        {
            var clobber_i: u32 = 0;
            while (clobber_i < clobbers_len) : (clobber_i += 1) {
                const clobber = std.mem.sliceTo(std.mem.sliceAsBytes(f.air.extra[extra_i..]), 0);
                // This equation accounts for the fact that even if we have exactly 4 bytes
                // for the string, we still use the next u32 for the null terminator.
                extra_i += clobber.len / 4 + 1;
            }
        }

        {
            const asm_source = mem.sliceAsBytes(f.air.extra[extra_i..])[0..extra.data.source_len];

            var stack = std.heap.stackFallback(256, f.object.dg.gpa);
            const allocator = stack.get();
            const fixed_asm_source = try allocator.alloc(u8, asm_source.len);
            defer allocator.free(fixed_asm_source);

            var src_i: usize = 0;
            var dst_i: usize = 0;
            while (true) {
                const literal = mem.sliceTo(asm_source[src_i..], '%');
                src_i += literal.len;

                mem.copy(u8, fixed_asm_source[dst_i..], literal);
                dst_i += literal.len;

                if (src_i >= asm_source.len) break;

                src_i += 1;
                if (src_i >= asm_source.len)
                    return f.fail("CBE: invalid inline asm string '{s}'", .{asm_source});

                fixed_asm_source[dst_i] = '%';
                dst_i += 1;

                if (asm_source[src_i] != '[') {
                    // This also handles %%
                    fixed_asm_source[dst_i] = asm_source[src_i];
                    src_i += 1;
                    dst_i += 1;
                    continue;
                }

                const desc = mem.sliceTo(asm_source[src_i..], ']');
                if (mem.indexOfScalar(u8, desc, ':')) |colon| {
                    const name = desc[0..colon];
                    const modifier = desc[colon + 1 ..];

                    mem.copy(u8, fixed_asm_source[dst_i..], modifier);
                    dst_i += modifier.len;
                    mem.copy(u8, fixed_asm_source[dst_i..], name);
                    dst_i += name.len;

                    src_i += desc.len;
                    if (src_i >= asm_source.len)
                        return f.fail("CBE: invalid inline asm string '{s}'", .{asm_source});
                }
            }

            try writer.writeAll("__asm");
            if (is_volatile) try writer.writeAll(" volatile");
            try writer.print("({s}", .{fmtStringLiteral(fixed_asm_source[0..dst_i])});
        }

        extra_i = constraints_extra_begin;
        var locals_index = locals_begin;
        try writer.writeByte(':');
        for (outputs) |output, index| {
            const extra_bytes = std.mem.sliceAsBytes(f.air.extra[extra_i..]);
            const constraint = std.mem.sliceTo(extra_bytes, 0);
            const name = std.mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
            // This equation accounts for the fact that even if we have exactly 4 bytes
            // for the string, we still use the next u32 for the null terminator.
            extra_i += (constraint.len + name.len + (2 + 3)) / 4;

            if (index > 0) try writer.writeByte(',');
            try writer.writeByte(' ');
            if (!std.mem.eql(u8, name, "_")) try writer.print("[{s}]", .{name});
            const is_reg = constraint[1] == '{';
            try writer.print("{s}(", .{fmtStringLiteral(if (is_reg) "=r" else constraint)});
            if (is_reg) {
                try f.writeCValue(writer, .{ .local = locals_index }, .Other);
                locals_index += 1;
            } else if (output == .none) {
                try f.writeCValue(writer, local, .FunctionArgument);
            } else {
                try f.writeCValueDeref(writer, try f.resolveInst(output));
            }
            try writer.writeByte(')');
        }
        try writer.writeByte(':');
        for (inputs) |input, index| {
            const extra_bytes = std.mem.sliceAsBytes(f.air.extra[extra_i..]);
            const constraint = std.mem.sliceTo(extra_bytes, 0);
            const name = std.mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
            // This equation accounts for the fact that even if we have exactly 4 bytes
            // for the string, we still use the next u32 for the null terminator.
            extra_i += (constraint.len + name.len + (2 + 3)) / 4;

            if (index > 0) try writer.writeByte(',');
            try writer.writeByte(' ');
            if (!std.mem.eql(u8, name, "_")) try writer.print("[{s}]", .{name});

            const is_reg = constraint[0] == '{';
            const input_val = try f.resolveInst(input);
            try writer.print("{s}(", .{fmtStringLiteral(if (is_reg) "r" else constraint)});
            try f.writeCValue(writer, if (asmInputNeedsLocal(constraint, input_val)) local: {
                const input_local = CValue{ .local = locals_index };
                locals_index += 1;
                break :local input_local;
            } else input_val, .Other);
            try writer.writeByte(')');
        }
        try writer.writeByte(':');
        {
            var clobber_i: u32 = 0;
            while (clobber_i < clobbers_len) : (clobber_i += 1) {
                const clobber = std.mem.sliceTo(std.mem.sliceAsBytes(f.air.extra[extra_i..]), 0);
                // This equation accounts for the fact that even if we have exactly 4 bytes
                // for the string, we still use the next u32 for the null terminator.
                extra_i += clobber.len / 4 + 1;

                if (clobber.len == 0) continue;

                if (clobber_i > 0) try writer.writeByte(',');
                try writer.print(" {s}", .{fmtStringLiteral(clobber)});
            }
        }
        try writer.writeAll(");\n");

        extra_i = constraints_extra_begin;
        locals_index = locals_begin;
        for (outputs) |output| {
            const extra_bytes = std.mem.sliceAsBytes(f.air.extra[extra_i..]);
            const constraint = std.mem.sliceTo(extra_bytes, 0);
            const name = std.mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
            // This equation accounts for the fact that even if we have exactly 4 bytes
            // for the string, we still use the next u32 for the null terminator.
            extra_i += (constraint.len + name.len + (2 + 3)) / 4;

            const is_reg = constraint[1] == '{';
            if (is_reg) {
                try f.writeCValueDeref(writer, if (output == .none)
                    CValue{ .local_ref = local.local }
                else
                    try f.resolveInst(output));
                try writer.writeAll(" = ");
                try f.writeCValue(writer, .{ .local = locals_index }, .Other);
                locals_index += 1;
                try writer.writeAll(";\n");
            }
        }

        break :r local;
    };

    var bt = iterateBigTomb(f, inst);
    for (outputs) |output| {
        if (output == .none) continue;
        try bt.feed(output);
    }
    for (inputs) |input| {
        try bt.feed(input);
    }

    return result;
}

fn airIsNull(
    f: *Function,
    inst: Air.Inst.Index,
    operator: []const u8,
    is_ptr: bool,
) !CValue {
    const un_op = f.air.instructions.items(.data)[inst].un_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{un_op});
        return CValue.none;
    }

    const writer = f.object.writer();
    const operand = try f.resolveInst(un_op);
    try reap(f, inst, &.{un_op});

    const local = try f.allocLocal(inst, Type.bool);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = ");
    if (is_ptr) {
        try f.writeCValueDeref(writer, operand);
    } else {
        try f.writeCValue(writer, operand, .Other);
    }

    const operand_ty = f.air.typeOf(un_op);
    const optional_ty = if (is_ptr) operand_ty.childType() else operand_ty;
    var payload_buf: Type.Payload.ElemType = undefined;
    const payload_ty = optional_ty.optionalChild(&payload_buf);
    var slice_ptr_buf: Type.SlicePtrFieldTypeBuffer = undefined;

    const rhs = if (!payload_ty.hasRuntimeBitsIgnoreComptime())
        TypedValue{ .ty = Type.bool, .val = Value.true }
    else if (optional_ty.isPtrLikeOptional())
        // operand is a regular pointer, test `operand !=/== NULL`
        TypedValue{ .ty = optional_ty, .val = Value.null }
    else if (payload_ty.zigTypeTag() == .ErrorSet)
        TypedValue{ .ty = payload_ty, .val = Value.zero }
    else if (payload_ty.isSlice() and optional_ty.optionalReprIsPayload()) rhs: {
        try writer.writeAll(".ptr");
        const slice_ptr_ty = payload_ty.slicePtrFieldType(&slice_ptr_buf);
        break :rhs TypedValue{ .ty = slice_ptr_ty, .val = Value.null };
    } else rhs: {
        try writer.writeAll(".is_null");
        break :rhs TypedValue{ .ty = Type.bool, .val = Value.true };
    };
    try writer.writeByte(' ');
    try writer.writeAll(operator);
    try writer.writeByte(' ');
    try f.object.dg.renderValue(writer, rhs.ty, rhs.val, .Other);
    try writer.writeAll(";\n");
    return local;
}

fn airOptionalPayload(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ty_op.operand});
        return CValue.none;
    }

    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const opt_ty = f.air.typeOf(ty_op.operand);

    var buf: Type.Payload.ElemType = undefined;
    const payload_ty = opt_ty.optionalChild(&buf);

    if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
        return CValue.none;
    }

    const inst_ty = f.air.typeOfIndex(inst);
    const local = try f.allocLocal(inst, inst_ty);
    const writer = f.object.writer();

    if (opt_ty.optionalReprIsPayload()) {
        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(" = ");
        try f.writeCValue(writer, operand, .Other);
        try writer.writeAll(";\n");
        return local;
    }

    const target = f.object.dg.module.getTarget();
    const is_array = lowersToArray(inst_ty, target);

    if (is_array) {
        try writer.writeAll("memcpy(");
        try f.writeCValue(writer, local, .FunctionArgument);
        try writer.writeAll(", ");
    } else {
        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(" = ");
    }
    try f.writeCValueMember(writer, operand, .{ .identifier = "payload" });
    if (is_array) {
        try writer.writeAll(", sizeof(");
        try f.renderTypecast(writer, inst_ty);
        try writer.writeAll("))");
    }
    try writer.writeAll(";\n");
    return local;
}

fn airOptionalPayloadPtr(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ty_op.operand});
        return CValue.none;
    }

    const writer = f.object.writer();
    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const ptr_ty = f.air.typeOf(ty_op.operand);
    const opt_ty = ptr_ty.childType();
    const inst_ty = f.air.typeOfIndex(inst);

    if (!inst_ty.childType().hasRuntimeBitsIgnoreComptime()) {
        return CValue{ .undef = inst_ty };
    }

    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);

    if (opt_ty.optionalReprIsPayload()) {
        // the operand is just a regular pointer, no need to do anything special.
        // *?*T -> **T and ?*T -> *T are **T -> **T and *T -> *T in C
        try writer.writeAll(" = ");
        try f.writeCValue(writer, operand, .Other);
    } else {
        try writer.writeAll(" = &");
        try f.writeCValueDerefMember(writer, operand, .{ .identifier = "payload" });
    }
    try writer.writeAll(";\n");
    return local;
}

fn airOptionalPayloadPtrSet(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    const writer = f.object.writer();
    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const operand_ty = f.air.typeOf(ty_op.operand);

    const opt_ty = operand_ty.elemType();

    const inst_ty = f.air.typeOfIndex(inst);

    if (opt_ty.optionalReprIsPayload()) {
        if (f.liveness.isUnused(inst)) {
            return CValue.none;
        }
        const local = try f.allocLocal(inst, inst_ty);
        // The payload and the optional are the same value.
        // Setting to non-null will be done when the payload is set.
        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(" = ");
        try f.writeCValue(writer, operand, .Other);
        try writer.writeAll(";\n");
        return local;
    } else {
        try f.writeCValueDeref(writer, operand);
        try writer.writeAll(".is_null = ");
        try f.object.dg.renderValue(writer, Type.bool, Value.false, .Initializer);
        try writer.writeAll(";\n");

        if (f.liveness.isUnused(inst)) {
            return CValue.none;
        }

        const local = try f.allocLocal(inst, inst_ty);
        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(" = &");
        try f.writeCValueDeref(writer, operand);
        try writer.writeAll(".payload;\n");
        return local;
    }
}

fn airStructFieldPtr(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_pl = f.air.instructions.items(.data)[inst].ty_pl;
    const extra = f.air.extraData(Air.StructField, ty_pl.payload).data;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{extra.struct_operand});
        // TODO this @as is needed because of a stage1 bug
        return @as(CValue, CValue.none);
    }

    const struct_ptr = try f.resolveInst(extra.struct_operand);
    try reap(f, inst, &.{extra.struct_operand});
    const struct_ptr_ty = f.air.typeOf(extra.struct_operand);
    return structFieldPtr(f, inst, struct_ptr_ty, struct_ptr, extra.field_index);
}

fn airStructFieldPtrIndex(f: *Function, inst: Air.Inst.Index, index: u8) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ty_op.operand});
        // TODO this @as is needed because of a stage1 bug
        return @as(CValue, CValue.none);
    }

    const struct_ptr = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const struct_ptr_ty = f.air.typeOf(ty_op.operand);
    return structFieldPtr(f, inst, struct_ptr_ty, struct_ptr, index);
}

fn airFieldParentPtr(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_pl = f.air.instructions.items(.data)[inst].ty_pl;
    const extra = f.air.extraData(Air.FieldParentPtr, ty_pl.payload).data;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{extra.field_ptr});
        return CValue.none;
    }

    const struct_ptr_ty = f.air.typeOfIndex(inst);
    const field_ptr_ty = f.air.typeOf(extra.field_ptr);
    const field_ptr_val = try f.resolveInst(extra.field_ptr);
    try reap(f, inst, &.{extra.field_ptr});

    const target = f.object.dg.module.getTarget();
    const struct_ty = struct_ptr_ty.childType();
    const field_offset = struct_ty.structFieldOffset(extra.field_index, target);

    var field_offset_pl = Value.Payload.I64{
        .base = .{ .tag = .int_i64 },
        .data = -@intCast(i64, field_offset),
    };
    const field_offset_val = Value.initPayload(&field_offset_pl.base);

    var u8_ptr_pl = field_ptr_ty.ptrInfo();
    u8_ptr_pl.data.pointee_type = Type.u8;
    const u8_ptr_ty = Type.initPayload(&u8_ptr_pl.base);

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, struct_ptr_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = (");
    try f.renderTypecast(writer, struct_ptr_ty);
    try writer.writeAll(")&((");
    try f.renderTypecast(writer, u8_ptr_ty);
    try writer.writeByte(')');
    try f.writeCValue(writer, field_ptr_val, .Other);
    try writer.print(")[{}];\n", .{try f.fmtIntLiteral(Type.isize, field_offset_val)});
    return local;
}

fn structFieldPtr(f: *Function, inst: Air.Inst.Index, struct_ptr_ty: Type, struct_ptr: CValue, index: u32) !CValue {
    const writer = f.object.writer();
    const field_ptr_ty = f.air.typeOfIndex(inst);
    const field_ptr_info = field_ptr_ty.ptrInfo();
    const struct_ty = struct_ptr_ty.elemType();
    const field_ty = struct_ty.structFieldType(index);

    // Ensure complete type definition is visible before accessing fields.
    try f.renderType(std.io.null_writer, struct_ty);

    const local = try f.allocLocal(inst, field_ptr_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = (");
    try f.renderTypecast(writer, field_ptr_ty);
    try writer.writeByte(')');

    const extra_name: CValue = switch (struct_ty.tag()) {
        .union_tagged, .union_safety_tagged => .{ .identifier = "payload" },
        else => .none,
    };

    const FieldLoc = union(enum) {
        begin: void,
        field: CValue,
        end: void,
    };
    const field_loc = switch (struct_ty.tag()) {
        .@"struct" => switch (struct_ty.containerLayout()) {
            .Auto, .Extern => for (struct_ty.structFields().values()[index..]) |field, offset| {
                if (field.ty.hasRuntimeBitsIgnoreComptime()) break FieldLoc{ .field = .{
                    .identifier = struct_ty.structFieldName(index + offset),
                } };
            } else @as(FieldLoc, .end),
            .Packed => if (field_ptr_info.data.host_size == 0) {
                const target = f.object.dg.module.getTarget();

                const byte_offset = struct_ty.packedStructFieldByteOffset(index, target);
                var byte_offset_pl = Value.Payload.U64{
                    .base = .{ .tag = .int_u64 },
                    .data = byte_offset,
                };
                const byte_offset_val = Value.initPayload(&byte_offset_pl.base);

                var u8_ptr_pl = field_ptr_info;
                u8_ptr_pl.data.pointee_type = Type.u8;
                const u8_ptr_ty = Type.initPayload(&u8_ptr_pl.base);

                if (!std.mem.isAligned(byte_offset, field_ptr_ty.ptrAlignment(target))) {
                    return f.fail("TODO: CBE: unaligned packed struct field pointer", .{});
                }

                try writer.writeAll("&((");
                try f.renderTypecast(writer, u8_ptr_ty);
                try writer.writeByte(')');
                try f.writeCValue(writer, struct_ptr, .Other);
                try writer.print(")[{}];\n", .{try f.fmtIntLiteral(Type.usize, byte_offset_val)});
                return local;
            } else @as(FieldLoc, .begin),
        },
        .@"union", .union_safety_tagged, .union_tagged => if (struct_ty.containerLayout() == .Packed) {
            try f.writeCValue(writer, struct_ptr, .Other);
            try writer.writeAll(";\n");
            return local;
        } else if (field_ty.hasRuntimeBitsIgnoreComptime()) FieldLoc{ .field = .{
            .identifier = struct_ty.unionFields().keys()[index],
        } } else @as(FieldLoc, .end),
        .tuple, .anon_struct => field_name: {
            const tuple = struct_ty.tupleFields();
            if (tuple.values[index].tag() != .unreachable_value) return CValue.none;

            var id: usize = 0;
            break :field_name for (tuple.values) |value, i| {
                if (value.tag() != .unreachable_value) continue;
                if (!tuple.types[i].hasRuntimeBitsIgnoreComptime()) continue;
                if (i >= index) break FieldLoc{ .field = .{ .field = id } };
                id += 1;
            } else @as(FieldLoc, .end);
        },
        else => unreachable,
    };

    try writer.writeByte('&');
    switch (field_loc) {
        .begin, .end => {
            try writer.writeByte('(');
            try f.writeCValue(writer, struct_ptr, .Other);
            try writer.print(")[{}]", .{@boolToInt(field_loc == .end)});
        },
        .field => |field| if (extra_name != .none) {
            try f.writeCValueDerefMember(writer, struct_ptr, extra_name);
            try writer.writeByte('.');
            try f.writeCValue(writer, field, .Other);
        } else try f.writeCValueDerefMember(writer, struct_ptr, field),
    }
    try writer.writeAll(";\n");
    return local;
}

fn airStructFieldVal(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_pl = f.air.instructions.items(.data)[inst].ty_pl;
    const extra = f.air.extraData(Air.StructField, ty_pl.payload).data;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{extra.struct_operand});
        return CValue.none;
    }

    const inst_ty = f.air.typeOfIndex(inst);
    if (!inst_ty.hasRuntimeBitsIgnoreComptime()) {
        try reap(f, inst, &.{extra.struct_operand});
        return CValue.none;
    }

    const target = f.object.dg.module.getTarget();
    const struct_byval = try f.resolveInst(extra.struct_operand);
    try reap(f, inst, &.{extra.struct_operand});
    const struct_ty = f.air.typeOf(extra.struct_operand);
    const writer = f.object.writer();

    // Ensure complete type definition is visible before accessing fields.
    try f.renderType(std.io.null_writer, struct_ty);

    const extra_name: CValue = switch (struct_ty.tag()) {
        .union_tagged, .union_safety_tagged => .{ .identifier = "payload" },
        else => .none,
    };

    const field_name: CValue = switch (struct_ty.tag()) {
        .@"struct" => switch (struct_ty.containerLayout()) {
            .Auto, .Extern => .{ .identifier = struct_ty.structFieldName(extra.field_index) },
            .Packed => {
                const struct_obj = struct_ty.castTag(.@"struct").?.data;
                const int_info = struct_ty.intInfo(target);

                var bit_offset_ty_pl = Type.Payload.Bits{
                    .base = .{ .tag = .int_unsigned },
                    .data = Type.smallestUnsignedBits(int_info.bits - 1),
                };
                const bit_offset_ty = Type.initPayload(&bit_offset_ty_pl.base);

                var bit_offset_val_pl: Value.Payload.U64 = .{
                    .base = .{ .tag = .int_u64 },
                    .data = struct_obj.packedFieldBitOffset(target, extra.field_index),
                };
                const bit_offset_val = Value.initPayload(&bit_offset_val_pl.base);

                const field_int_signedness = if (inst_ty.isAbiInt())
                    inst_ty.intInfo(target).signedness
                else
                    .unsigned;
                var field_int_pl = Type.Payload.Bits{
                    .base = .{ .tag = switch (field_int_signedness) {
                        .unsigned => .int_unsigned,
                        .signed => .int_signed,
                    } },
                    .data = @intCast(u16, inst_ty.bitSize(target)),
                };
                const field_int_ty = Type.initPayload(&field_int_pl.base);

                const temp_local = try f.allocLocal(inst, try field_int_ty.copy(f.arena.allocator()));
                try f.writeCValue(writer, temp_local, .Other);
                try writer.writeAll(" = zig_wrap_");
                try f.object.dg.renderTypeForBuiltinFnName(writer, field_int_ty);
                try writer.writeAll("((");
                try f.renderTypecast(writer, field_int_ty);
                try writer.writeAll(")zig_shr_");
                try f.object.dg.renderTypeForBuiltinFnName(writer, struct_ty);
                try writer.writeByte('(');
                try f.writeCValue(writer, struct_byval, .Other);
                try writer.writeAll(", ");
                try f.object.dg.renderValue(writer, bit_offset_ty, bit_offset_val, .FunctionArgument);
                try writer.writeByte(')');
                try f.object.dg.renderBuiltinInfo(writer, field_int_ty, .Bits);
                try writer.writeAll(");\n");
                if (inst_ty.eql(field_int_ty, f.object.dg.module)) return temp_local;

                const local = try f.allocLocal(inst, inst_ty);
                try writer.writeAll("memcpy(");
                try f.writeCValue(writer, .{ .local_ref = local.local }, .FunctionArgument);
                try writer.writeAll(", ");
                try f.writeCValue(writer, .{ .local_ref = temp_local.local }, .FunctionArgument);
                try writer.writeAll(", sizeof(");
                try f.renderTypecast(writer, inst_ty);
                try writer.writeAll("));\n");
                try freeLocal(f, inst, temp_local.local, 0);
                return local;
            },
        },
        .@"union", .union_safety_tagged, .union_tagged => if (struct_ty.containerLayout() == .Packed) {
            const operand_lval = if (struct_byval == .constant) blk: {
                const operand_local = try f.allocLocal(inst, struct_ty);
                try f.writeCValue(writer, operand_local, .Other);
                try writer.writeAll(" = ");
                try f.writeCValue(writer, struct_byval, .Initializer);
                try writer.writeAll(";\n");
                break :blk operand_local;
            } else struct_byval;

            const local = try f.allocLocal(inst, inst_ty);
            try writer.writeAll("memcpy(&");
            try f.writeCValue(writer, local, .FunctionArgument);
            try writer.writeAll(", &");
            try f.writeCValue(writer, operand_lval, .FunctionArgument);
            try writer.writeAll(", sizeof(");
            try f.renderTypecast(writer, inst_ty);
            try writer.writeAll("));\n");

            if (struct_byval == .constant) {
                try freeLocal(f, inst, operand_lval.local, 0);
            }

            return local;
        } else .{
            .identifier = struct_ty.unionFields().keys()[extra.field_index],
        },
        .tuple, .anon_struct => blk: {
            const tuple = struct_ty.tupleFields();
            if (tuple.values[extra.field_index].tag() != .unreachable_value) return CValue.none;

            var id: usize = 0;
            for (tuple.values[0..extra.field_index]) |value|
                id += @boolToInt(value.tag() == .unreachable_value);
            break :blk .{ .field = id };
        },
        else => unreachable,
    };

    const is_array = lowersToArray(inst_ty, target);
    const local = try f.allocLocal(inst, inst_ty);
    if (is_array) {
        try writer.writeAll("memcpy(");
        try f.writeCValue(writer, local, .FunctionArgument);
        try writer.writeAll(", ");
    } else {
        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(" = ");
    }
    if (extra_name != .none) {
        try f.writeCValueMember(writer, struct_byval, extra_name);
        try writer.writeByte('.');
        try f.writeCValue(writer, field_name, .Other);
    } else try f.writeCValueMember(writer, struct_byval, field_name);
    if (is_array) {
        try writer.writeAll(", sizeof(");
        try f.renderTypecast(writer, inst_ty);
        try writer.writeAll("))");
    }
    try writer.writeAll(";\n");
    return local;
}

/// *(E!T) -> E
/// Note that the result is never a pointer.
fn airUnwrapErrUnionErr(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ty_op.operand});
        return CValue.none;
    }

    const inst_ty = f.air.typeOfIndex(inst);
    const operand = try f.resolveInst(ty_op.operand);
    const operand_ty = f.air.typeOf(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});

    const operand_is_ptr = operand_ty.zigTypeTag() == .Pointer;
    const error_union_ty = if (operand_is_ptr) operand_ty.childType() else operand_ty;
    const error_ty = error_union_ty.errorUnionSet();
    const payload_ty = error_union_ty.errorUnionPayload();
    const local = try f.allocLocal(inst, inst_ty);
    const writer = f.object.writer();
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = ");

    if (!payload_ty.hasRuntimeBits()) {
        try f.writeCValue(writer, operand, .Other);
    } else {
        if (!error_ty.errorSetIsEmpty())
            if (operand_is_ptr)
                try f.writeCValueDerefMember(writer, operand, .{ .identifier = "error" })
            else
                try f.writeCValueMember(writer, operand, .{ .identifier = "error" })
        else
            try f.object.dg.renderValue(writer, error_ty, Value.zero, .Initializer);
    }
    try writer.writeAll(";\n");
    return local;
}

fn airUnwrapErrUnionPay(f: *Function, inst: Air.Inst.Index, is_ptr: bool) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ty_op.operand});
        return CValue.none;
    }

    const inst_ty = f.air.typeOfIndex(inst);
    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const operand_ty = f.air.typeOf(ty_op.operand);
    const operand_is_ptr = operand_ty.zigTypeTag() == .Pointer;
    const error_union_ty = if (operand_is_ptr) operand_ty.childType() else operand_ty;

    if (!error_union_ty.errorUnionPayload().hasRuntimeBits()) {
        if (!is_ptr) return CValue.none;

        const w = f.object.writer();
        const local = try f.allocLocal(inst, inst_ty);
        try f.writeCValue(w, local, .Other);
        try w.writeAll(" = (");
        try f.renderTypecast(w, inst_ty);
        try w.writeByte(')');
        try f.writeCValue(w, operand, .Initializer);
        try w.writeAll(";\n");
        return local;
    }

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = ");
    if (is_ptr) try writer.writeByte('&');
    if (operand_is_ptr)
        try f.writeCValueDerefMember(writer, operand, .{ .identifier = "payload" })
    else
        try f.writeCValueMember(writer, operand, .{ .identifier = "payload" });
    try writer.writeAll(";\n");
    return local;
}

fn airWrapOptional(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ty_op.operand});
        return CValue.none;
    }

    const inst_ty = f.air.typeOfIndex(inst);
    const payload = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const writer = f.object.writer();

    if (inst_ty.optionalReprIsPayload()) {
        const local = try f.allocLocal(inst, inst_ty);
        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(" = ");
        try f.writeCValue(writer, payload, .Other);
        try writer.writeAll(";\n");
        return local;
    }

    const payload_ty = f.air.typeOf(ty_op.operand);
    const target = f.object.dg.module.getTarget();
    const is_array = lowersToArray(payload_ty, target);

    const local = try f.allocLocal(inst, inst_ty);
    if (!is_array) {
        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(".payload = ");
        try f.writeCValue(writer, payload, .Other);
        try writer.writeAll("; ");
    }
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(".is_null = false;\n");
    if (is_array) {
        try writer.writeAll("memcpy(");
        try f.writeCValueMember(writer, local, .{ .identifier = "payload" });
        try writer.writeAll(", ");
        try f.writeCValue(writer, payload, .FunctionArgument);
        try writer.writeAll(", sizeof(");
        try f.renderTypecast(writer, payload_ty);
        try writer.writeAll("));\n");
    }
    return local;
}

fn airWrapErrUnionErr(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ty_op.operand});
        return CValue.none;
    }

    const writer = f.object.writer();
    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const error_union_ty = f.air.typeOfIndex(inst);
    const payload_ty = error_union_ty.errorUnionPayload();
    const local = try f.allocLocal(inst, error_union_ty);

    if (!payload_ty.hasRuntimeBits()) {
        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(" = ");
        try f.writeCValue(writer, operand, .Other);
        try writer.writeAll(";\n");
        return local;
    }

    {
        // TODO: set the payload to undefined
        //try f.writeCValue(writer, local, .Other);
    }
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(".error = ");
    try f.writeCValue(writer, operand, .Other);
    try writer.writeAll(";\n");
    return local;
}

fn airErrUnionPayloadPtrSet(f: *Function, inst: Air.Inst.Index) !CValue {
    const writer = f.object.writer();
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    const operand = try f.resolveInst(ty_op.operand);
    const error_union_ty = f.air.typeOf(ty_op.operand).childType();

    const error_ty = error_union_ty.errorUnionSet();
    const payload_ty = error_union_ty.errorUnionPayload();

    // First, set the non-error value.
    if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
        try f.writeCValueDeref(writer, operand);
        try writer.writeAll(" = ");
        try f.object.dg.renderValue(writer, error_ty, Value.zero, .Other);
        try writer.writeAll(";\n ");

        return operand;
    }
    try reap(f, inst, &.{ty_op.operand});
    try f.writeCValueDeref(writer, operand);
    try writer.writeAll(".error = ");
    try f.object.dg.renderValue(writer, error_ty, Value.zero, .Other);
    try writer.writeAll(";\n");

    // Then return the payload pointer (only if it is used)
    if (f.liveness.isUnused(inst)) return CValue.none;

    const local = try f.allocLocal(inst, f.air.typeOfIndex(inst));
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = &(");
    try f.writeCValueDeref(writer, operand);
    try writer.writeAll(").payload;\n");
    return local;
}

fn airErrReturnTrace(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst)) return CValue.none;
    return f.fail("TODO: C backend: implement airErrReturnTrace", .{});
}

fn airSetErrReturnTrace(f: *Function, inst: Air.Inst.Index) !CValue {
    _ = inst;
    return f.fail("TODO: C backend: implement airSetErrReturnTrace", .{});
}

fn airSaveErrReturnTraceIndex(f: *Function, inst: Air.Inst.Index) !CValue {
    _ = inst;
    return f.fail("TODO: C backend: implement airSaveErrReturnTraceIndex", .{});
}

fn airWrapErrUnionPay(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ty_op.operand});
        return CValue.none;
    }

    const inst_ty = f.air.typeOfIndex(inst);
    const payload_ty = inst_ty.errorUnionPayload();
    const payload = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});

    const target = f.object.dg.module.getTarget();
    const is_array = lowersToArray(payload_ty, target);

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    if (!is_array) {
        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(".payload = ");
        try f.writeCValue(writer, payload, .Other);
        try writer.writeAll("; ");
    }
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(".error = 0;\n");
    if (is_array) {
        try writer.writeAll("memcpy(");
        try f.writeCValueMember(writer, local, .{ .identifier = "payload" });
        try writer.writeAll(", ");
        try f.writeCValue(writer, payload, .FunctionArgument);
        try writer.writeAll(", sizeof(");
        try f.renderTypecast(writer, payload_ty);
        try writer.writeAll("));\n");
    }
    return local;
}

fn airIsErr(f: *Function, inst: Air.Inst.Index, is_ptr: bool, operator: []const u8) !CValue {
    const un_op = f.air.instructions.items(.data)[inst].un_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{un_op});
        return CValue.none;
    }

    const writer = f.object.writer();
    const operand = try f.resolveInst(un_op);
    try reap(f, inst, &.{un_op});
    const operand_ty = f.air.typeOf(un_op);
    const local = try f.allocLocal(inst, Type.bool);
    const err_union_ty = if (is_ptr) operand_ty.childType() else operand_ty;
    const payload_ty = err_union_ty.errorUnionPayload();
    const error_ty = err_union_ty.errorUnionSet();

    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = ");

    if (!error_ty.errorSetIsEmpty())
        if (payload_ty.hasRuntimeBits())
            if (is_ptr)
                try f.writeCValueDerefMember(writer, operand, .{ .identifier = "error" })
            else
                try f.writeCValueMember(writer, operand, .{ .identifier = "error" })
        else
            try f.writeCValue(writer, operand, .Other)
    else
        try f.object.dg.renderValue(writer, error_ty, Value.zero, .Other);
    try writer.writeByte(' ');
    try writer.writeAll(operator);
    try writer.writeByte(' ');
    try f.object.dg.renderValue(writer, error_ty, Value.zero, .Other);
    try writer.writeAll(";\n");
    return local;
}

fn airArrayToSlice(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ty_op.operand});
        return CValue.none;
    }

    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const inst_ty = f.air.typeOfIndex(inst);
    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);
    const array_len = f.air.typeOf(ty_op.operand).elemType().arrayLen();

    try writer.writeAll(".ptr = ");
    if (operand == .undef) {
        // Unfortunately, C does not support any equivalent to
        // &(*(void *)p)[0], although LLVM does via GetElementPtr
        var buf: Type.SlicePtrFieldTypeBuffer = undefined;
        try f.writeCValue(writer, CValue{ .undef = inst_ty.slicePtrFieldType(&buf) }, .Initializer);
    } else {
        try writer.writeAll("&(");
        try f.writeCValueDeref(writer, operand);
        try writer.print(")[{}]", .{try f.fmtIntLiteral(Type.usize, Value.zero)});
    }

    var len_pl: Value.Payload.U64 = .{ .base = .{ .tag = .int_u64 }, .data = array_len };
    const len_val = Value.initPayload(&len_pl.base);
    try writer.writeAll("; ");
    try f.writeCValue(writer, local, .Other);
    try writer.print(".len = {};\n", .{try f.fmtIntLiteral(Type.usize, len_val)});
    return local;
}

fn airFloatCast(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ty_op.operand});
        return CValue.none;
    }

    const inst_ty = f.air.typeOfIndex(inst);
    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const operand_ty = f.air.typeOf(ty_op.operand);
    const target = f.object.dg.module.getTarget();
    const operation = if (inst_ty.isRuntimeFloat() and operand_ty.isRuntimeFloat())
        if (inst_ty.floatBits(target) < operand_ty.floatBits(target)) "trunc" else "extend"
    else if (inst_ty.isInt() and operand_ty.isRuntimeFloat())
        if (inst_ty.isSignedInt()) "fix" else "fixuns"
    else if (inst_ty.isRuntimeFloat() and operand_ty.isInt())
        if (operand_ty.isSignedInt()) "float" else "floatun"
    else
        unreachable;

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);

    try writer.writeAll(" = ");
    if (inst_ty.isInt() and operand_ty.isRuntimeFloat()) {
        try writer.writeAll("zig_wrap_");
        try f.object.dg.renderTypeForBuiltinFnName(writer, inst_ty);
        try writer.writeByte('(');
    }
    try writer.writeAll("__");
    try writer.writeAll(operation);
    try writer.writeAll(compilerRtAbbrev(operand_ty, target));
    try writer.writeAll(compilerRtAbbrev(inst_ty, target));
    if (inst_ty.isRuntimeFloat() and operand_ty.isRuntimeFloat()) try writer.writeByte('2');
    try writer.writeByte('(');
    try f.writeCValue(writer, operand, .FunctionArgument);
    try writer.writeByte(')');
    if (inst_ty.isInt() and operand_ty.isRuntimeFloat()) {
        try f.object.dg.renderBuiltinInfo(writer, inst_ty, .Bits);
        try writer.writeByte(')');
    }
    try writer.writeAll(";\n");
    return local;
}

fn airPtrToInt(f: *Function, inst: Air.Inst.Index) !CValue {
    const un_op = f.air.instructions.items(.data)[inst].un_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{un_op});
        return CValue.none;
    }

    const operand = try f.resolveInst(un_op);
    try reap(f, inst, &.{un_op});
    const inst_ty = f.air.typeOfIndex(inst);
    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);

    try writer.writeAll(" = (");
    try f.renderTypecast(writer, inst_ty);
    try writer.writeByte(')');
    try f.writeCValue(writer, operand, .Other);
    try writer.writeAll(";\n");
    return local;
}

fn airUnBuiltinCall(
    f: *Function,
    inst: Air.Inst.Index,
    operation: []const u8,
    info: BuiltinInfo,
) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ty_op.operand});
        return CValue.none;
    }

    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const inst_ty = f.air.typeOfIndex(inst);
    const operand_ty = f.air.typeOf(ty_op.operand);

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = zig_");
    try writer.writeAll(operation);
    try writer.writeByte('_');
    try f.object.dg.renderTypeForBuiltinFnName(writer, operand_ty);
    try writer.writeByte('(');
    try f.writeCValue(writer, operand, .FunctionArgument);
    try f.object.dg.renderBuiltinInfo(writer, operand_ty, info);
    try writer.writeAll(");\n");
    return local;
}

fn airBinBuiltinCall(
    f: *Function,
    inst: Air.Inst.Index,
    operation: []const u8,
    info: BuiltinInfo,
) !CValue {
    const bin_op = f.air.instructions.items(.data)[inst].bin_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
        return CValue.none;
    }

    const lhs = try f.resolveInst(bin_op.lhs);
    const rhs = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const inst_ty = f.air.typeOfIndex(inst);
    const operand_ty = f.air.typeOf(bin_op.lhs);

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = zig_");
    try writer.writeAll(operation);
    try writer.writeByte('_');
    try f.object.dg.renderTypeForBuiltinFnName(writer, operand_ty);
    try writer.writeByte('(');
    try f.writeCValue(writer, lhs, .FunctionArgument);
    try writer.writeAll(", ");
    try f.writeCValue(writer, rhs, .FunctionArgument);
    try f.object.dg.renderBuiltinInfo(writer, operand_ty, info);
    try writer.writeAll(");\n");
    return local;
}

fn cmpBuiltinCall(
    f: *Function,
    inst: Air.Inst.Index,
    operator: []const u8,
    operation: []const u8,
) !CValue {
    const inst_ty = f.air.typeOfIndex(inst);
    const bin_op = f.air.instructions.items(.data)[inst].bin_op;
    const operand_ty = f.air.typeOf(bin_op.lhs);

    const lhs = try f.resolveInst(bin_op.lhs);
    const rhs = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = zig_");
    try writer.writeAll(operation);
    try writer.writeByte('_');
    try f.object.dg.renderTypeForBuiltinFnName(writer, operand_ty);
    try writer.writeByte('(');
    try f.writeCValue(writer, lhs, .FunctionArgument);
    try writer.writeAll(", ");
    try f.writeCValue(writer, rhs, .FunctionArgument);
    try writer.print(") {s} {};\n", .{ operator, try f.fmtIntLiteral(Type.initTag(.i32), Value.zero) });
    return local;
}

fn airCmpxchg(f: *Function, inst: Air.Inst.Index, flavor: [*:0]const u8) !CValue {
    const ty_pl = f.air.instructions.items(.data)[inst].ty_pl;
    const extra = f.air.extraData(Air.Cmpxchg, ty_pl.payload).data;
    const inst_ty = f.air.typeOfIndex(inst);
    const ptr = try f.resolveInst(extra.ptr);
    const expected_value = try f.resolveInst(extra.expected_value);
    const new_value = try f.resolveInst(extra.new_value);
    try reap(f, inst, &.{ extra.ptr, extra.expected_value, extra.new_value });
    const writer = f.object.writer();
    const ptr_ty = f.air.typeOf(extra.ptr);
    const local = try f.allocLocal(inst, inst_ty);
    if (inst_ty.isPtrLikeOptional()) {
        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(" = ");
        try f.writeCValue(writer, expected_value, .Initializer);
        try writer.writeAll(";\n");
        try writer.writeAll("if (");
        try writer.print("zig_cmpxchg_{s}((zig_atomic(", .{flavor});
        try f.renderTypecast(writer, ptr_ty.elemType());
        try writer.writeByte(')');
        if (ptr_ty.isVolatilePtr()) try writer.writeAll(" volatile");
        try writer.writeAll(" *)");
        try f.writeCValue(writer, ptr, .Other);
        try writer.writeAll(", ");
        try f.writeCValue(writer, local, .FunctionArgument);
        try writer.writeAll(", ");
        try f.writeCValue(writer, new_value, .FunctionArgument);
        try writer.writeAll(", ");
        try writeMemoryOrder(writer, extra.successOrder());
        try writer.writeAll(", ");
        try writeMemoryOrder(writer, extra.failureOrder());
        try writer.writeByte(')');
        try writer.writeAll(") {\n");
        f.object.indent_writer.pushIndent();
        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(" = NULL;\n");
        f.object.indent_writer.popIndent();
        try writer.writeAll("}\n");
    } else {
        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(".payload = ");
        try f.writeCValue(writer, expected_value, .Other);
        try writer.writeAll(";\n");
        try f.writeCValue(writer, local, .Other);
        try writer.print(".is_null = zig_cmpxchg_{s}((zig_atomic(", .{flavor});
        try f.renderTypecast(writer, ptr_ty.elemType());
        try writer.writeByte(')');
        if (ptr_ty.isVolatilePtr()) try writer.writeAll(" volatile");
        try writer.writeAll(" *)");
        try f.writeCValue(writer, ptr, .Other);
        try writer.writeAll(", ");
        try f.writeCValueMember(writer, local, .{ .identifier = "payload" });
        try writer.writeAll(", ");
        try f.writeCValue(writer, new_value, .FunctionArgument);
        try writer.writeAll(", ");
        try writeMemoryOrder(writer, extra.successOrder());
        try writer.writeAll(", ");
        try writeMemoryOrder(writer, extra.failureOrder());
        try writer.writeByte(')');
        try writer.writeAll(";\n");
    }

    if (f.liveness.isUnused(inst)) {
        try freeLocal(f, inst, local.local, 0);
        return CValue.none;
    }

    return local;
}

fn airAtomicRmw(f: *Function, inst: Air.Inst.Index) !CValue {
    const pl_op = f.air.instructions.items(.data)[inst].pl_op;
    const extra = f.air.extraData(Air.AtomicRmw, pl_op.payload).data;
    const inst_ty = f.air.typeOfIndex(inst);
    const ptr_ty = f.air.typeOf(pl_op.operand);
    const ptr = try f.resolveInst(pl_op.operand);
    const operand = try f.resolveInst(extra.operand);
    try reap(f, inst, &.{ pl_op.operand, extra.operand });
    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);

    try writer.print(" = zig_atomicrmw_{s}((", .{toAtomicRmwSuffix(extra.op())});
    switch (extra.op()) {
        else => {
            try writer.writeAll("zig_atomic(");
            try f.renderTypecast(writer, ptr_ty.elemType());
            try writer.writeByte(')');
        },
        .Nand, .Min, .Max => {
            // These are missing from stdatomic.h, so no atomic types for now.
            try f.renderTypecast(writer, ptr_ty.elemType());
        },
    }
    if (ptr_ty.isVolatilePtr()) try writer.writeAll(" volatile");
    try writer.writeAll(" *)");
    try f.writeCValue(writer, ptr, .Other);
    try writer.writeAll(", ");
    try f.writeCValue(writer, operand, .FunctionArgument);
    try writer.writeAll(", ");
    try writeMemoryOrder(writer, extra.ordering());
    try writer.writeAll(");\n");

    if (f.liveness.isUnused(inst)) {
        try freeLocal(f, inst, local.local, 0);
        return CValue.none;
    }

    return local;
}

fn airAtomicLoad(f: *Function, inst: Air.Inst.Index) !CValue {
    const atomic_load = f.air.instructions.items(.data)[inst].atomic_load;
    const ptr = try f.resolveInst(atomic_load.ptr);
    try reap(f, inst, &.{atomic_load.ptr});
    const ptr_ty = f.air.typeOf(atomic_load.ptr);
    if (!ptr_ty.isVolatilePtr() and f.liveness.isUnused(inst)) {
        return CValue.none;
    }

    const inst_ty = f.air.typeOfIndex(inst);
    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);

    try writer.writeAll(" = zig_atomic_load((zig_atomic(");
    try f.renderTypecast(writer, ptr_ty.elemType());
    try writer.writeByte(')');
    if (ptr_ty.isVolatilePtr()) try writer.writeAll(" volatile");
    try writer.writeAll(" *)");
    try f.writeCValue(writer, ptr, .Other);
    try writer.writeAll(", ");
    try writeMemoryOrder(writer, atomic_load.order);
    try writer.writeAll(");\n");

    return local;
}

fn airAtomicStore(f: *Function, inst: Air.Inst.Index, order: [*:0]const u8) !CValue {
    const bin_op = f.air.instructions.items(.data)[inst].bin_op;
    const ptr_ty = f.air.typeOf(bin_op.lhs);
    const ptr = try f.resolveInst(bin_op.lhs);
    const element = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
    const writer = f.object.writer();

    try writer.writeAll("zig_atomic_store((zig_atomic(");
    try f.renderTypecast(writer, ptr_ty.elemType());
    try writer.writeByte(')');
    if (ptr_ty.isVolatilePtr()) try writer.writeAll(" volatile");
    try writer.writeAll(" *)");
    try f.writeCValue(writer, ptr, .Other);
    try writer.writeAll(", ");
    try f.writeCValue(writer, element, .FunctionArgument);
    try writer.print(", {s});\n", .{order});

    return CValue.none;
}

fn airMemset(f: *Function, inst: Air.Inst.Index) !CValue {
    const pl_op = f.air.instructions.items(.data)[inst].pl_op;
    const extra = f.air.extraData(Air.Bin, pl_op.payload).data;
    const dest_ty = f.air.typeOf(pl_op.operand);
    const dest_ptr = try f.resolveInst(pl_op.operand);
    const value = try f.resolveInst(extra.lhs);
    const len = try f.resolveInst(extra.rhs);

    const writer = f.object.writer();
    if (dest_ty.isVolatilePtr()) {
        var u8_ptr_pl = dest_ty.ptrInfo();
        u8_ptr_pl.data.pointee_type = Type.u8;
        const u8_ptr_ty = Type.initPayload(&u8_ptr_pl.base);
        const index = try f.allocLocal(inst, Type.usize);

        try writer.writeAll("for (");
        try f.writeCValue(writer, index, .Other);
        try writer.writeAll(" = ");
        try f.object.dg.renderValue(writer, Type.usize, Value.zero, .Initializer);
        try writer.writeAll("; ");
        try f.writeCValue(writer, index, .Other);
        try writer.writeAll(" != ");
        try f.writeCValue(writer, len, .Other);
        try writer.writeAll("; ");
        try f.writeCValue(writer, index, .Other);
        try writer.writeAll(" += ");
        try f.object.dg.renderValue(writer, Type.usize, Value.one, .Other);
        try writer.writeAll(") ((");
        try f.renderTypecast(writer, u8_ptr_ty);
        try writer.writeByte(')');
        try f.writeCValue(writer, dest_ptr, .FunctionArgument);
        try writer.writeAll(")[");
        try f.writeCValue(writer, index, .Other);
        try writer.writeAll("] = ");
        try f.writeCValue(writer, value, .FunctionArgument);
        try writer.writeAll(";\n");

        try reap(f, inst, &.{ pl_op.operand, extra.lhs, extra.rhs });
        try freeLocal(f, inst, index.local, 0);

        return CValue.none;
    }

    try reap(f, inst, &.{ pl_op.operand, extra.lhs, extra.rhs });
    try writer.writeAll("memset(");
    try f.writeCValue(writer, dest_ptr, .FunctionArgument);
    try writer.writeAll(", ");
    try f.writeCValue(writer, value, .FunctionArgument);
    try writer.writeAll(", ");
    try f.writeCValue(writer, len, .FunctionArgument);
    try writer.writeAll(");\n");

    return CValue.none;
}

fn airMemcpy(f: *Function, inst: Air.Inst.Index) !CValue {
    const pl_op = f.air.instructions.items(.data)[inst].pl_op;
    const extra = f.air.extraData(Air.Bin, pl_op.payload).data;
    const dest_ptr = try f.resolveInst(pl_op.operand);
    const src_ptr = try f.resolveInst(extra.lhs);
    const len = try f.resolveInst(extra.rhs);
    try reap(f, inst, &.{ pl_op.operand, extra.lhs, extra.rhs });
    const writer = f.object.writer();

    try writer.writeAll("memcpy(");
    try f.writeCValue(writer, dest_ptr, .FunctionArgument);
    try writer.writeAll(", ");
    try f.writeCValue(writer, src_ptr, .FunctionArgument);
    try writer.writeAll(", ");
    try f.writeCValue(writer, len, .FunctionArgument);
    try writer.writeAll(");\n");

    return CValue.none;
}

fn airSetUnionTag(f: *Function, inst: Air.Inst.Index) !CValue {
    const bin_op = f.air.instructions.items(.data)[inst].bin_op;
    const union_ptr = try f.resolveInst(bin_op.lhs);
    const new_tag = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
    const writer = f.object.writer();

    const union_ty = f.air.typeOf(bin_op.lhs).childType();
    const target = f.object.dg.module.getTarget();
    const layout = union_ty.unionGetLayout(target);
    if (layout.tag_size == 0) return CValue.none;

    try writer.writeByte('(');
    try f.writeCValue(writer, union_ptr, .Other);
    try writer.writeAll(")->tag = ");
    try f.writeCValue(writer, new_tag, .Other);
    try writer.writeAll(";\n");

    return CValue.none;
}

fn airGetUnionTag(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ty_op.operand});
        return CValue.none;
    }

    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});

    const un_ty = f.air.typeOf(ty_op.operand);

    const target = f.object.dg.module.getTarget();
    const layout = un_ty.unionGetLayout(target);
    if (layout.tag_size == 0) return CValue.none;

    const inst_ty = f.air.typeOfIndex(inst);
    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);

    try writer.writeAll(" = ");
    try f.writeCValue(writer, operand, .Other);
    try writer.writeAll(".tag;\n");
    return local;
}

fn airTagName(f: *Function, inst: Air.Inst.Index) !CValue {
    const un_op = f.air.instructions.items(.data)[inst].un_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{un_op});
        return CValue.none;
    }

    const inst_ty = f.air.typeOfIndex(inst);
    const enum_ty = f.air.typeOf(un_op);
    const operand = try f.resolveInst(un_op);
    try reap(f, inst, &.{un_op});

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.print(" = {s}(", .{try f.object.dg.getTagNameFn(enum_ty)});
    try f.writeCValue(writer, operand, .Other);
    try writer.writeAll(");\n");

    return local;
}

fn airErrorName(f: *Function, inst: Air.Inst.Index) !CValue {
    const un_op = f.air.instructions.items(.data)[inst].un_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{un_op});
        return CValue.none;
    }

    const writer = f.object.writer();
    const inst_ty = f.air.typeOfIndex(inst);
    const operand = try f.resolveInst(un_op);
    try reap(f, inst, &.{un_op});
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);

    try writer.writeAll(" = zig_errorName[");
    try f.writeCValue(writer, operand, .Other);
    try writer.writeAll("];\n");
    return local;
}

fn airSplat(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ty_op.operand});
        return CValue.none;
    }

    const inst_ty = f.air.typeOfIndex(inst);
    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = ");

    _ = operand;
    return f.fail("TODO: C backend: implement airSplat", .{});
}

fn airSelect(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst)) return CValue.none;

    return f.fail("TODO: C backend: implement airSelect", .{});
}

fn airShuffle(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst)) return CValue.none;

    return f.fail("TODO: C backend: implement airShuffle", .{});
}

fn airReduce(f: *Function, inst: Air.Inst.Index) !CValue {
    const reduce = f.air.instructions.items(.data)[inst].reduce;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{reduce.operand});
        return CValue.none;
    }

    const target = f.object.dg.module.getTarget();
    const scalar_ty = f.air.typeOfIndex(inst);
    const operand = try f.resolveInst(reduce.operand);
    try reap(f, inst, &.{reduce.operand});
    const operand_ty = f.air.typeOf(reduce.operand);
    const vector_len = operand_ty.vectorLen();
    const writer = f.object.writer();

    const Op = union(enum) {
        call_fn: []const u8,
        infix: []const u8,
        ternary: []const u8,
    };
    var fn_name_buf: [64]u8 = undefined;
    const op: Op = switch (reduce.operation) {
        .And => .{ .infix = " &= " },
        .Or => .{ .infix = " |= " },
        .Xor => .{ .infix = " ^= " },
        .Min => switch (scalar_ty.zigTypeTag()) {
            .Int => Op{ .ternary = " < " },
            .Float => op: {
                const float_bits = scalar_ty.floatBits(target);
                break :op Op{
                    .call_fn = std.fmt.bufPrintZ(&fn_name_buf, "{s}fmin{s}", .{
                        libcFloatPrefix(float_bits), libcFloatSuffix(float_bits),
                    }) catch unreachable,
                };
            },
            else => unreachable,
        },
        .Max => switch (scalar_ty.zigTypeTag()) {
            .Int => Op{ .ternary = " > " },
            .Float => op: {
                const float_bits = scalar_ty.floatBits(target);
                break :op Op{
                    .call_fn = std.fmt.bufPrintZ(&fn_name_buf, "{s}fmax{s}", .{
                        libcFloatPrefix(float_bits), libcFloatSuffix(float_bits),
                    }) catch unreachable,
                };
            },
            else => unreachable,
        },
        .Add => switch (scalar_ty.zigTypeTag()) {
            .Int => Op{ .infix = " += " },
            .Float => op: {
                const float_bits = scalar_ty.floatBits(target);
                break :op Op{
                    .call_fn = std.fmt.bufPrintZ(&fn_name_buf, "__add{s}f3", .{
                        compilerRtFloatAbbrev(float_bits),
                    }) catch unreachable,
                };
            },
            else => unreachable,
        },
        .Mul => switch (scalar_ty.zigTypeTag()) {
            .Int => Op{ .infix = " *= " },
            .Float => op: {
                const float_bits = scalar_ty.floatBits(target);
                break :op Op{
                    .call_fn = std.fmt.bufPrintZ(&fn_name_buf, "__mul{s}f3", .{
                        compilerRtFloatAbbrev(float_bits),
                    }) catch unreachable,
                };
            },
            else => unreachable,
        },
    };

    // Reduce a vector by repeatedly applying a function to produce an
    // accumulated result.
    //
    // Equivalent to:
    //   reduce: {
    //     var i: usize = 0;
    //     var accum: T = init;
    //     while (i < vec.len) : (i += 1) {
    //       accum = func(accum, vec[i]);
    //     }
    //     break :reduce accum;
    //   }
    const it = try f.allocLocal(inst, Type.usize);
    try f.writeCValue(writer, it, .Other);
    try writer.writeAll(" = 0;\n");

    const accum = try f.allocLocal(inst, scalar_ty);
    try f.writeCValue(writer, accum, .Other);
    try writer.writeAll(" = ");

    const init_val = switch (reduce.operation) {
        .And, .Or, .Xor, .Add => "0",
        .Min => switch (scalar_ty.zigTypeTag()) {
            .Int => "TODO_intmax",
            .Float => "TODO_nan",
            else => unreachable,
        },
        .Max => switch (scalar_ty.zigTypeTag()) {
            .Int => "TODO_intmin",
            .Float => "TODO_nan",
            else => unreachable,
        },
        .Mul => "1",
    };
    try writer.writeAll(init_val);
    try writer.writeAll(";");
    try f.object.indent_writer.insertNewline();
    try writer.writeAll("for (;");
    try f.writeCValue(writer, it, .Other);
    try writer.print("<{d};++", .{vector_len});
    try f.writeCValue(writer, it, .Other);
    try writer.writeAll(") ");
    try f.writeCValue(writer, accum, .Other);

    switch (op) {
        .call_fn => |fn_name| {
            try writer.print(" = {s}(", .{fn_name});
            try f.writeCValue(writer, accum, .FunctionArgument);
            try writer.writeAll(", ");
            try f.writeCValue(writer, operand, .Other);
            try writer.writeAll("[");
            try f.writeCValue(writer, it, .Other);
            try writer.writeAll("])");
        },
        .infix => |ass| {
            try writer.writeAll(ass);
            try f.writeCValue(writer, operand, .Other);
            try writer.writeAll("[");
            try f.writeCValue(writer, it, .Other);
            try writer.writeAll("]");
        },
        .ternary => |cmp| {
            try writer.writeAll(" = ");
            try f.writeCValue(writer, accum, .Other);
            try writer.writeAll(cmp);
            try f.writeCValue(writer, operand, .Other);
            try writer.writeAll("[");
            try f.writeCValue(writer, it, .Other);
            try writer.writeAll("] ? ");
            try f.writeCValue(writer, accum, .Other);
            try writer.writeAll(" : ");
            try f.writeCValue(writer, operand, .Other);
            try writer.writeAll("[");
            try f.writeCValue(writer, it, .Other);
            try writer.writeAll("]");
        },
    }

    try writer.writeAll(";\n");

    try freeLocal(f, inst, it.local, 0);

    return accum;
}

fn airAggregateInit(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_pl = f.air.instructions.items(.data)[inst].ty_pl;
    const inst_ty = f.air.typeOfIndex(inst);
    const len = @intCast(usize, inst_ty.arrayLen());
    const elements = @ptrCast([]const Air.Inst.Ref, f.air.extra[ty_pl.payload..][0..len]);
    const gpa = f.object.dg.gpa;
    const resolved_elements = try gpa.alloc(CValue, elements.len);
    defer gpa.free(resolved_elements);
    for (elements) |element, i| {
        resolved_elements[i] = try f.resolveInst(element);
    }
    {
        var bt = iterateBigTomb(f, inst);
        for (elements) |element| {
            try bt.feed(element);
        }
    }

    if (f.liveness.isUnused(inst)) return CValue.none;

    const target = f.object.dg.module.getTarget();

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    switch (inst_ty.zigTypeTag()) {
        .Array, .Vector => {
            const elem_ty = inst_ty.childType();
            for (resolved_elements) |element, i| {
                try f.writeCValue(writer, local, .Other);
                try writer.print("[{d}] = ", .{i});
                try f.writeCValue(writer, element, .Other);
                try writer.writeAll(";\n");
            }
            if (inst_ty.sentinel()) |sentinel| {
                try f.writeCValue(writer, local, .Other);
                try writer.print("[{d}] = ", .{resolved_elements.len});
                try f.object.dg.renderValue(writer, elem_ty, sentinel, .Other);
                try writer.writeAll(";\n");
            }
        },
        .Struct => switch (inst_ty.containerLayout()) {
            .Auto, .Extern => {
                try f.writeCValue(writer, local, .Other);
                try writer.writeAll(" = (");
                try f.renderTypecast(writer, inst_ty);
                try writer.writeAll(")");
                try writer.writeByte('{');
                var empty = true;
                for (elements) |element, index| {
                    if (inst_ty.structFieldValueComptime(index)) |_| continue;

                    if (!empty) try writer.writeAll(", ");
                    if (!inst_ty.isTupleOrAnonStruct()) {
                        try writer.print(".{ } = ", .{fmtIdent(inst_ty.structFieldName(index))});
                    }

                    const element_ty = f.air.typeOf(element);
                    try f.writeCValue(writer, switch (element_ty.zigTypeTag()) {
                        .Array => CValue{ .undef = element_ty },
                        else => resolved_elements[index],
                    }, .Initializer);
                    empty = false;
                }
                if (empty) try writer.print("{}", .{try f.fmtIntLiteral(Type.u8, Value.zero)});
                try writer.writeAll("};\n");

                var field_id: usize = 0;
                for (elements) |element, index| {
                    if (inst_ty.structFieldValueComptime(index)) |_| continue;

                    const element_ty = f.air.typeOf(element);
                    if (element_ty.zigTypeTag() != .Array) continue;

                    const field_name = if (inst_ty.isTupleOrAnonStruct())
                        CValue{ .field = field_id }
                    else
                        CValue{ .identifier = inst_ty.structFieldName(index) };

                    try writer.writeAll(";\n");
                    try writer.writeAll("memcpy(");
                    try f.writeCValueMember(writer, local, field_name);
                    try writer.writeAll(", ");
                    try f.writeCValue(writer, resolved_elements[index], .FunctionArgument);
                    try writer.writeAll(", sizeof(");
                    try f.renderTypecast(writer, element_ty);
                    try writer.writeAll("));\n");

                    field_id += 1;
                }
            },
            .Packed => {
                try f.writeCValue(writer, local, .Other);
                try writer.writeAll(" = (");
                try f.renderTypecast(writer, inst_ty);
                try writer.writeAll(")");
                const int_info = inst_ty.intInfo(target);

                var bit_offset_ty_pl = Type.Payload.Bits{
                    .base = .{ .tag = .int_unsigned },
                    .data = Type.smallestUnsignedBits(int_info.bits - 1),
                };
                const bit_offset_ty = Type.initPayload(&bit_offset_ty_pl.base);

                var bit_offset_val_pl: Value.Payload.U64 = .{ .base = .{ .tag = .int_u64 }, .data = 0 };
                const bit_offset_val = Value.initPayload(&bit_offset_val_pl.base);

                var empty = true;
                for (elements) |_, index| {
                    const field_ty = inst_ty.structFieldType(index);
                    if (!field_ty.hasRuntimeBitsIgnoreComptime()) continue;

                    if (!empty) {
                        try writer.writeAll("zig_or_");
                        try f.object.dg.renderTypeForBuiltinFnName(writer, inst_ty);
                        try writer.writeByte('(');
                    }
                    empty = false;
                }
                empty = true;
                for (resolved_elements) |element, index| {
                    const field_ty = inst_ty.structFieldType(index);
                    if (!field_ty.hasRuntimeBitsIgnoreComptime()) continue;

                    if (!empty) try writer.writeAll(", ");
                    try writer.writeAll("zig_shlw_");
                    try f.object.dg.renderTypeForBuiltinFnName(writer, inst_ty);
                    try writer.writeAll("((");
                    try f.renderTypecast(writer, inst_ty);
                    try writer.writeByte(')');
                    if (field_ty.isPtrAtRuntime()) {
                        try writer.writeByte('(');
                        try f.renderTypecast(writer, switch (int_info.signedness) {
                            .unsigned => Type.usize,
                            .signed => Type.isize,
                        });
                        try writer.writeByte(')');
                    }
                    try f.writeCValue(writer, element, .Other);
                    try writer.writeAll(", ");
                    try f.object.dg.renderValue(writer, bit_offset_ty, bit_offset_val, .FunctionArgument);
                    try f.object.dg.renderBuiltinInfo(writer, inst_ty, .Bits);
                    try writer.writeByte(')');
                    if (!empty) try writer.writeByte(')');

                    bit_offset_val_pl.data += field_ty.bitSize(target);
                    empty = false;
                }
                if (empty) try f.writeCValue(writer, .{ .undef = inst_ty }, .Initializer);
                try writer.writeAll(";\n");
            },
        },
        else => unreachable,
    }

    return local;
}

fn airUnionInit(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_pl = f.air.instructions.items(.data)[inst].ty_pl;
    const extra = f.air.extraData(Air.UnionInit, ty_pl.payload).data;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{extra.init});
        return CValue.none;
    }

    const union_ty = f.air.typeOfIndex(inst);
    const target = f.object.dg.module.getTarget();
    const union_obj = union_ty.cast(Type.Payload.Union).?.data;
    const field_name = union_obj.fields.keys()[extra.field_index];
    const payload = try f.resolveInst(extra.init);
    try reap(f, inst, &.{extra.init});

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, union_ty);
    if (union_obj.layout == .Packed) {
        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(" = ");
        try f.writeCValue(writer, payload, .Initializer);
        try writer.writeAll(";\n");
        return local;
    }

    if (union_ty.unionTagTypeSafety()) |tag_ty| {
        const layout = union_ty.unionGetLayout(target);
        if (layout.tag_size != 0) {
            const field_index = tag_ty.enumFieldIndex(field_name).?;

            var tag_pl: Value.Payload.U32 = .{
                .base = .{ .tag = .enum_field_index },
                .data = @intCast(u32, field_index),
            };
            const tag_val = Value.initPayload(&tag_pl.base);

            var int_pl: Value.Payload.U64 = undefined;
            const int_val = tag_val.enumToInt(tag_ty, &int_pl);

            try f.writeCValue(writer, local, .Other);
            try writer.print(".tag = {}; ", .{try f.fmtIntLiteral(tag_ty, int_val)});
        }
        try f.writeCValue(writer, local, .Other);
        try writer.print(".payload.{ } = ", .{fmtIdent(field_name)});
        try f.writeCValue(writer, payload, .Other);
        try writer.writeAll(";\n");
        return local;
    }

    try f.writeCValue(writer, local, .Other);
    try writer.print(".{ } = ", .{fmtIdent(field_name)});
    try f.writeCValue(writer, payload, .Other);
    try writer.writeAll(";\n");

    return local;
}

fn airPrefetch(f: *Function, inst: Air.Inst.Index) !CValue {
    const prefetch = f.air.instructions.items(.data)[inst].prefetch;
    switch (prefetch.cache) {
        .data => {},
        // The available prefetch intrinsics do not accept a cache argument; only
        // address, rw, and locality. So unless the cache is data, we do not lower
        // this instruction.
        .instruction => return CValue.none,
    }
    const ptr = try f.resolveInst(prefetch.ptr);
    try reap(f, inst, &.{prefetch.ptr});
    const writer = f.object.writer();
    try writer.writeAll("zig_prefetch(");
    try f.writeCValue(writer, ptr, .FunctionArgument);
    try writer.print(", {d}, {d});\n", .{
        @enumToInt(prefetch.rw), prefetch.locality,
    });
    return CValue.none;
}

fn airWasmMemorySize(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst)) return CValue.none;

    const pl_op = f.air.instructions.items(.data)[inst].pl_op;

    const writer = f.object.writer();
    const inst_ty = f.air.typeOfIndex(inst);
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);

    try writer.writeAll(" = ");
    try writer.print("zig_wasm_memory_size({d});\n", .{pl_op.payload});

    return local;
}

fn airWasmMemoryGrow(f: *Function, inst: Air.Inst.Index) !CValue {
    const pl_op = f.air.instructions.items(.data)[inst].pl_op;

    const writer = f.object.writer();
    const inst_ty = f.air.typeOfIndex(inst);
    const operand = try f.resolveInst(pl_op.operand);
    try reap(f, inst, &.{pl_op.operand});
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);

    try writer.writeAll(" = ");
    try writer.print("zig_wasm_memory_grow({d}, ", .{pl_op.payload});
    try f.writeCValue(writer, operand, .FunctionArgument);
    try writer.writeAll(");\n");
    return local;
}

fn airFloatNeg(f: *Function, inst: Air.Inst.Index) !CValue {
    const inst_ty = f.air.typeOfIndex(inst);
    const un_op = f.air.instructions.items(.data)[inst].un_op;
    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{un_op});
        return CValue.none;
    }

    const operand = try f.resolveInst(un_op);
    try reap(f, inst, &.{un_op});
    const operand_ty = f.air.typeOf(un_op);

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = zig_neg_");
    try f.object.dg.renderTypeForBuiltinFnName(writer, operand_ty);
    try writer.writeByte('(');
    try f.writeCValue(writer, operand, .FunctionArgument);
    try writer.writeAll(");\n");
    return local;
}

fn airUnFloatOp(f: *Function, inst: Air.Inst.Index, operation: []const u8) !CValue {
    const un_op = f.air.instructions.items(.data)[inst].un_op;
    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{un_op});
        return CValue.none;
    }
    const operand = try f.resolveInst(un_op);
    try reap(f, inst, &.{un_op});
    const writer = f.object.writer();
    const inst_ty = f.air.typeOfIndex(inst);
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = zig_libc_name_");
    try f.object.dg.renderTypeForBuiltinFnName(writer, inst_ty);
    try writer.writeByte('(');
    try writer.writeAll(operation);
    try writer.writeAll(")(");
    try f.writeCValue(writer, operand, .FunctionArgument);
    try writer.writeAll(");\n");
    return local;
}

fn airBinFloatOp(f: *Function, inst: Air.Inst.Index, operation: []const u8) !CValue {
    const bin_op = f.air.instructions.items(.data)[inst].bin_op;
    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
        return CValue.none;
    }
    const lhs = try f.resolveInst(bin_op.lhs);
    const rhs = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const writer = f.object.writer();
    const inst_ty = f.air.typeOfIndex(inst);
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = zig_libc_name_");
    try f.object.dg.renderTypeForBuiltinFnName(writer, inst_ty);
    try writer.writeByte('(');
    try writer.writeAll(operation);
    try writer.writeAll(")(");
    try f.writeCValue(writer, lhs, .FunctionArgument);
    try writer.writeAll(", ");
    try f.writeCValue(writer, rhs, .FunctionArgument);
    try writer.writeAll(");\n");
    return local;
}

fn airMulAdd(f: *Function, inst: Air.Inst.Index) !CValue {
    const pl_op = f.air.instructions.items(.data)[inst].pl_op;
    const bin_op = f.air.extraData(Air.Bin, pl_op.payload).data;
    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs, pl_op.operand });
        return CValue.none;
    }
    const inst_ty = f.air.typeOfIndex(inst);
    const mulend1 = try f.resolveInst(bin_op.lhs);
    const mulend2 = try f.resolveInst(bin_op.rhs);
    const addend = try f.resolveInst(pl_op.operand);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs, pl_op.operand });
    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = zig_libc_name_");
    try f.object.dg.renderTypeForBuiltinFnName(writer, inst_ty);
    try writer.writeAll("(fma)(");
    try f.writeCValue(writer, mulend1, .FunctionArgument);
    try writer.writeAll(", ");
    try f.writeCValue(writer, mulend2, .FunctionArgument);
    try writer.writeAll(", ");
    try f.writeCValue(writer, addend, .FunctionArgument);
    try writer.writeAll(");\n");
    return local;
}

fn toMemoryOrder(order: std.builtin.AtomicOrder) [:0]const u8 {
    return switch (order) {
        // Note: unordered is actually even less atomic than relaxed
        .Unordered, .Monotonic => "memory_order_relaxed",
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

fn signAbbrev(signedness: std.builtin.Signedness) u8 {
    return switch (signedness) {
        .signed => 'i',
        .unsigned => 'u',
    };
}

fn compilerRtAbbrev(ty: Type, target: std.Target) []const u8 {
    return if (ty.isInt()) switch (ty.intInfo(target).bits) {
        1...32 => "si",
        33...64 => "di",
        65...128 => "ti",
        else => unreachable,
    } else if (ty.isRuntimeFloat()) switch (ty.floatBits(target)) {
        16 => "hf",
        32 => "sf",
        64 => "df",
        80 => "xf",
        128 => "tf",
        else => unreachable,
    } else unreachable;
}

fn formatStringLiteral(
    str: []const u8,
    comptime fmt: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    if (fmt.len != 1 or fmt[0] != 's') @compileError("Invalid fmt: " ++ fmt);
    try writer.writeByte('\"');
    for (str) |c|
        try writeStringLiteralChar(writer, c);
    try writer.writeByte('\"');
}

fn fmtStringLiteral(str: []const u8) std.fmt.Formatter(formatStringLiteral) {
    return .{ .data = str };
}

fn writeStringLiteralChar(writer: anytype, c: u8) !void {
    switch (c) {
        7 => try writer.writeAll("\\a"),
        8 => try writer.writeAll("\\b"),
        '\t' => try writer.writeAll("\\t"),
        '\n' => try writer.writeAll("\\n"),
        11 => try writer.writeAll("\\v"),
        12 => try writer.writeAll("\\f"),
        '\r' => try writer.writeAll("\\r"),
        '"', '\'', '?', '\\' => try writer.print("\\{c}", .{c}),
        else => switch (c) {
            ' '...'~' => try writer.writeByte(c),
            else => try writer.print("\\{o:0>3}", .{c}),
        },
    }
}

fn undefPattern(comptime IntType: type) IntType {
    const int_info = @typeInfo(IntType).Int;
    const UnsignedType = std.meta.Int(.unsigned, int_info.bits);
    return @bitCast(IntType, @as(UnsignedType, (1 << (int_info.bits | 1)) / 3));
}

const FormatIntLiteralContext = struct {
    ty: Type,
    val: Value,
    mod: *Module,
};
fn formatIntLiteral(
    data: FormatIntLiteralContext,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    const target = data.mod.getTarget();
    const int_info = data.ty.intInfo(target);

    const ExpectedContents = struct {
        const base = 10;
        const limbs_count_128 = BigInt.calcTwosCompLimbCount(128);
        const expected_needed_limbs_count = BigInt.calcToStringLimbsBufferLen(limbs_count_128, base);
        const worst_case_int = BigInt.Const{
            .limbs = &([1]BigIntLimb{std.math.maxInt(BigIntLimb)} ** expected_needed_limbs_count),
            .positive = false,
        };

        undef_limbs: [limbs_count_128]BigIntLimb,
        wrap_limbs: [limbs_count_128]BigIntLimb,
    };
    var stack align(@alignOf(ExpectedContents)) =
        std.heap.stackFallback(@sizeOf(ExpectedContents), data.mod.gpa);
    const allocator = stack.get();

    var undef_limbs: []BigIntLimb = &.{};
    defer allocator.free(undef_limbs);

    var int_buf: Value.BigIntSpace = undefined;
    const int = if (data.val.isUndefDeep()) blk: {
        undef_limbs = try allocator.alloc(BigIntLimb, BigInt.calcTwosCompLimbCount(int_info.bits));
        std.mem.set(BigIntLimb, undef_limbs, undefPattern(BigIntLimb));

        var undef_int = BigInt.Mutable{
            .limbs = undef_limbs,
            .len = undef_limbs.len,
            .positive = true,
        };
        undef_int.truncate(undef_int.toConst(), int_info.signedness, int_info.bits);
        break :blk undef_int.toConst();
    } else data.val.toBigInt(&int_buf, target);
    assert(int.fitsInTwosComp(int_info.signedness, int_info.bits));

    const c_bits = toCIntBits(int_info.bits) orelse unreachable;
    var one_limbs: [BigInt.calcLimbLen(1)]BigIntLimb = undefined;
    const one = BigInt.Mutable.init(&one_limbs, 1).toConst();

    const wrap_limbs = try allocator.alloc(BigIntLimb, BigInt.calcTwosCompLimbCount(c_bits));
    defer allocator.free(wrap_limbs);
    var wrap = BigInt.Mutable{ .limbs = wrap_limbs, .len = undefined, .positive = undefined };
    if (wrap.addWrap(int, one, int_info.signedness, c_bits) or
        int_info.signedness == .signed and wrap.subWrap(int, one, int_info.signedness, c_bits))
    {
        const abbrev = switch (data.ty.tag()) {
            .c_short, .c_ushort => "SHRT",
            .c_int, .c_uint => "INT",
            .c_long, .c_ulong => "LONG",
            .c_longlong, .c_ulonglong => "LLONG",
            .isize, .usize => "INTPTR",
            else => return writer.print("zig_{s}Int_{c}{d}", .{
                if (int.positive) "max" else "min", signAbbrev(int_info.signedness), c_bits,
            }),
        };
        if (int_info.signedness == .unsigned) try writer.writeByte('U');
        return writer.print("{s}_{s}", .{ abbrev, if (int.positive) "MAX" else "MIN" });
    }

    if (!int.positive) try writer.writeByte('-');
    switch (data.ty.tag()) {
        .c_short, .c_ushort, .c_int, .c_uint, .c_long, .c_ulong, .c_longlong, .c_ulonglong => {},
        else => try writer.print("zig_as_{c}{d}(", .{ signAbbrev(int_info.signedness), c_bits }),
    }

    const limbs_count_64 = @divExact(64, @bitSizeOf(BigIntLimb));
    if (c_bits <= 64) {
        var base: u8 = undefined;
        var case: std.fmt.Case = undefined;
        switch (fmt.len) {
            0 => base = 10,
            1 => switch (fmt[0]) {
                'b' => {
                    base = 2;
                    try writer.writeAll("0b");
                },
                'o' => {
                    base = 8;
                    try writer.writeByte('0');
                },
                'd' => base = 10,
                'x' => {
                    base = 16;
                    case = .lower;
                    try writer.writeAll("0x");
                },
                'X' => {
                    base = 16;
                    case = .upper;
                    try writer.writeAll("0x");
                },
                else => @compileError("Invalid fmt: " ++ fmt),
            },
            else => @compileError("Invalid fmt: " ++ fmt),
        }

        var str: [64]u8 = undefined;
        var limbs_buf: [BigInt.calcToStringLimbsBufferLen(limbs_count_64, 10)]BigIntLimb = undefined;
        try writer.writeAll(str[0..int.abs().toString(&str, base, case, &limbs_buf)]);
    } else {
        assert(c_bits == 128);
        const split = std.math.min(int.limbs.len, limbs_count_64);

        var upper_pl = Value.Payload.BigInt{
            .base = .{ .tag = .int_big_positive },
            .data = int.limbs[split..],
        };
        const upper_val = Value.initPayload(&upper_pl.base);
        try formatIntLiteral(.{
            .ty = switch (int_info.signedness) {
                .unsigned => Type.u64,
                .signed => Type.i64,
            },
            .val = upper_val,
            .mod = data.mod,
        }, fmt, options, writer);

        try writer.writeAll(", ");

        var lower_pl = Value.Payload.BigInt{
            .base = .{ .tag = .int_big_positive },
            .data = int.limbs[0..split],
        };
        const lower_val = Value.initPayload(&lower_pl.base);
        try formatIntLiteral(.{
            .ty = Type.u64,
            .val = lower_val,
            .mod = data.mod,
        }, fmt, options, writer);

        return writer.writeByte(')');
    }

    switch (data.ty.tag()) {
        .c_short, .c_ushort, .c_int => {},
        .c_uint => try writer.writeAll("u"),
        .c_long => try writer.writeAll("l"),
        .c_ulong => try writer.writeAll("ul"),
        .c_longlong => try writer.writeAll("ll"),
        .c_ulonglong => try writer.writeAll("ull"),
        else => try writer.writeByte(')'),
    }
}

fn isByRef(ty: Type) bool {
    _ = ty;
    return false;
}

const LowerFnRetTyBuffer = struct {
    types: [1]Type,
    values: [1]Value,
    payload: Type.Payload.Tuple,
};
fn lowerFnRetTy(ret_ty: Type, buffer: *LowerFnRetTyBuffer, target: std.Target) Type {
    if (ret_ty.zigTypeTag() == .NoReturn) return Type.initTag(.noreturn);

    if (lowersToArray(ret_ty, target)) {
        buffer.types = [1]Type{ret_ty};
        buffer.values = [1]Value{Value.initTag(.unreachable_value)};
        buffer.payload = .{ .data = .{
            .types = &buffer.types,
            .values = &buffer.values,
        } };
        return Type.initPayload(&buffer.payload.base);
    }

    return if (ret_ty.hasRuntimeBitsIgnoreComptime()) ret_ty else Type.void;
}

fn lowersToArray(ty: Type, target: std.Target) bool {
    return switch (ty.zigTypeTag()) {
        .Array, .Vector => return true,
        else => return ty.isAbiInt() and toCIntBits(@intCast(u32, ty.bitSize(target))) == null,
    };
}

fn loweredArrayInfo(ty: Type, target: std.Target) ?Type.ArrayInfo {
    if (!lowersToArray(ty, target)) return null;

    switch (ty.zigTypeTag()) {
        .Array, .Vector => return ty.arrayInfo(),
        else => {
            const abi_size = ty.abiSize(target);
            const abi_align = ty.abiAlignment(target);
            return Type.ArrayInfo{
                .elem_type = switch (abi_align) {
                    1 => Type.u8,
                    2 => Type.u16,
                    4 => Type.u32,
                    8 => Type.u64,
                    16 => Type.initTag(.u128),
                    else => unreachable,
                },
                .len = @divExact(abi_size, abi_align),
            };
        },
    }
}

fn reap(f: *Function, inst: Air.Inst.Index, operands: []const Air.Inst.Ref) !void {
    assert(operands.len <= Liveness.bpi - 1);
    var tomb_bits = f.liveness.getTombBits(inst);
    for (operands) |operand| {
        const dies = @truncate(u1, tomb_bits) != 0;
        tomb_bits >>= 1;
        if (!dies) continue;
        try die(f, inst, operand);
    }
}

fn die(f: *Function, inst: Air.Inst.Index, ref: Air.Inst.Ref) !void {
    const ref_inst = Air.refToIndex(ref) orelse return;
    if (f.air.instructions.items(.tag)[ref_inst] == .constant) return;
    const c_value = (f.value_map.fetchRemove(ref) orelse return).value;
    const local_index = switch (c_value) {
        .local => |l| l,
        else => return,
    };
    try freeLocal(f, inst, local_index, ref_inst);
}

fn freeLocal(f: *Function, inst: Air.Inst.Index, local_index: LocalIndex, ref_inst: Air.Inst.Index) !void {
    const gpa = f.object.dg.gpa;
    const local = &f.locals.items[local_index];
    log.debug("%{d}: freeing t{d} (operand %{d})", .{ inst, local_index, ref_inst });
    if (local.loop_depth < f.free_locals_clone_depth) return;
    const gop = try f.free_locals_stack.items[local.loop_depth].getOrPutContext(
        gpa,
        local.ty,
        f.tyHashCtx(),
    );
    if (!gop.found_existing) gop.value_ptr.* = .{};
    if (std.debug.runtime_safety) {
        // If this trips, it means a local is being inserted into the
        // free_locals map while it already exists in the map, which is not
        // allowed.
        assert(mem.indexOfScalar(LocalIndex, gop.value_ptr.items, local_index) == null);
        // If this trips, an unfreeable allocation was attempted to be freed.
        assert(!f.allocs.contains(local_index));
    }
    try gop.value_ptr.append(gpa, local_index);
}

const BigTomb = struct {
    f: *Function,
    inst: Air.Inst.Index,
    lbt: Liveness.BigTomb,

    fn feed(bt: *BigTomb, op_ref: Air.Inst.Ref) !void {
        const dies = bt.lbt.feed();
        if (!dies) return;
        try die(bt.f, bt.inst, op_ref);
    }
};

fn iterateBigTomb(f: *Function, inst: Air.Inst.Index) BigTomb {
    return .{
        .f = f,
        .inst = inst,
        .lbt = f.liveness.iterateBigTomb(inst),
    };
}

/// A naive clone of this map would create copies of the ArrayList which is
/// stored in the values. This function additionally clones the values.
fn cloneFreeLocalsMap(gpa: mem.Allocator, map: *LocalsMap) !LocalsMap {
    var cloned = try map.clone(gpa);
    const values = cloned.values();
    var i: usize = 0;
    errdefer {
        cloned.deinit(gpa);
        while (i > 0) {
            i -= 1;
            values[i].deinit(gpa);
        }
    }
    while (i < values.len) : (i += 1) {
        values[i] = try values[i].clone(gpa);
    }
    return cloned;
}

fn deinitFreeLocalsMap(gpa: mem.Allocator, map: *LocalsMap) void {
    for (map.values()) |*value| {
        value.deinit(gpa);
    }
    map.deinit(gpa);
}

fn noticeBranchFrees(f: *Function, pre_locals_len: LocalIndex, inst: Air.Inst.Index) !void {
    for (f.locals.items[pre_locals_len..]) |*local, local_offset| {
        const local_index = pre_locals_len + @intCast(LocalIndex, local_offset);
        if (f.allocs.contains(local_index)) continue; // allocs are not freeable

        // free more deeply nested locals from other branches at current depth
        assert(local.loop_depth >= f.free_locals_stack.items.len - 1);
        local.loop_depth = @intCast(LoopDepth, f.free_locals_stack.items.len - 1);
        try freeLocal(f, inst, local_index, 0);
    }
}
