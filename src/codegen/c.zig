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

const target_util = @import("../target.zig");
const libcFloatPrefix = target_util.libcFloatPrefix;
const libcFloatSuffix = target_util.libcFloatSuffix;
const compilerRtFloatAbbrev = target_util.compilerRtFloatAbbrev;
const compilerRtIntAbbrev = target_util.compilerRtIntAbbrev;

const BigIntLimb = std.math.big.Limb;
const BigInt = std.math.big.int;

pub const CType = @import("c/type.zig").CType;

pub const CValue = union(enum) {
    none: void,
    new_local: LocalIndex,
    local: LocalIndex,
    /// Address of a local.
    local_ref: LocalIndex,
    /// A constant instruction, to be rendered inline.
    constant: Air.Inst.Ref,
    /// Index into the parameters
    arg: usize,
    /// The array field of a parameter
    arg_array: usize,
    /// Index into a tuple's fields
    field: usize,
    /// By-value
    decl: Decl.Index,
    decl_ref: Decl.Index,
    /// An undefined value (cannot be dereferenced)
    undef: Type,
    /// Render the slice as an identifier (using fmtIdent)
    identifier: []const u8,
    /// Render the slice as an payload.identifier (using fmtIdent)
    payload_identifier: []const u8,
    /// Render these bytes literally.
    /// TODO make this a [*:0]const u8 to save memory
    bytes: []const u8,
};

const BlockData = struct {
    block_id: usize,
    result: CValue,
};

pub const CValueMap = std.AutoHashMap(Air.Inst.Ref, CValue);

pub const LazyFnKey = union(enum) {
    tag_name: Decl.Index,
    never_tail: Decl.Index,
    never_inline: Decl.Index,
};
pub const LazyFnValue = struct {
    fn_name: []const u8,
    data: Data,

    pub const Data = union {
        tag_name: Type,
        never_tail: void,
        never_inline: void,
    };
};
pub const LazyFnMap = std.AutoArrayHashMapUnmanaged(LazyFnKey, LazyFnValue);

const LoopDepth = u16;
const Local = struct {
    cty_idx: CType.Index,
    /// How many loops the last definition was nested in.
    loop_depth: LoopDepth,
    alignas: CType.AlignAs,

    pub fn getType(local: Local) LocalType {
        return .{ .cty_idx = local.cty_idx, .alignas = local.alignas };
    }
};

const LocalIndex = u16;
const LocalType = struct { cty_idx: CType.Index, alignas: CType.AlignAs };
const LocalsList = std.AutoArrayHashMapUnmanaged(LocalIndex, void);
const LocalsMap = std.AutoArrayHashMapUnmanaged(LocalType, LocalsList);
const LocalsStack = std.ArrayListUnmanaged(LocalsMap);

const ValueRenderLocation = enum {
    FunctionArgument,
    Initializer,
    StaticInitializer,
    Other,

    pub fn isInitializer(self: ValueRenderLocation) bool {
        return switch (self) {
            .Initializer, .StaticInitializer => true,
            else => false,
        };
    }
};

const BuiltinInfo = enum {
    None,
    Range,
    Bits,
};

const reserved_idents = std.ComptimeStringMap(void, .{
    // C language
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

    // stdarg.h
    .{ "va_start", {} },
    .{ "va_arg", {} },
    .{ "va_end", {} },
    .{ "va_copy", {} },

    // stddef.h
    .{ "offsetof", {} },

    // windows.h
    .{ "max", {} },
    .{ "min", {} },
});

fn isReservedIdent(ident: []const u8) bool {
    if (ident.len >= 2 and ident[0] == '_') { // C language
        switch (ident[1]) {
            'A'...'Z', '_' => return true,
            else => return false,
        }
    } else if (std.mem.startsWith(u8, ident, "DUMMYSTRUCTNAME") or
        std.mem.startsWith(u8, ident, "DUMMYUNIONNAME"))
    { // windows.h
        return true;
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
    for (ident, 0..) |c, i| {
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
    lazy_fns: LazyFnMap,
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

    fn resolveInst(f: *Function, inst: Air.Inst.Ref) !CValue {
        const gop = try f.value_map.getOrPut(inst);
        if (gop.found_existing) return gop.value_ptr.*;

        const val = f.air.value(inst).?;
        const ty = f.air.typeOf(inst);

        const result: CValue = if (lowersToArray(ty, f.object.dg.module.getTarget())) result: {
            const writer = f.object.code_header.writer();
            const alignment = 0;
            const decl_c_value = try f.allocLocalValue(ty, alignment);
            const gpa = f.object.dg.gpa;
            try f.allocs.put(gpa, decl_c_value.new_local, true);
            try writer.writeAll("static ");
            try f.object.dg.renderTypeAndName(writer, ty, decl_c_value, Const, alignment, .complete);
            try writer.writeAll(" = ");
            try f.object.dg.renderValue(writer, ty, val, .StaticInitializer);
            try writer.writeAll(";\n ");
            break :result decl_c_value;
        } else .{ .constant = inst };

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
        const target = f.object.dg.module.getTarget();
        try f.locals.append(gpa, .{
            .cty_idx = try f.typeToIndex(ty, .complete),
            .loop_depth = @intCast(LoopDepth, f.free_locals_stack.items.len - 1),
            .alignas = CType.AlignAs.init(alignment, ty.abiAlignment(target)),
        });
        return .{ .new_local = @intCast(LocalIndex, f.locals.items.len - 1) };
    }

    fn allocLocal(f: *Function, inst: Air.Inst.Index, ty: Type) !CValue {
        const result = try f.allocAlignedLocal(ty, .{}, 0);
        log.debug("%{d}: allocating t{d}", .{ inst, result.new_local });
        return result;
    }

    /// Only allocates the local; does not print anything.
    fn allocAlignedLocal(f: *Function, ty: Type, _: CQualifiers, alignment: u32) !CValue {
        const target = f.object.dg.module.getTarget();
        if (f.getFreeLocals().getPtr(.{
            .cty_idx = try f.typeToIndex(ty, .complete),
            .alignas = CType.AlignAs.init(alignment, ty.abiAlignment(target)),
        })) |locals_list| {
            if (locals_list.popOrNull()) |local_entry| {
                const local = &f.locals.items[local_entry.key];
                local.loop_depth = @intCast(LoopDepth, f.free_locals_stack.items.len - 1);
                return .{ .new_local = local_entry.key };
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

    fn indexToCType(f: *Function, idx: CType.Index) CType {
        return f.object.dg.indexToCType(idx);
    }

    fn typeToIndex(f: *Function, ty: Type, kind: CType.Kind) !CType.Index {
        return f.object.dg.typeToIndex(ty, kind);
    }

    fn typeToCType(f: *Function, ty: Type, kind: CType.Kind) !CType {
        return f.object.dg.typeToCType(ty, kind);
    }

    fn renderType(f: *Function, w: anytype, t: Type) !void {
        return f.object.dg.renderType(w, t);
    }

    fn renderIntCast(f: *Function, w: anytype, dest_ty: Type, src: CValue, src_ty: Type, location: ValueRenderLocation) !void {
        return f.object.dg.renderIntCast(w, dest_ty, .{ .c_value = .{ .f = f, .value = src } }, src_ty, location);
    }

    fn fmtIntLiteral(f: *Function, ty: Type, val: Value) !std.fmt.Formatter(formatIntLiteral) {
        return f.object.dg.fmtIntLiteral(ty, val);
    }

    fn getLazyFnName(f: *Function, key: LazyFnKey, data: LazyFnValue.Data) ![]const u8 {
        const gpa = f.object.dg.gpa;
        const gop = try f.lazy_fns.getOrPut(gpa, key);
        if (!gop.found_existing) {
            errdefer _ = f.lazy_fns.pop();

            var promoted = f.object.dg.ctypes.promote(gpa);
            defer f.object.dg.ctypes.demote(promoted);
            const arena = promoted.arena.allocator();

            gop.value_ptr.* = .{
                .fn_name = switch (key) {
                    .tag_name,
                    .never_tail,
                    .never_inline,
                    => |owner_decl| try std.fmt.allocPrint(arena, "zig_{s}_{}__{d}", .{
                        @tagName(key),
                        fmtIdent(mem.span(f.object.dg.module.declPtr(owner_decl).name)),
                        @enumToInt(owner_decl),
                    }),
                },
                .data = switch (key) {
                    .tag_name => .{ .tag_name = try data.tag_name.copy(arena) },
                    .never_tail => .{ .never_tail = data.never_tail },
                    .never_inline => .{ .never_inline = data.never_inline },
                },
            };
        }
        return gop.value_ptr.fn_name;
    }

    pub fn deinit(f: *Function) void {
        const gpa = f.object.dg.gpa;
        f.allocs.deinit(gpa);
        f.locals.deinit(gpa);
        for (f.free_locals_stack.items) |*free_locals| {
            deinitFreeLocalsMap(gpa, free_locals);
        }
        f.free_locals_stack.deinit(gpa);
        f.blocks.deinit(gpa);
        f.value_map.deinit();
        f.lazy_fns.deinit(gpa);
        f.object.code.deinit();
        f.object.dg.ctypes.deinit(gpa);
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
    decl: ?*Decl,
    decl_index: Decl.OptionalIndex,
    fwd_decl: std.ArrayList(u8),
    error_msg: ?*Module.ErrorMsg,
    ctypes: CType.Store,

    fn fail(dg: *DeclGen, comptime format: []const u8, args: anytype) error{ AnalysisFail, OutOfMemory } {
        @setCold(true);
        const src = LazySrcLoc.nodeOffset(0);
        const src_loc = src.toSrcLoc(dg.decl.?);
        dg.error_msg = try Module.ErrorMsg.create(dg.gpa, src_loc, format, args);
        return error.AnalysisFail;
    }

    fn renderDeclValue(
        dg: *DeclGen,
        writer: anytype,
        ty: Type,
        val: Value,
        decl_index: Decl.Index,
        location: ValueRenderLocation,
    ) error{ OutOfMemory, AnalysisFail }!void {
        const decl = dg.module.declPtr(decl_index);
        assert(decl.has_tv);

        // Render an undefined pointer if we have a pointer to a zero-bit or comptime type.
        if (ty.isPtrAtRuntime() and !decl.ty.isFnOrHasRuntimeBits()) {
            return dg.writeCValue(writer, .{ .undef = ty });
        }

        // Chase function values in order to be able to reference the original function.
        inline for (.{ .function, .extern_fn }) |tag|
            if (decl.val.castTag(tag)) |func|
                if (func.data.owner_decl != decl_index)
                    return dg.renderDeclValue(writer, ty, val, func.data.owner_decl, location);

        if (ty.isSlice()) {
            if (location == .StaticInitializer) {
                try writer.writeByte('{');
            } else {
                try writer.writeByte('(');
                try dg.renderType(writer, ty);
                try writer.writeAll("){ .ptr = ");
            }

            var buf: Type.SlicePtrFieldTypeBuffer = undefined;
            try dg.renderValue(writer, ty.slicePtrFieldType(&buf), val.slicePtr(), .Initializer);

            var len_pl: Value.Payload.U64 = .{
                .base = .{ .tag = .int_u64 },
                .data = val.sliceLen(dg.module),
            };
            const len_val = Value.initPayload(&len_pl.base);

            if (location == .StaticInitializer) {
                return writer.print(", {} }}", .{try dg.fmtIntLiteral(Type.usize, len_val)});
            } else {
                return writer.print(", .len = {} }}", .{try dg.fmtIntLiteral(Type.usize, len_val)});
            }
        }

        // We shouldn't cast C function pointers as this is UB (when you call
        // them).  The analysis until now should ensure that the C function
        // pointers are compatible.  If they are not, then there is a bug
        // somewhere and we should let the C compiler tell us about it.
        const need_typecast = if (ty.castPtrToFn()) |_| false else !ty.eql(decl.ty, dg.module);
        if (need_typecast) {
            try writer.writeAll("((");
            try dg.renderType(writer, ty);
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
    fn renderParentPtr(dg: *DeclGen, writer: anytype, ptr_val: Value, ptr_ty: Type, location: ValueRenderLocation) error{ OutOfMemory, AnalysisFail }!void {
        if (!ptr_ty.isSlice()) {
            try writer.writeByte('(');
            try dg.renderType(writer, ptr_ty);
            try writer.writeByte(')');
        }
        switch (ptr_val.tag()) {
            .int_u64, .one => try writer.print("{x}", .{try dg.fmtIntLiteral(Type.usize, ptr_val)}),
            .decl_ref_mut, .decl_ref, .variable => {
                const decl_index = switch (ptr_val.tag()) {
                    .decl_ref => ptr_val.castTag(.decl_ref).?.data,
                    .decl_ref_mut => ptr_val.castTag(.decl_ref_mut).?.data.decl_index,
                    .variable => ptr_val.castTag(.variable).?.data.owner_decl,
                    else => unreachable,
                };
                try dg.renderDeclValue(writer, ptr_ty, ptr_val, decl_index, location);
            },
            .field_ptr => {
                const target = dg.module.getTarget();
                const field_ptr = ptr_val.castTag(.field_ptr).?.data;

                // Ensure complete type definition is visible before accessing fields.
                _ = try dg.typeToIndex(field_ptr.container_ty, .complete);

                var container_ptr_pl = ptr_ty.ptrInfo();
                container_ptr_pl.data.pointee_type = field_ptr.container_ty;
                const container_ptr_ty = Type.initPayload(&container_ptr_pl.base);

                switch (fieldLocation(
                    field_ptr.container_ty,
                    ptr_ty,
                    @intCast(u32, field_ptr.field_index),
                    target,
                )) {
                    .begin => try dg.renderParentPtr(
                        writer,
                        field_ptr.container_ptr,
                        container_ptr_ty,
                        location,
                    ),
                    .field => |field| {
                        try writer.writeAll("&(");
                        try dg.renderParentPtr(
                            writer,
                            field_ptr.container_ptr,
                            container_ptr_ty,
                            location,
                        );
                        try writer.writeAll(")->");
                        try dg.writeCValue(writer, field);
                    },
                    .byte_offset => |byte_offset| {
                        var u8_ptr_pl = ptr_ty.ptrInfo();
                        u8_ptr_pl.data.pointee_type = Type.u8;
                        const u8_ptr_ty = Type.initPayload(&u8_ptr_pl.base);

                        var byte_offset_pl = Value.Payload.U64{
                            .base = .{ .tag = .int_u64 },
                            .data = byte_offset,
                        };
                        const byte_offset_val = Value.initPayload(&byte_offset_pl.base);

                        try writer.writeAll("((");
                        try dg.renderType(writer, u8_ptr_ty);
                        try writer.writeByte(')');
                        try dg.renderParentPtr(
                            writer,
                            field_ptr.container_ptr,
                            container_ptr_ty,
                            location,
                        );
                        try writer.print(" + {})", .{try dg.fmtIntLiteral(Type.usize, byte_offset_val)});
                    },
                    .end => {
                        try writer.writeAll("((");
                        try dg.renderParentPtr(
                            writer,
                            field_ptr.container_ptr,
                            container_ptr_ty,
                            location,
                        );
                        try writer.print(") + {})", .{try dg.fmtIntLiteral(Type.usize, Value.one)});
                    },
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
                try dg.renderParentPtr(writer, elem_ptr.array_ptr, elem_ptr_ty, location);
                try writer.print(")[{d}]", .{elem_ptr.index});
            },
            .opt_payload_ptr, .eu_payload_ptr => {
                const payload_ptr = ptr_val.cast(Value.Payload.PayloadPtr).?.data;
                var container_ptr_ty_pl: Type.Payload.ElemType = .{
                    .base = .{ .tag = .c_mut_pointer },
                    .data = payload_ptr.container_ty,
                };
                const container_ptr_ty = Type.initPayload(&container_ptr_ty_pl.base);

                // Ensure complete type definition is visible before accessing fields.
                _ = try dg.typeToIndex(payload_ptr.container_ty, .complete);

                try writer.writeAll("&(");
                try dg.renderParentPtr(writer, payload_ptr.container_ptr, container_ptr_ty, location);
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
        const initializer_type: ValueRenderLocation = switch (location) {
            .StaticInitializer => .StaticInitializer,
            else => .Initializer,
        };

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
                .Int, .Enum, .ErrorSet => return writer.print("{x}", .{try dg.fmtIntLiteralLoc(ty, val, location)}),
                .Float => {
                    const bits = ty.floatBits(target);
                    var int_pl = Type.Payload.Bits{ .base = .{ .tag = .int_signed }, .data = bits };
                    const int_ty = Type.initPayload(&int_pl.base);

                    try writer.writeAll("zig_cast_");
                    try dg.renderTypeForBuiltinFnName(writer, ty);
                    try writer.writeAll(" zig_make_");
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
                    if (!location.isInitializer()) {
                        try writer.writeByte('(');
                        try dg.renderType(writer, ty);
                        try writer.writeByte(')');
                    }

                    try writer.writeAll("{(");
                    var buf: Type.SlicePtrFieldTypeBuffer = undefined;
                    const ptr_ty = ty.slicePtrFieldType(&buf);
                    try dg.renderType(writer, ptr_ty);
                    return writer.print("){x}, {0x}}}", .{try dg.fmtIntLiteral(Type.usize, val)});
                } else {
                    try writer.writeAll("((");
                    try dg.renderType(writer, ty);
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

                    if (!location.isInitializer()) {
                        try writer.writeByte('(');
                        try dg.renderType(writer, ty);
                        try writer.writeByte(')');
                    }

                    try writer.writeAll("{ .payload = ");
                    try dg.renderValue(writer, payload_ty, val, initializer_type);
                    try writer.writeAll(", .is_null = ");
                    try dg.renderValue(writer, Type.bool, val, initializer_type);
                    return writer.writeAll(" }");
                },
                .Struct => switch (ty.containerLayout()) {
                    .Auto, .Extern => {
                        if (!location.isInitializer()) {
                            try writer.writeByte('(');
                            try dg.renderType(writer, ty);
                            try writer.writeByte(')');
                        }

                        try writer.writeByte('{');
                        var empty = true;
                        for (ty.structFields().values()) |field| {
                            if (!field.ty.hasRuntimeBits()) continue;

                            if (!empty) try writer.writeByte(',');
                            try dg.renderValue(writer, field.ty, val, initializer_type);

                            empty = false;
                        }

                        return writer.writeByte('}');
                    },
                    .Packed => return writer.print("{x}", .{try dg.fmtIntLiteral(ty, Value.undef)}),
                },
                .Union => {
                    if (!location.isInitializer()) {
                        try writer.writeByte('(');
                        try dg.renderType(writer, ty);
                        try writer.writeByte(')');
                    }

                    try writer.writeByte('{');
                    if (ty.unionTagTypeSafety()) |tag_ty| {
                        const layout = ty.unionGetLayout(target);
                        if (layout.tag_size != 0) {
                            try writer.writeAll(" .tag = ");
                            try dg.renderValue(writer, tag_ty, val, initializer_type);
                            try writer.writeByte(',');
                        }
                        try writer.writeAll(" .payload = {");
                    }
                    for (ty.unionFields().values()) |field| {
                        if (!field.ty.hasRuntimeBits()) continue;
                        try dg.renderValue(writer, field.ty, val, initializer_type);
                        break;
                    } else try writer.print("{x}", .{try dg.fmtIntLiteral(Type.u8, Value.undef)});
                    if (ty.unionTagTypeSafety()) |_| try writer.writeByte('}');
                    return writer.writeByte('}');
                },
                .ErrorUnion => {
                    if (!location.isInitializer()) {
                        try writer.writeByte('(');
                        try dg.renderType(writer, ty);
                        try writer.writeByte(')');
                    }

                    try writer.writeAll("{ .payload = ");
                    try dg.renderValue(writer, ty.errorUnionPayload(), val, initializer_type);
                    return writer.print(", .error = {x} }}", .{
                        try dg.fmtIntLiteral(ty.errorUnionSet(), val),
                    });
                },
                .Array, .Vector => {
                    if (!location.isInitializer()) {
                        try writer.writeByte('(');
                        try dg.renderType(writer, ty);
                        try writer.writeByte(')');
                    }

                    const ai = ty.arrayInfo();
                    if (ai.elem_type.eql(Type.u8, dg.module)) {
                        var literal = stringLiteral(writer);
                        try literal.start();
                        const c_len = ty.arrayLenIncludingSentinel();
                        var index: u64 = 0;
                        while (index < c_len) : (index += 1)
                            try literal.writeChar(0xaa);
                        return literal.end();
                    } else {
                        try writer.writeByte('{');
                        const c_len = ty.arrayLenIncludingSentinel();
                        var index: u64 = 0;
                        while (index < c_len) : (index += 1) {
                            if (index > 0) try writer.writeAll(", ");
                            try dg.renderValue(writer, ty.childType(), val, initializer_type);
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
                => try dg.renderParentPtr(writer, val, ty, location),
                else => try writer.print("{}", .{try dg.fmtIntLiteralLoc(ty, val, location)}),
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

                try writer.writeAll("zig_cast_");
                try dg.renderTypeForBuiltinFnName(writer, ty);
                try writer.writeByte(' ');
                var empty = true;
                if (std.math.isFinite(f128_val)) {
                    try writer.writeAll("zig_make_");
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
                    try writer.writeAll(", ");
                    empty = false;
                } else {
                    // isSignalNan is equivalent to isNan currently, and MSVC doens't have nans, so prefer nan
                    const operation = if (std.math.isNan(f128_val))
                        "nan"
                    else if (std.math.isSignalNan(f128_val))
                        "nans"
                    else if (std.math.isInf(f128_val))
                        "inf"
                    else
                        unreachable;

                    if (location == .StaticInitializer) {
                        if (!std.math.isNan(f128_val) and std.math.isSignalNan(f128_val))
                            return dg.fail("TODO: C backend: implement nans rendering in static initializers", .{});

                        // MSVC doesn't have a way to define a custom or signaling NaN value in a constant expression

                        // TODO: Re-enable this check, otherwise we're writing qnan bit patterns on msvc incorrectly
                        // if (std.math.isNan(f128_val) and f128_val != std.math.qnan_f128)
                        //     return dg.fail("Only quiet nans are supported in global variable initializers", .{});
                    }

                    try writer.writeAll("zig_make_special_");
                    if (location == .StaticInitializer) try writer.writeAll("constant_");
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
                    try writer.writeAll(", ");
                    empty = false;
                }
                try writer.print("{x}", .{try dg.fmtIntLiteralLoc(int_ty, int_val, location)});
                if (!empty) try writer.writeByte(')');
                return;
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
                    try dg.renderType(writer, ty);
                    try writer.writeAll(")NULL)");
                },
                .variable => {
                    const decl = val.castTag(.variable).?.data.owner_decl;
                    return dg.renderDeclValue(writer, ty, val, decl, location);
                },
                .slice => {
                    if (!location.isInitializer()) {
                        try writer.writeByte('(');
                        try dg.renderType(writer, ty);
                        try writer.writeByte(')');
                    }

                    const slice = val.castTag(.slice).?.data;
                    var buf: Type.SlicePtrFieldTypeBuffer = undefined;

                    try writer.writeByte('{');
                    try dg.renderValue(writer, ty.slicePtrFieldType(&buf), slice.ptr, initializer_type);
                    try writer.writeAll(", ");
                    try dg.renderValue(writer, Type.usize, slice.len, initializer_type);
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
                    try dg.renderType(writer, ty);
                    return writer.print("){x})", .{try dg.fmtIntLiteral(Type.usize, val)});
                },
                .field_ptr,
                .elem_ptr,
                .opt_payload_ptr,
                .eu_payload_ptr,
                .decl_ref_mut,
                .decl_ref,
                => try dg.renderParentPtr(writer, val, ty, location),
                else => unreachable,
            },
            .Array, .Vector => {
                if (location == .FunctionArgument) {
                    try writer.writeByte('(');
                    try dg.renderType(writer, ty);
                    try writer.writeByte(')');
                }

                // First try specific tag representations for more efficiency.
                switch (val.tag()) {
                    .undef, .empty_struct_value, .empty_array => {
                        const ai = ty.arrayInfo();
                        try writer.writeByte('{');
                        if (ai.sentinel) |s| {
                            try dg.renderValue(writer, ai.elem_type, s, initializer_type);
                        } else {
                            try writer.writeByte('0');
                        }
                        try writer.writeByte('}');
                    },
                    .bytes, .str_lit => |t| {
                        const bytes = switch (t) {
                            .bytes => val.castTag(.bytes).?.data,
                            .str_lit => bytes: {
                                const str_lit = val.castTag(.str_lit).?.data;
                                break :bytes dg.module.string_literal_bytes.items[str_lit.index..][0..str_lit.len];
                            },
                            else => unreachable,
                        };
                        const sentinel = if (ty.sentinel()) |sentinel| @intCast(u8, sentinel.toUnsignedInt(target)) else null;
                        try writer.print("{s}", .{
                            fmtStringLiteral(bytes[0..@intCast(usize, ty.arrayLen())], sentinel),
                        });
                    },
                    else => {
                        // Fall back to generic implementation.
                        var arena = std.heap.ArenaAllocator.init(dg.gpa);
                        defer arena.deinit();
                        const arena_allocator = arena.allocator();

                        // MSVC throws C2078 if an array of size 65536 or greater is initialized with a string literal
                        const max_string_initializer_len = 65535;

                        const ai = ty.arrayInfo();
                        if (ai.elem_type.eql(Type.u8, dg.module)) {
                            if (ai.len <= max_string_initializer_len) {
                                var literal = stringLiteral(writer);
                                try literal.start();
                                var index: usize = 0;
                                while (index < ai.len) : (index += 1) {
                                    const elem_val = try val.elemValue(dg.module, arena_allocator, index);
                                    const elem_val_u8 = if (elem_val.isUndef()) undefPattern(u8) else @intCast(u8, elem_val.toUnsignedInt(target));
                                    try literal.writeChar(elem_val_u8);
                                }
                                if (ai.sentinel) |s| {
                                    const s_u8 = @intCast(u8, s.toUnsignedInt(target));
                                    if (s_u8 != 0) try literal.writeChar(s_u8);
                                }
                                try literal.end();
                            } else {
                                try writer.writeByte('{');
                                var index: usize = 0;
                                while (index < ai.len) : (index += 1) {
                                    if (index != 0) try writer.writeByte(',');
                                    const elem_val = try val.elemValue(dg.module, arena_allocator, index);
                                    const elem_val_u8 = if (elem_val.isUndef()) undefPattern(u8) else @intCast(u8, elem_val.toUnsignedInt(target));
                                    try writer.print("'\\x{x}'", .{elem_val_u8});
                                }
                                if (ai.sentinel) |s| {
                                    if (index != 0) try writer.writeByte(',');
                                    try dg.renderValue(writer, ai.elem_type, s, initializer_type);
                                }
                                try writer.writeByte('}');
                            }
                        } else {
                            try writer.writeByte('{');
                            var index: usize = 0;
                            while (index < ai.len) : (index += 1) {
                                if (index != 0) try writer.writeByte(',');
                                const elem_val = try val.elemValue(dg.module, arena_allocator, index);
                                try dg.renderValue(writer, ai.elem_type, elem_val, initializer_type);
                            }
                            if (ai.sentinel) |s| {
                                if (index != 0) try writer.writeByte(',');
                                try dg.renderValue(writer, ai.elem_type, s, initializer_type);
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

                if (!location.isInitializer()) {
                    try writer.writeByte('(');
                    try dg.renderType(writer, ty);
                    try writer.writeByte(')');
                }

                const payload_val = if (val.castTag(.opt_payload)) |pl| pl.data else Value.undef;

                try writer.writeAll("{ .payload = ");
                try dg.renderValue(writer, payload_ty, payload_val, initializer_type);
                try writer.writeAll(", .is_null = ");
                try dg.renderValue(writer, Type.bool, is_null_val, initializer_type);
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

                if (!location.isInitializer()) {
                    try writer.writeByte('(');
                    try dg.renderType(writer, ty);
                    try writer.writeByte(')');
                }

                const payload_val = if (val.castTag(.eu_payload)) |pl| pl.data else Value.undef;
                const error_val = if (val.errorUnionIsPayload()) Value.zero else val;

                try writer.writeAll("{ .payload = ");
                try dg.renderValue(writer, payload_ty, payload_val, initializer_type);
                try writer.writeAll(", .error = ");
                try dg.renderValue(writer, error_ty, error_val, initializer_type);
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
                    return dg.renderDeclValue(writer, ty, val, decl, location);
                },
                .extern_fn => {
                    const decl = val.castTag(.extern_fn).?.data.owner_decl;
                    return dg.renderDeclValue(writer, ty, val, decl, location);
                },
                else => unreachable,
            },
            .Struct => switch (ty.containerLayout()) {
                .Auto, .Extern => {
                    const field_vals = val.castTag(.aggregate).?.data;

                    if (!location.isInitializer()) {
                        try writer.writeByte('(');
                        try dg.renderType(writer, ty);
                        try writer.writeByte(')');
                    }

                    try writer.writeByte('{');
                    var empty = true;
                    for (field_vals, 0..) |field_val, field_index| {
                        const field_ty = ty.structFieldType(field_index);
                        if (!field_ty.hasRuntimeBits()) continue;

                        if (!empty) try writer.writeByte(',');
                        try dg.renderValue(writer, field_ty, field_val, initializer_type);

                        empty = false;
                    }
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

                    var eff_num_fields: usize = 0;
                    for (0..field_vals.len) |index| {
                        const field_ty = ty.structFieldType(index);
                        if (!field_ty.hasRuntimeBitsIgnoreComptime()) continue;

                        eff_num_fields += 1;
                    }

                    if (eff_num_fields == 0) {
                        try writer.writeByte('(');
                        try dg.renderValue(writer, ty, Value.undef, initializer_type);
                        try writer.writeByte(')');
                    } else if (ty.bitSize(target) > 64) {
                        // zig_or_u128(zig_or_u128(zig_shl_u128(a, a_off), zig_shl_u128(b, b_off)), zig_shl_u128(c, c_off))
                        var num_or = eff_num_fields - 1;
                        while (num_or > 0) : (num_or -= 1) {
                            try writer.writeAll("zig_or_");
                            try dg.renderTypeForBuiltinFnName(writer, ty);
                            try writer.writeByte('(');
                        }

                        var eff_index: usize = 0;
                        var needs_closing_paren = false;
                        for (field_vals, 0..) |field_val, index| {
                            const field_ty = ty.structFieldType(index);
                            if (!field_ty.hasRuntimeBitsIgnoreComptime()) continue;

                            const cast_context = IntCastContext{ .value = .{ .value = field_val } };
                            if (bit_offset_val_pl.data != 0) {
                                try writer.writeAll("zig_shl_");
                                try dg.renderTypeForBuiltinFnName(writer, ty);
                                try writer.writeByte('(');
                                try dg.renderIntCast(writer, ty, cast_context, field_ty, .FunctionArgument);
                                try writer.writeAll(", ");
                                try dg.renderValue(writer, bit_offset_ty, bit_offset_val, .FunctionArgument);
                                try writer.writeByte(')');
                            } else {
                                try dg.renderIntCast(writer, ty, cast_context, field_ty, .FunctionArgument);
                            }

                            if (needs_closing_paren) try writer.writeByte(')');
                            if (eff_index != eff_num_fields - 1) try writer.writeAll(", ");

                            bit_offset_val_pl.data += field_ty.bitSize(target);
                            needs_closing_paren = true;
                            eff_index += 1;
                        }
                    } else {
                        try writer.writeByte('(');
                        // a << a_off | b << b_off | c << c_off
                        var empty = true;
                        for (field_vals, 0..) |field_val, index| {
                            const field_ty = ty.structFieldType(index);
                            if (!field_ty.hasRuntimeBitsIgnoreComptime()) continue;

                            if (!empty) try writer.writeAll(" | ");
                            try writer.writeByte('(');
                            try dg.renderType(writer, ty);
                            try writer.writeByte(')');

                            if (bit_offset_val_pl.data != 0) {
                                try dg.renderValue(writer, field_ty, field_val, .Other);
                                try writer.writeAll(" << ");
                                try dg.renderValue(writer, bit_offset_ty, bit_offset_val, .FunctionArgument);
                            } else {
                                try dg.renderValue(writer, field_ty, field_val, .Other);
                            }

                            bit_offset_val_pl.data += field_ty.bitSize(target);
                            empty = false;
                        }
                        try writer.writeByte(')');
                    }
                },
            },
            .Union => {
                const union_obj = val.castTag(.@"union").?.data;

                if (!location.isInitializer()) {
                    try writer.writeByte('(');
                    try dg.renderType(writer, ty);
                    try writer.writeByte(')');
                }

                const index = ty.unionTagFieldIndex(union_obj.tag, dg.module).?;
                const field_ty = ty.unionFields().values()[index].ty;
                const field_name = ty.unionFields().keys()[index];
                if (ty.containerLayout() == .Packed) {
                    if (field_ty.hasRuntimeBits()) {
                        if (field_ty.isPtrAtRuntime()) {
                            try writer.writeByte('(');
                            try dg.renderType(writer, ty);
                            try writer.writeByte(')');
                        } else if (field_ty.zigTypeTag() == .Float) {
                            try writer.writeByte('(');
                            try dg.renderType(writer, ty);
                            try writer.writeByte(')');
                        }
                        try dg.renderValue(writer, field_ty, union_obj.val, initializer_type);
                    } else {
                        try writer.writeAll("0");
                    }
                    return;
                }

                var has_payload_init = false;
                try writer.writeByte('{');
                if (ty.unionTagTypeSafety()) |tag_ty| {
                    const layout = ty.unionGetLayout(target);
                    if (layout.tag_size != 0) {
                        try writer.writeAll(".tag = ");
                        try dg.renderValue(writer, tag_ty, union_obj.tag, initializer_type);
                        try writer.writeAll(", ");
                    }
                    if (!ty.unionHasAllZeroBitFieldTypes()) {
                        try writer.writeAll(".payload = {");
                        has_payload_init = true;
                    }
                }

                var it = ty.unionFields().iterator();
                if (field_ty.hasRuntimeBits()) {
                    try writer.print(".{ } = ", .{fmtIdent(field_name)});
                    try dg.renderValue(writer, field_ty, union_obj.val, initializer_type);
                } else while (it.next()) |field| {
                    if (!field.value_ptr.ty.hasRuntimeBits()) continue;
                    try writer.print(".{ } = ", .{fmtIdent(field.key_ptr.*)});
                    try dg.renderValue(writer, field.value_ptr.ty, Value.undef, initializer_type);
                    break;
                }
                if (has_payload_init) try writer.writeByte('}');
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
            .Opaque => unreachable,

            .Frame,
            .AnyFrame,
            => |tag| return dg.fail("TODO: C backend: implement value of type {s}", .{
                @tagName(tag),
            }),
        }
    }

    fn renderFunctionSignature(
        dg: *DeclGen,
        w: anytype,
        fn_decl_index: Decl.Index,
        kind: CType.Kind,
        name: union(enum) {
            export_index: u32,
            string: []const u8,
        },
    ) !void {
        const store = &dg.ctypes.set;
        const module = dg.module;

        const fn_decl = module.declPtr(fn_decl_index);
        const fn_cty_idx = try dg.typeToIndex(fn_decl.ty, kind);

        const fn_info = fn_decl.ty.fnInfo();
        if (fn_info.cc == .Naked) {
            switch (kind) {
                .forward => try w.writeAll("zig_naked_decl "),
                .complete => try w.writeAll("zig_naked "),
                else => unreachable,
            }
        }
        if (fn_decl.val.castTag(.function)) |func_payload|
            if (func_payload.data.is_cold) try w.writeAll("zig_cold ");
        if (fn_info.return_type.tag() == .noreturn) try w.writeAll("zig_noreturn ");

        const trailing = try renderTypePrefix(
            dg.decl_index,
            store.*,
            module,
            w,
            fn_cty_idx,
            .suffix,
            .{},
        );
        try w.print("{}", .{trailing});

        if (toCallingConvention(fn_info.cc)) |call_conv| {
            try w.print("zig_callconv({s}) ", .{call_conv});
        }

        switch (kind) {
            .forward => {},
            .complete => if (fn_info.alignment > 0)
                try w.print(" zig_align_fn({})", .{fn_info.alignment}),
            else => unreachable,
        }

        switch (name) {
            .export_index => |export_index| try dg.renderDeclName(w, fn_decl_index, export_index),
            .string => |string| try w.writeAll(string),
        }

        try renderTypeSuffix(
            dg.decl_index,
            store.*,
            module,
            w,
            fn_cty_idx,
            .suffix,
            CQualifiers.init(.{ .@"const" = switch (kind) {
                .forward => false,
                .complete => true,
                else => unreachable,
            } }),
        );

        switch (kind) {
            .forward => if (fn_info.alignment > 0)
                try w.print(" zig_align_fn({})", .{fn_info.alignment}),
            .complete => {},
            else => unreachable,
        }
    }

    fn indexToCType(dg: *DeclGen, idx: CType.Index) CType {
        return dg.ctypes.indexToCType(idx);
    }

    fn typeToIndex(dg: *DeclGen, ty: Type, kind: CType.Kind) !CType.Index {
        return dg.ctypes.typeToIndex(dg.gpa, ty, dg.module, kind);
    }

    fn typeToCType(dg: *DeclGen, ty: Type, kind: CType.Kind) !CType {
        return dg.ctypes.typeToCType(dg.gpa, ty, dg.module, kind);
    }

    /// Renders a type as a single identifier, generating intermediate typedefs
    /// if necessary.
    ///
    /// This is guaranteed to be valid in both typedefs and declarations/definitions.
    ///
    /// There are three type formats in total that we support rendering:
    ///   | Function            | Example 1 (*u8) | Example 2 ([10]*u8) |
    ///   |---------------------|-----------------|---------------------|
    ///   | `renderTypeAndName` | "uint8_t *name" | "uint8_t *name[10]" |
    ///   | `renderType`        | "uint8_t *"     | "uint8_t *[10]"     |
    ///
    fn renderType(dg: *DeclGen, w: anytype, t: Type) error{ OutOfMemory, AnalysisFail }!void {
        const store = &dg.ctypes.set;
        const module = dg.module;
        const idx = try dg.typeToIndex(t, .complete);
        _ = try renderTypePrefix(dg.decl_index, store.*, module, w, idx, .suffix, .{});
        try renderTypeSuffix(dg.decl_index, store.*, module, w, idx, .suffix, .{});
    }

    const IntCastContext = union(enum) {
        c_value: struct {
            f: *Function,
            value: CValue,
        },
        value: struct {
            value: Value,
        },

        pub fn writeValue(self: *const IntCastContext, dg: *DeclGen, w: anytype, value_ty: Type, location: ValueRenderLocation) !void {
            switch (self.*) {
                .c_value => |v| {
                    try v.f.writeCValue(w, v.value, location);
                },
                .value => |v| {
                    try dg.renderValue(w, value_ty, v.value, location);
                },
            }
        }
    };

    /// Renders a cast to an int type, from either an int or a pointer.
    ///
    /// Some platforms don't have 128 bit integers, so we need to use
    /// the zig_make_ and zig_lo_ macros in those cases.
    ///
    ///   | Dest type bits   | Src type         | Result
    ///   |------------------|------------------|---------------------------|
    ///   | < 64 bit integer | pointer          | (zig_<dest_ty>)(zig_<u|i>size)src
    ///   | < 64 bit integer | < 64 bit integer | (zig_<dest_ty>)src
    ///   | < 64 bit integer | > 64 bit integer | zig_lo(src)
    ///   | > 64 bit integer | pointer          | zig_make_<dest_ty>(0, (zig_<u|i>size)src)
    ///   | > 64 bit integer | < 64 bit integer | zig_make_<dest_ty>(0, src)
    ///   | > 64 bit integer | > 64 bit integer | zig_make_<dest_ty>(zig_hi_<src_ty>(src), zig_lo_<src_ty>(src))
    fn renderIntCast(dg: *DeclGen, w: anytype, dest_ty: Type, context: IntCastContext, src_ty: Type, location: ValueRenderLocation) !void {
        const target = dg.module.getTarget();
        const dest_bits = dest_ty.bitSize(target);
        const dest_int_info = dest_ty.intInfo(target);

        const src_is_ptr = src_ty.isPtrAtRuntime();
        const src_eff_ty: Type = if (src_is_ptr) switch (dest_int_info.signedness) {
            .unsigned => Type.usize,
            .signed => Type.isize,
        } else src_ty;

        const src_bits = src_eff_ty.bitSize(target);
        const src_int_info = if (src_eff_ty.isAbiInt()) src_eff_ty.intInfo(target) else null;
        if (dest_bits <= 64 and src_bits <= 64) {
            const needs_cast = src_int_info == null or
                (toCIntBits(dest_int_info.bits) != toCIntBits(src_int_info.?.bits) or
                dest_int_info.signedness != src_int_info.?.signedness);

            if (needs_cast) {
                try w.writeByte('(');
                try dg.renderType(w, dest_ty);
                try w.writeByte(')');
            }
            if (src_is_ptr) {
                try w.writeByte('(');
                try dg.renderType(w, src_eff_ty);
                try w.writeByte(')');
            }
            try context.writeValue(dg, w, src_ty, location);
        } else if (dest_bits <= 64 and src_bits > 64) {
            assert(!src_is_ptr);
            if (dest_bits < 64) {
                try w.writeByte('(');
                try dg.renderType(w, dest_ty);
                try w.writeByte(')');
            }
            try w.writeAll("zig_lo_");
            try dg.renderTypeForBuiltinFnName(w, src_eff_ty);
            try w.writeByte('(');
            try context.writeValue(dg, w, src_ty, .FunctionArgument);
            try w.writeByte(')');
        } else if (dest_bits > 64 and src_bits <= 64) {
            try w.writeAll("zig_make_");
            try dg.renderTypeForBuiltinFnName(w, dest_ty);
            try w.writeAll("(0, "); // TODO: Should the 0 go through fmtIntLiteral?
            if (src_is_ptr) {
                try w.writeByte('(');
                try dg.renderType(w, src_eff_ty);
                try w.writeByte(')');
            }
            try context.writeValue(dg, w, src_ty, .FunctionArgument);
            try w.writeByte(')');
        } else {
            assert(!src_is_ptr);
            try w.writeAll("zig_make_");
            try dg.renderTypeForBuiltinFnName(w, dest_ty);
            try w.writeAll("(zig_hi_");
            try dg.renderTypeForBuiltinFnName(w, src_eff_ty);
            try w.writeByte('(');
            try context.writeValue(dg, w, src_ty, .FunctionArgument);
            try w.writeAll("), zig_lo_");
            try dg.renderTypeForBuiltinFnName(w, src_eff_ty);
            try w.writeByte('(');
            try context.writeValue(dg, w, src_ty, .FunctionArgument);
            try w.writeAll("))");
        }
    }

    /// Renders a type and name in field declaration/definition format.
    ///
    /// There are three type formats in total that we support rendering:
    ///   | Function            | Example 1 (*u8) | Example 2 ([10]*u8) |
    ///   |---------------------|-----------------|---------------------|
    ///   | `renderTypeAndName` | "uint8_t *name" | "uint8_t *name[10]" |
    ///   | `renderType`        | "uint8_t *"     | "uint8_t *[10]"     |
    ///
    fn renderTypeAndName(
        dg: *DeclGen,
        w: anytype,
        ty: Type,
        name: CValue,
        qualifiers: CQualifiers,
        alignment: u32,
        kind: CType.Kind,
    ) error{ OutOfMemory, AnalysisFail }!void {
        const target = dg.module.getTarget();
        const alignas = CType.AlignAs.init(alignment, ty.abiAlignment(target));
        try dg.renderCTypeAndName(w, try dg.typeToIndex(ty, kind), name, qualifiers, alignas);
    }

    fn renderCTypeAndName(
        dg: *DeclGen,
        w: anytype,
        cty_idx: CType.Index,
        name: CValue,
        qualifiers: CQualifiers,
        alignas: CType.AlignAs,
    ) error{ OutOfMemory, AnalysisFail }!void {
        const store = &dg.ctypes.set;
        const module = dg.module;

        switch (std.math.order(alignas.@"align", alignas.abi)) {
            .lt => try w.print("zig_under_align({}) ", .{alignas.getAlign()}),
            .eq => {},
            .gt => try w.print("zig_align({}) ", .{alignas.getAlign()}),
        }

        const trailing =
            try renderTypePrefix(dg.decl_index, store.*, module, w, cty_idx, .suffix, qualifiers);
        try w.print("{}", .{trailing});
        try dg.writeCValue(w, name);
        try renderTypeSuffix(dg.decl_index, store.*, module, w, cty_idx, .suffix, .{});
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
            .local, .new_local => |i| return w.print("t{d}", .{i}),
            .local_ref => |i| return w.print("&t{d}", .{i}),
            .constant => unreachable,
            .arg => |i| return w.print("a{d}", .{i}),
            .arg_array => |i| return dg.writeCValueMember(w, .{ .arg = i }, .{ .identifier = "array" }),
            .field => |i| return w.print("f{d}", .{i}),
            .decl => |decl| return dg.renderDeclName(w, decl, 0),
            .decl_ref => |decl| {
                try w.writeByte('&');
                return dg.renderDeclName(w, decl, 0);
            },
            .undef => |ty| return dg.renderValue(w, ty, Value.undef, .Other),
            .identifier => |ident| return w.print("{ }", .{fmtIdent(ident)}),
            .payload_identifier => |ident| return w.print("{ }.{ }", .{
                fmtIdent("payload"),
                fmtIdent(ident),
            }),
            .bytes => |bytes| return w.writeAll(bytes),
        }
    }

    fn writeCValueDeref(dg: *DeclGen, w: anytype, c_value: CValue) !void {
        switch (c_value) {
            .none => unreachable,
            .local, .new_local => |i| return w.print("(*t{d})", .{i}),
            .local_ref => |i| return w.print("t{d}", .{i}),
            .constant => unreachable,
            .arg => |i| return w.print("(*a{d})", .{i}),
            .arg_array => |i| {
                try w.writeAll("(*");
                try dg.writeCValueMember(w, .{ .arg = i }, .{ .identifier = "array" });
                return w.writeByte(')');
            },
            .field => |i| return w.print("f{d}", .{i}),
            .decl => |decl| {
                try w.writeAll("(*");
                try dg.renderDeclName(w, decl, 0);
                return w.writeByte(')');
            },
            .decl_ref => |decl| return dg.renderDeclName(w, decl, 0),
            .undef => unreachable,
            .identifier => |ident| return w.print("(*{ })", .{fmtIdent(ident)}),
            .payload_identifier => |ident| return w.print("(*{ }.{ })", .{
                fmtIdent("payload"),
                fmtIdent(ident),
            }),
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
            .new_local, .local, .arg, .arg_array, .decl, .identifier, .payload_identifier, .bytes => {
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

    const IdentHasher = std.crypto.auth.siphash.SipHash128(1, 3);
    const ident_hasher_init: IdentHasher = IdentHasher.init(&[_]u8{0} ** IdentHasher.key_length);

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

            // MSVC has a limit of 4095 character token length limit, and fmtIdent can (worst case), expand
            // to 3x the length of its input
            if (name.len > 1365) {
                var hash = ident_hasher_init;
                hash.update(name);
                const ident_hash = hash.finalInt();
                try writer.writeAll("zig_D_");
                return std.fmt.formatIntValue(ident_hash, "x", .{}, writer);
            } else {
                return writer.print("{}", .{fmtIdent(name)});
            }
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
        } else if (ty.isPtrAtRuntime()) {
            try writer.print("p{d}", .{ty.bitSize(target)});
        } else if (ty.zigTypeTag() == .Bool) {
            try writer.print("u8", .{});
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

    fn fmtIntLiteralLoc(
        dg: *DeclGen,
        ty: Type,
        val: Value,
        location: ValueRenderLocation, // TODO: Instead add this as optional arg to fmtIntLiteral
    ) !std.fmt.Formatter(formatIntLiteral) {
        const int_info = ty.intInfo(dg.module.getTarget());
        const c_bits = toCIntBits(int_info.bits);
        if (c_bits == null or c_bits.? > 128)
            return dg.fail("TODO implement integer constants larger than 128 bits", .{});
        return std.fmt.Formatter(formatIntLiteral){ .data = .{ .ty = ty, .val = val, .mod = dg.module, .location = location } };
    }
};

const CTypeFix = enum { prefix, suffix };
const CQualifiers = std.enums.EnumSet(enum { @"const", @"volatile", restrict });
const Const = CQualifiers.init(.{ .@"const" = true });
const RenderCTypeTrailing = enum {
    no_space,
    maybe_space,

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        _: std.fmt.FormatOptions,
        w: anytype,
    ) @TypeOf(w).Error!void {
        if (fmt.len != 0)
            @compileError("invalid format string '" ++ fmt ++ "' for type '" ++
                @typeName(@This()) ++ "'");
        comptime assert(fmt.len == 0);
        switch (self) {
            .no_space => {},
            .maybe_space => try w.writeByte(' '),
        }
    }
};
fn renderTypeName(
    mod: *Module,
    w: anytype,
    idx: CType.Index,
    cty: CType,
    attributes: []const u8,
) !void {
    switch (cty.tag()) {
        else => unreachable,

        .fwd_anon_struct,
        .fwd_anon_union,
        => |tag| try w.print("{s} {s}anon__lazy_{d}", .{
            @tagName(tag)["fwd_anon_".len..],
            attributes,
            idx,
        }),

        .fwd_struct,
        .fwd_union,
        => |tag| {
            const owner_decl = cty.cast(CType.Payload.FwdDecl).?.data;
            try w.print("{s} {s}{}__{d}", .{
                @tagName(tag)["fwd_".len..],
                attributes,
                fmtIdent(mem.span(mod.declPtr(owner_decl).name)),
                @enumToInt(owner_decl),
            });
        },
    }
}
fn renderTypePrefix(
    decl: Decl.OptionalIndex,
    store: CType.Store.Set,
    mod: *Module,
    w: anytype,
    idx: CType.Index,
    parent_fix: CTypeFix,
    qualifiers: CQualifiers,
) @TypeOf(w).Error!RenderCTypeTrailing {
    var trailing = RenderCTypeTrailing.maybe_space;

    const cty = store.indexToCType(idx);
    switch (cty.tag()) {
        .void,
        .char,
        .@"signed char",
        .short,
        .int,
        .long,
        .@"long long",
        ._Bool,
        .@"unsigned char",
        .@"unsigned short",
        .@"unsigned int",
        .@"unsigned long",
        .@"unsigned long long",
        .float,
        .double,
        .@"long double",
        .bool,
        .size_t,
        .ptrdiff_t,
        .uint8_t,
        .int8_t,
        .uint16_t,
        .int16_t,
        .uint32_t,
        .int32_t,
        .uint64_t,
        .int64_t,
        .uintptr_t,
        .intptr_t,
        .zig_u128,
        .zig_i128,
        .zig_f16,
        .zig_f32,
        .zig_f64,
        .zig_f80,
        .zig_f128,
        .zig_c_longdouble,
        => |tag| try w.writeAll(@tagName(tag)),

        .pointer,
        .pointer_const,
        .pointer_volatile,
        .pointer_const_volatile,
        => |tag| {
            const child_idx = cty.cast(CType.Payload.Child).?.data;
            const child_trailing = try renderTypePrefix(
                decl,
                store,
                mod,
                w,
                child_idx,
                .prefix,
                CQualifiers.init(.{ .@"const" = switch (tag) {
                    .pointer, .pointer_volatile => false,
                    .pointer_const, .pointer_const_volatile => true,
                    else => unreachable,
                }, .@"volatile" = switch (tag) {
                    .pointer, .pointer_const => false,
                    .pointer_volatile, .pointer_const_volatile => true,
                    else => unreachable,
                } }),
            );
            try w.print("{}*", .{child_trailing});
            trailing = .no_space;
        },

        .array,
        .vector,
        => {
            const child_idx = cty.cast(CType.Payload.Sequence).?.data.elem_type;
            const child_trailing = try renderTypePrefix(
                decl,
                store,
                mod,
                w,
                child_idx,
                .suffix,
                qualifiers,
            );
            switch (parent_fix) {
                .prefix => {
                    try w.print("{}(", .{child_trailing});
                    return .no_space;
                },
                .suffix => return child_trailing,
            }
        },

        .fwd_anon_struct,
        .fwd_anon_union,
        => if (decl.unwrap()) |decl_index|
            try w.print("anon__{d}_{d}", .{ @enumToInt(decl_index), idx })
        else
            try renderTypeName(mod, w, idx, cty, ""),

        .fwd_struct,
        .fwd_union,
        => try renderTypeName(mod, w, idx, cty, ""),

        .unnamed_struct,
        .unnamed_union,
        .packed_unnamed_struct,
        .packed_unnamed_union,
        => |tag| {
            try w.print("{s} {s}", .{
                @tagName(tag)["unnamed_".len..],
                if (cty.isPacked()) "zig_packed(" else "",
            });
            try renderAggregateFields(mod, w, store, cty, 1);
            if (cty.isPacked()) try w.writeByte(')');
        },

        .anon_struct,
        .anon_union,
        .@"struct",
        .@"union",
        .packed_struct,
        .packed_union,
        => return renderTypePrefix(
            decl,
            store,
            mod,
            w,
            cty.cast(CType.Payload.Aggregate).?.data.fwd_decl,
            parent_fix,
            qualifiers,
        ),

        .function,
        .varargs_function,
        => {
            const child_trailing = try renderTypePrefix(
                decl,
                store,
                mod,
                w,
                cty.cast(CType.Payload.Function).?.data.return_type,
                .suffix,
                .{},
            );
            switch (parent_fix) {
                .prefix => {
                    try w.print("{}(", .{child_trailing});
                    return .no_space;
                },
                .suffix => return child_trailing,
            }
        },
    }

    var qualifier_it = qualifiers.iterator();
    while (qualifier_it.next()) |qualifier| {
        try w.print("{}{s}", .{ trailing, @tagName(qualifier) });
        trailing = .maybe_space;
    }

    return trailing;
}
fn renderTypeSuffix(
    decl: Decl.OptionalIndex,
    store: CType.Store.Set,
    mod: *Module,
    w: anytype,
    idx: CType.Index,
    parent_fix: CTypeFix,
    qualifiers: CQualifiers,
) @TypeOf(w).Error!void {
    const cty = store.indexToCType(idx);
    switch (cty.tag()) {
        .void,
        .char,
        .@"signed char",
        .short,
        .int,
        .long,
        .@"long long",
        ._Bool,
        .@"unsigned char",
        .@"unsigned short",
        .@"unsigned int",
        .@"unsigned long",
        .@"unsigned long long",
        .float,
        .double,
        .@"long double",
        .bool,
        .size_t,
        .ptrdiff_t,
        .uint8_t,
        .int8_t,
        .uint16_t,
        .int16_t,
        .uint32_t,
        .int32_t,
        .uint64_t,
        .int64_t,
        .uintptr_t,
        .intptr_t,
        .zig_u128,
        .zig_i128,
        .zig_f16,
        .zig_f32,
        .zig_f64,
        .zig_f80,
        .zig_f128,
        .zig_c_longdouble,
        => {},

        .pointer,
        .pointer_const,
        .pointer_volatile,
        .pointer_const_volatile,
        => try renderTypeSuffix(
            decl,
            store,
            mod,
            w,
            cty.cast(CType.Payload.Child).?.data,
            .prefix,
            .{},
        ),

        .array,
        .vector,
        => {
            switch (parent_fix) {
                .prefix => try w.writeByte(')'),
                .suffix => {},
            }

            try w.print("[{}]", .{cty.cast(CType.Payload.Sequence).?.data.len});
            try renderTypeSuffix(
                decl,
                store,
                mod,
                w,
                cty.cast(CType.Payload.Sequence).?.data.elem_type,
                .suffix,
                .{},
            );
        },

        .fwd_anon_struct,
        .fwd_anon_union,
        .fwd_struct,
        .fwd_union,
        .unnamed_struct,
        .unnamed_union,
        .packed_unnamed_struct,
        .packed_unnamed_union,
        .anon_struct,
        .anon_union,
        .@"struct",
        .@"union",
        .packed_struct,
        .packed_union,
        => {},

        .function,
        .varargs_function,
        => |tag| {
            switch (parent_fix) {
                .prefix => try w.writeByte(')'),
                .suffix => {},
            }

            const data = cty.cast(CType.Payload.Function).?.data;

            try w.writeByte('(');
            var need_comma = false;
            for (data.param_types, 0..) |param_type, param_i| {
                if (need_comma) try w.writeAll(", ");
                need_comma = true;
                const trailing =
                    try renderTypePrefix(decl, store, mod, w, param_type, .suffix, qualifiers);
                if (qualifiers.contains(.@"const")) try w.print("{}a{d}", .{ trailing, param_i });
                try renderTypeSuffix(decl, store, mod, w, param_type, .suffix, .{});
            }
            switch (tag) {
                .function => {},
                .varargs_function => {
                    if (need_comma) try w.writeAll(", ");
                    need_comma = true;
                    try w.writeAll("...");
                },
                else => unreachable,
            }
            if (!need_comma) try w.writeAll("void");
            try w.writeByte(')');

            try renderTypeSuffix(decl, store, mod, w, data.return_type, .suffix, .{});
        },
    }
}
fn renderAggregateFields(
    mod: *Module,
    writer: anytype,
    store: CType.Store.Set,
    cty: CType,
    indent: usize,
) !void {
    try writer.writeAll("{\n");
    const fields = cty.fields();
    for (fields) |field| {
        try writer.writeByteNTimes(' ', indent + 1);
        switch (std.math.order(field.alignas.@"align", field.alignas.abi)) {
            .lt => try writer.print("zig_under_align({}) ", .{field.alignas.getAlign()}),
            .eq => {},
            .gt => try writer.print("zig_align({}) ", .{field.alignas.getAlign()}),
        }
        const trailing = try renderTypePrefix(.none, store, mod, writer, field.type, .suffix, .{});
        try writer.print("{}{ }", .{ trailing, fmtIdent(mem.span(field.name)) });
        try renderTypeSuffix(.none, store, mod, writer, field.type, .suffix, .{});
        try writer.writeAll(";\n");
    }
    try writer.writeByteNTimes(' ', indent);
    try writer.writeByte('}');
}

pub fn genTypeDecl(
    mod: *Module,
    writer: anytype,
    global_store: CType.Store.Set,
    global_idx: CType.Index,
    decl: Decl.OptionalIndex,
    decl_store: CType.Store.Set,
    decl_idx: CType.Index,
    found_existing: bool,
) !void {
    const global_cty = global_store.indexToCType(global_idx);
    switch (global_cty.tag()) {
        .fwd_anon_struct => if (decl != .none) {
            try writer.writeAll("typedef ");
            _ = try renderTypePrefix(.none, global_store, mod, writer, global_idx, .suffix, .{});
            try writer.writeByte(' ');
            _ = try renderTypePrefix(decl, decl_store, mod, writer, decl_idx, .suffix, .{});
            try writer.writeAll(";\n");
        },

        .fwd_struct,
        .fwd_union,
        .anon_struct,
        .anon_union,
        .@"struct",
        .@"union",
        .packed_struct,
        .packed_union,
        => |tag| if (!found_existing) {
            switch (tag) {
                .fwd_struct,
                .fwd_union,
                => {
                    const owner_decl = global_cty.cast(CType.Payload.FwdDecl).?.data;
                    _ = try renderTypePrefix(.none, global_store, mod, writer, global_idx, .suffix, .{});
                    try writer.writeAll("; // ");
                    try mod.declPtr(owner_decl).renderFullyQualifiedName(mod, writer);
                    try writer.writeByte('\n');
                },

                .anon_struct,
                .anon_union,
                .@"struct",
                .@"union",
                .packed_struct,
                .packed_union,
                => {
                    const fwd_idx = global_cty.cast(CType.Payload.Aggregate).?.data.fwd_decl;
                    try renderTypeName(
                        mod,
                        writer,
                        fwd_idx,
                        global_store.indexToCType(fwd_idx),
                        if (global_cty.isPacked()) "zig_packed(" else "",
                    );
                    try writer.writeByte(' ');
                    try renderAggregateFields(mod, writer, global_store, global_cty, 0);
                    if (global_cty.isPacked()) try writer.writeByte(')');
                    try writer.writeAll(";\n");
                },

                else => unreachable,
            }
        },

        else => {},
    }
}

pub fn genGlobalAsm(mod: *Module, writer: anytype) !void {
    var it = mod.global_assembly.valueIterator();
    while (it.next()) |asm_source| try writer.print("__asm({s});\n", .{fmtStringLiteral(asm_source.*, null)});
}

pub fn genErrDecls(o: *Object) !void {
    const writer = o.writer();

    try writer.writeAll("enum {\n");
    o.indent_writer.pushIndent();
    var max_name_len: usize = 0;
    for (o.dg.module.error_name_list.items, 0..) |name, value| {
        max_name_len = std.math.max(name.len, max_name_len);
        var err_pl = Value.Payload.Error{ .data = .{ .name = name } };
        try o.dg.renderValue(writer, Type.anyerror, Value.initPayload(&err_pl.base), .Other);
        try writer.print(" = {d}u,\n", .{value});
    }
    o.indent_writer.popIndent();
    try writer.writeAll("};\n");

    const array_identifier = "zig_errorName";
    const name_prefix = array_identifier ++ "_";
    const name_buf = try o.dg.gpa.alloc(u8, name_prefix.len + max_name_len);
    defer o.dg.gpa.free(name_buf);

    std.mem.copy(u8, name_buf, name_prefix);
    for (o.dg.module.error_name_list.items) |name| {
        std.mem.copy(u8, name_buf[name_prefix.len..], name);
        const identifier = name_buf[0 .. name_prefix.len + name.len];

        var name_ty_pl = Type.Payload.Len{ .base = .{ .tag = .array_u8_sentinel_0 }, .data = name.len };
        const name_ty = Type.initPayload(&name_ty_pl.base);

        var name_pl = Value.Payload.Bytes{ .base = .{ .tag = .bytes }, .data = name };
        const name_val = Value.initPayload(&name_pl.base);

        try writer.writeAll("static ");
        try o.dg.renderTypeAndName(writer, name_ty, .{ .identifier = identifier }, Const, 0, .complete);
        try writer.writeAll(" = ");
        try o.dg.renderValue(writer, name_ty, name_val, .StaticInitializer);
        try writer.writeAll(";\n");
    }

    var name_array_ty_pl = Type.Payload.Array{ .base = .{ .tag = .array }, .data = .{
        .len = o.dg.module.error_name_list.items.len,
        .elem_type = Type.initTag(.const_slice_u8_sentinel_0),
    } };
    const name_array_ty = Type.initPayload(&name_array_ty_pl.base);

    try writer.writeAll("static ");
    try o.dg.renderTypeAndName(writer, name_array_ty, .{ .identifier = array_identifier }, Const, 0, .complete);
    try writer.writeAll(" = {");
    for (o.dg.module.error_name_list.items, 0..) |name, value| {
        if (value != 0) try writer.writeByte(',');

        var len_pl = Value.Payload.U64{ .base = .{ .tag = .int_u64 }, .data = name.len };
        const len_val = Value.initPayload(&len_pl.base);

        try writer.print("{{" ++ name_prefix ++ "{}, {}}}", .{
            fmtIdent(name), try o.dg.fmtIntLiteral(Type.usize, len_val),
        });
    }
    try writer.writeAll("};\n");
}

fn genExports(o: *Object) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const fwd_decl_writer = o.dg.fwd_decl.writer();
    if (o.dg.module.decl_exports.get(o.dg.decl_index.unwrap().?)) |exports| {
        for (exports.items[1..], 1..) |@"export", i| {
            try fwd_decl_writer.writeAll("zig_export(");
            try o.dg.renderFunctionSignature(fwd_decl_writer, o.dg.decl_index.unwrap().?, .forward, .{ .export_index = @intCast(u32, i) });
            try fwd_decl_writer.print(", {s}, {s});\n", .{
                fmtStringLiteral(exports.items[0].options.name, null),
                fmtStringLiteral(@"export".options.name, null),
            });
        }
    }
}

pub fn genLazyFn(o: *Object, lazy_fn: LazyFnMap.Entry) !void {
    const w = o.writer();
    const key = lazy_fn.key_ptr.*;
    const val = lazy_fn.value_ptr;
    const fn_name = val.fn_name;
    switch (key) {
        .tag_name => {
            const enum_ty = val.data.tag_name;

            const name_slice_ty = Type.initTag(.const_slice_u8_sentinel_0);

            try w.writeAll("static ");
            try o.dg.renderType(w, name_slice_ty);
            try w.writeByte(' ');
            try w.writeAll(fn_name);
            try w.writeByte('(');
            try o.dg.renderTypeAndName(w, enum_ty, .{ .identifier = "tag" }, Const, 0, .complete);
            try w.writeAll(") {\n switch (tag) {\n");
            for (enum_ty.enumFields().keys(), 0..) |name, index| {
                var tag_pl: Value.Payload.U32 = .{
                    .base = .{ .tag = .enum_field_index },
                    .data = @intCast(u32, index),
                };
                const tag_val = Value.initPayload(&tag_pl.base);

                var int_pl: Value.Payload.U64 = undefined;
                const int_val = tag_val.enumToInt(enum_ty, &int_pl);

                var name_ty_pl = Type.Payload.Len{ .base = .{ .tag = .array_u8_sentinel_0 }, .data = name.len };
                const name_ty = Type.initPayload(&name_ty_pl.base);

                var name_pl = Value.Payload.Bytes{ .base = .{ .tag = .bytes }, .data = name };
                const name_val = Value.initPayload(&name_pl.base);

                var len_pl = Value.Payload.U64{ .base = .{ .tag = .int_u64 }, .data = name.len };
                const len_val = Value.initPayload(&len_pl.base);

                try w.print("  case {}: {{\n   static ", .{try o.dg.fmtIntLiteral(enum_ty, int_val)});
                try o.dg.renderTypeAndName(w, name_ty, .{ .identifier = "name" }, Const, 0, .complete);
                try w.writeAll(" = ");
                try o.dg.renderValue(w, name_ty, name_val, .Initializer);
                try w.writeAll(";\n   return (");
                try o.dg.renderType(w, name_slice_ty);
                try w.print("){{{}, {}}};\n", .{
                    fmtIdent("name"), try o.dg.fmtIntLiteral(Type.usize, len_val),
                });

                try w.writeAll("  }\n");
            }
            try w.writeAll(" }\n while (");
            try o.dg.renderValue(w, Type.bool, Value.true, .Other);
            try w.writeAll(") ");
            _ = try airBreakpoint(w);
            try w.writeAll("}\n");
        },
        .never_tail, .never_inline => |fn_decl_index| {
            const fn_decl = o.dg.module.declPtr(fn_decl_index);
            const fn_cty = try o.dg.typeToCType(fn_decl.ty, .complete);
            const fn_info = fn_cty.cast(CType.Payload.Function).?.data;

            const fwd_decl_writer = o.dg.fwd_decl.writer();
            try fwd_decl_writer.print("static zig_{s} ", .{@tagName(key)});
            try o.dg.renderFunctionSignature(fwd_decl_writer, fn_decl_index, .forward, .{ .string = fn_name });
            try fwd_decl_writer.writeAll(";\n");

            try w.print("static zig_{s} ", .{@tagName(key)});
            try o.dg.renderFunctionSignature(w, fn_decl_index, .complete, .{ .string = fn_name });
            try w.writeAll(" {\n return ");
            try o.dg.renderDeclName(w, fn_decl_index, 0);
            try w.writeByte('(');
            for (0..fn_info.param_types.len) |arg| {
                if (arg > 0) try w.writeAll(", ");
                try o.dg.writeCValue(w, .{ .arg = arg });
            }
            try w.writeAll(");\n}\n");
        },
    }
}

pub fn genFunc(f: *Function) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const o = &f.object;
    const gpa = o.dg.gpa;
    const decl_index = o.dg.decl_index.unwrap().?;
    const tv: TypedValue = .{
        .ty = o.dg.decl.?.ty,
        .val = o.dg.decl.?.val,
    };

    o.code_header = std.ArrayList(u8).init(gpa);
    defer o.code_header.deinit();

    const is_global = o.dg.declIsGlobal(tv);
    const fwd_decl_writer = o.dg.fwd_decl.writer();
    try fwd_decl_writer.writeAll(if (is_global) "zig_extern " else "static ");
    try o.dg.renderFunctionSignature(fwd_decl_writer, decl_index, .forward, .{ .export_index = 0 });
    try fwd_decl_writer.writeAll(";\n");
    try genExports(o);

    try o.indent_writer.insertNewline();
    if (!is_global) try o.writer().writeAll("static ");
    try o.dg.renderFunctionSignature(o.writer(), decl_index, .complete, .{ .export_index = 0 });
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
    for (f.allocs.keys(), f.allocs.values()) |local_index, value| {
        if (value) continue; // static
        const local = f.locals.items[local_index];
        log.debug("inserting local {d} into free_locals", .{local_index});
        const gop = try free_locals.getOrPut(gpa, local.getType());
        if (!gop.found_existing) gop.value_ptr.* = .{};
        try gop.value_ptr.putNoClobber(gpa, local_index, {});
    }

    const SortContext = struct {
        keys: []const LocalType,

        pub fn lessThan(ctx: @This(), lhs_index: usize, rhs_index: usize) bool {
            const lhs_ty = ctx.keys[lhs_index];
            const rhs_ty = ctx.keys[rhs_index];
            return lhs_ty.alignas.getAlign() > rhs_ty.alignas.getAlign();
        }
    };
    free_locals.sort(SortContext{ .keys = free_locals.keys() });

    const w = o.code_header.writer();
    for (free_locals.values()) |list| {
        for (list.keys()) |local_index| {
            const local = f.locals.items[local_index];
            try o.dg.renderCTypeAndName(w, local.cty_idx, .{ .local = local_index }, .{}, local.alignas);
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

    const decl = o.dg.decl.?;
    const decl_c_value = .{ .decl = o.dg.decl_index.unwrap().? };
    const tv: TypedValue = .{ .ty = decl.ty, .val = decl.val };

    if (!tv.ty.isFnOrHasRuntimeBitsIgnoreComptime()) return;
    if (tv.val.tag() == .extern_fn) {
        const fwd_decl_writer = o.dg.fwd_decl.writer();
        try fwd_decl_writer.writeAll("zig_extern ");
        try o.dg.renderFunctionSignature(fwd_decl_writer, decl_c_value.decl, .forward, .{ .export_index = 0 });
        try fwd_decl_writer.writeAll(";\n");
        try genExports(o);
    } else if (tv.val.castTag(.variable)) |var_payload| {
        const variable: *Module.Var = var_payload.data;

        const is_global = o.dg.declIsGlobal(tv) or variable.is_extern;
        const fwd_decl_writer = o.dg.fwd_decl.writer();

        try fwd_decl_writer.writeAll(if (is_global) "zig_extern " else "static ");
        if (variable.is_threadlocal) try fwd_decl_writer.writeAll("zig_threadlocal ");
        try o.dg.renderTypeAndName(fwd_decl_writer, decl.ty, decl_c_value, .{}, decl.@"align", .complete);
        try fwd_decl_writer.writeAll(";\n");
        try genExports(o);

        if (variable.is_extern) return;

        const w = o.writer();
        if (!is_global) try w.writeAll("static ");
        if (variable.is_threadlocal) try w.writeAll("zig_threadlocal ");
        if (decl.@"linksection") |section| try w.print("zig_linksection(\"{s}\", ", .{section});
        try o.dg.renderTypeAndName(w, tv.ty, decl_c_value, .{}, decl.@"align", .complete);
        if (decl.@"linksection" != null) try w.writeAll(", read, write)");
        try w.writeAll(" = ");
        try o.dg.renderValue(w, tv.ty, variable.init, .StaticInitializer);
        try w.writeByte(';');
        try o.indent_writer.insertNewline();
    } else {
        const is_global = o.dg.module.decl_exports.contains(decl_c_value.decl);
        const fwd_decl_writer = o.dg.fwd_decl.writer();

        try fwd_decl_writer.writeAll(if (is_global) "zig_extern " else "static ");
        try o.dg.renderTypeAndName(fwd_decl_writer, tv.ty, decl_c_value, Const, decl.@"align", .complete);
        try fwd_decl_writer.writeAll(";\n");

        const w = o.writer();
        if (!is_global) try w.writeAll("static ");
        if (decl.@"linksection") |section| try w.print("zig_linksection(\"{s}\", ", .{section});
        try o.dg.renderTypeAndName(w, tv.ty, decl_c_value, Const, decl.@"align", .complete);
        if (decl.@"linksection" != null) try w.writeAll(", read)");
        try w.writeAll(" = ");
        try o.dg.renderValue(w, tv.ty, tv.val, .StaticInitializer);
        try w.writeAll(";\n");
    }
}

pub fn genHeader(dg: *DeclGen) error{ AnalysisFail, OutOfMemory }!void {
    const tracy = trace(@src());
    defer tracy.end();

    const tv: TypedValue = .{
        .ty = dg.decl.?.ty,
        .val = dg.decl.?.val,
    };
    const writer = dg.fwd_decl.writer();

    switch (tv.ty.zigTypeTag()) {
        .Fn => {
            const is_global = dg.declIsGlobal(tv);
            if (is_global) {
                try writer.writeAll("zig_extern ");
                try dg.renderFunctionSignature(writer, dg.decl_index.unwrap().?, .complete, .{ .export_index = 0 });
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
            .arg      => try airArg(f, inst),

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
            => .none,

            .call              => try airCall(f, inst, .auto),
            .call_always_tail  => .none,
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
            .vector_store_elem => return f.fail("TODO: C backend: implement vector_store_elem", .{}),

            .c_va_start => try airCVaStart(f, inst),
            .c_va_arg => try airCVaArg(f, inst),
            .c_va_end => try airCVaEnd(f, inst),
            .c_va_copy => try airCVaCopy(f, inst),
            // zig fmt: on
        };
        if (result_value == .new_local) {
            log.debug("map %{d} to t{d}", .{ inst, result_value.new_local });
        }
        try f.value_map.putNoClobber(Air.indexToRef(inst), switch (result_value) {
            .none => continue,
            .new_local => |i| .{ .local = i },
            else => result_value,
        });
    }
}

fn airSliceField(f: *Function, inst: Air.Inst.Index, is_ptr: bool, field_name: []const u8) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ty_op.operand});
        return .none;
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
        return .none;
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
        try f.renderType(writer, inst_ty);
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
        return .none;
    }

    const inst_ty = f.air.typeOfIndex(inst);
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
    try writer.writeAll(" = (");
    try f.renderType(writer, inst_ty);
    try writer.writeAll(")&(");
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
        return .none;
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
        try f.renderType(writer, inst_ty);
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
        return .none;
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
        return .none;
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
        try f.renderType(writer, inst_ty);
        try writer.writeAll("))");
    }
    try writer.writeAll(";\n");
    return local;
}

fn airAlloc(f: *Function, inst: Air.Inst.Index) !CValue {
    const inst_ty = f.air.typeOfIndex(inst);

    const elem_type = inst_ty.elemType();
    if (!elem_type.isFnOrHasRuntimeBitsIgnoreComptime()) {
        return .{ .undef = inst_ty };
    }

    const target = f.object.dg.module.getTarget();
    const local = try f.allocAlignedLocal(
        elem_type,
        CQualifiers.init(.{ .@"const" = inst_ty.isConstPtr() }),
        inst_ty.ptrAlignment(target),
    );
    log.debug("%{d}: allocated unfreeable t{d}", .{ inst, local.new_local });
    const gpa = f.object.dg.module.gpa;
    try f.allocs.put(gpa, local.new_local, false);
    return .{ .local_ref = local.new_local };
}

fn airRetPtr(f: *Function, inst: Air.Inst.Index) !CValue {
    const inst_ty = f.air.typeOfIndex(inst);

    const elem_ty = inst_ty.elemType();
    if (!elem_ty.isFnOrHasRuntimeBitsIgnoreComptime()) {
        return .{ .undef = inst_ty };
    }

    const target = f.object.dg.module.getTarget();
    const local = try f.allocAlignedLocal(
        elem_ty,
        CQualifiers.init(.{ .@"const" = inst_ty.isConstPtr() }),
        inst_ty.ptrAlignment(target),
    );
    log.debug("%{d}: allocated unfreeable t{d}", .{ inst, local.new_local });
    const gpa = f.object.dg.module.gpa;
    try f.allocs.put(gpa, local.new_local, false);
    return .{ .local_ref = local.new_local };
}

fn airArg(f: *Function, inst: Air.Inst.Index) !CValue {
    const inst_ty = f.air.typeOfIndex(inst);
    const inst_cty = try f.typeToIndex(inst_ty, .parameter);

    const i = f.next_arg_index;
    f.next_arg_index += 1;
    return if (inst_cty != try f.typeToIndex(inst_ty, .complete))
        .{ .arg_array = i }
    else
        .{ .arg = i };
}

fn airLoad(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    const ptr_info = f.air.typeOf(ty_op.operand).ptrInfo().data;
    const src_ty = ptr_info.pointee_type;

    if (!src_ty.hasRuntimeBitsIgnoreComptime() or
        (!ptr_info.@"volatile" and f.liveness.isUnused(inst)))
    {
        try reap(f, inst, &.{ty_op.operand});
        return .none;
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
        try f.renderType(writer, src_ty);
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
        try f.renderType(writer, src_ty);
        try writer.writeAll(")zig_wrap_");
        try f.object.dg.renderTypeForBuiltinFnName(writer, field_ty);
        try writer.writeAll("((");
        try f.renderType(writer, field_ty);
        try writer.writeByte(')');
        const cant_cast = host_ty.isInt() and host_ty.bitSize(target) > 64;
        if (cant_cast) {
            if (field_ty.bitSize(target) > 64) return f.fail("TODO: C backend: implement casting between types > 64 bits", .{});
            try writer.writeAll("zig_lo_");
            try f.object.dg.renderTypeForBuiltinFnName(writer, host_ty);
            try writer.writeByte('(');
        }
        try writer.writeAll("zig_shr_");
        try f.object.dg.renderTypeForBuiltinFnName(writer, host_ty);
        try writer.writeByte('(');
        try f.writeCValueDeref(writer, operand);
        try writer.print(", {})", .{try f.fmtIntLiteral(bit_offset_ty, bit_offset_val)});
        if (cant_cast) try writer.writeByte(')');
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
    const op_inst = Air.refToIndex(un_op);
    const op_ty = f.air.typeOf(un_op);
    const ret_ty = if (is_ptr) op_ty.childType() else op_ty;
    var lowered_ret_buf: LowerFnRetTyBuffer = undefined;
    const lowered_ret_ty = lowerFnRetTy(ret_ty, &lowered_ret_buf, target);

    if (op_inst != null and f.air.instructions.items(.tag)[op_inst.?] == .call_always_tail) {
        try reap(f, inst, &.{un_op});
        _ = try airCall(f, op_inst.?, .always_tail);
    } else if (lowered_ret_ty.hasRuntimeBitsIgnoreComptime()) {
        const operand = try f.resolveInst(un_op);
        try reap(f, inst, &.{un_op});
        var deref = is_ptr;
        const is_array = lowersToArray(ret_ty, target);
        const ret_val = if (is_array) ret_val: {
            const array_local = try f.allocLocal(inst, try lowered_ret_ty.copy(f.arena.allocator()));
            try writer.writeAll("memcpy(");
            try f.writeCValueMember(writer, array_local, .{ .identifier = "array" });
            try writer.writeAll(", ");
            if (deref)
                try f.writeCValueDeref(writer, operand)
            else
                try f.writeCValue(writer, operand, .FunctionArgument);
            deref = false;
            try writer.writeAll(", sizeof(");
            try f.renderType(writer, ret_ty);
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
            try freeLocal(f, inst, ret_val.new_local, 0);
        }
    } else {
        try reap(f, inst, &.{un_op});
        // Not even allowed to return void in a naked function.
        if (if (f.object.dg.decl) |decl| decl.ty.fnCallingConvention() != .Naked else true)
            try writer.writeAll("return;\n");
    }
    return .none;
}

fn airIntCast(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ty_op.operand});
        return .none;
    }

    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const writer = f.object.writer();
    const inst_ty = f.air.typeOfIndex(inst);
    const local = try f.allocLocal(inst, inst_ty);
    const operand_ty = f.air.typeOf(ty_op.operand);

    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = ");
    try f.renderIntCast(writer, inst_ty, operand, operand_ty, .Other);
    try writer.writeAll(";\n");
    return local;
}

fn airTrunc(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ty_op.operand});
        return .none;
    }

    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const inst_ty = f.air.typeOfIndex(inst);
    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const target = f.object.dg.module.getTarget();
    const dest_int_info = inst_ty.intInfo(target);
    const dest_bits = dest_int_info.bits;
    const dest_c_bits = toCIntBits(dest_int_info.bits) orelse
        return f.fail("TODO: C backend: implement integer types larger than 128 bits", .{});
    const operand_ty = f.air.typeOf(ty_op.operand);
    const operand_int_info = operand_ty.intInfo(target);

    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = ");

    if (dest_c_bits < 64) {
        try writer.writeByte('(');
        try f.renderType(writer, inst_ty);
        try writer.writeByte(')');
    }

    const needs_lo = operand_int_info.bits > 64 and dest_bits <= 64;
    if (needs_lo) {
        try writer.writeAll("zig_lo_");
        try f.object.dg.renderTypeForBuiltinFnName(writer, operand_ty);
        try writer.writeByte('(');
    }

    if (dest_bits >= 8 and std.math.isPowerOfTwo(dest_bits)) {
        try f.writeCValue(writer, operand, .Other);
    } else switch (dest_int_info.signedness) {
        .unsigned => {
            var arena = std.heap.ArenaAllocator.init(f.object.dg.gpa);
            defer arena.deinit();

            const ExpectedContents = union { u: Value.Payload.U64, i: Value.Payload.I64 };
            var stack align(@alignOf(ExpectedContents)) =
                std.heap.stackFallback(@sizeOf(ExpectedContents), arena.allocator());

            const mask_val = try inst_ty.maxInt(stack.get(), target);
            try writer.writeAll("zig_and_");
            try f.object.dg.renderTypeForBuiltinFnName(writer, operand_ty);
            try writer.writeByte('(');
            try f.writeCValue(writer, operand, .FunctionArgument);
            try writer.print(", {x})", .{try f.fmtIntLiteral(operand_ty, mask_val)});
        },
        .signed => {
            const c_bits = toCIntBits(operand_int_info.bits) orelse
                return f.fail("TODO: C backend: implement integer types larger than 128 bits", .{});
            var shift_pl = Value.Payload.U64{
                .base = .{ .tag = .int_u64 },
                .data = c_bits - dest_bits,
            };
            const shift_val = Value.initPayload(&shift_pl.base);

            try writer.writeAll("zig_shr_");
            try f.object.dg.renderTypeForBuiltinFnName(writer, operand_ty);
            if (c_bits == 128) {
                try writer.print("(zig_bitcast_i{d}(", .{c_bits});
            } else {
                try writer.print("((int{d}_t)", .{c_bits});
            }
            try writer.print("zig_shl_u{d}(", .{c_bits});
            if (c_bits == 128) {
                try writer.print("zig_bitcast_u{d}(", .{c_bits});
            } else {
                try writer.print("(uint{d}_t)", .{c_bits});
            }
            try f.writeCValue(writer, operand, .FunctionArgument);
            if (c_bits == 128) try writer.writeByte(')');
            try writer.print(", {})", .{try f.fmtIntLiteral(Type.u8, shift_val)});
            if (c_bits == 128) try writer.writeByte(')');
            try writer.print(", {})", .{try f.fmtIntLiteral(Type.u8, shift_val)});
        },
    }

    if (needs_lo) try writer.writeByte(')');
    try writer.writeAll(";\n");
    return local;
}

fn airBoolToInt(f: *Function, inst: Air.Inst.Index) !CValue {
    const un_op = f.air.instructions.items(.data)[inst].un_op;
    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{un_op});
        return .none;
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
        try f.renderType(writer, lhs_child_ty);
        try writer.writeAll("));\n");
    }
    return .none;
}

fn airStore(f: *Function, inst: Air.Inst.Index) !CValue {
    // *a = b;
    const bin_op = f.air.instructions.items(.data)[inst].bin_op;
    const ptr_info = f.air.typeOf(bin_op.lhs).ptrInfo().data;
    if (!ptr_info.pointee_type.hasRuntimeBitsIgnoreComptime()) {
        try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
        return .none;
    }

    const ptr_val = try f.resolveInst(bin_op.lhs);
    const src_ty = f.air.typeOf(bin_op.rhs);

    // TODO Sema should emit a different instruction when the store should
    // possibly do the safety 0xaa bytes for undefined.
    const src_val_is_undefined =
        if (f.air.value(bin_op.rhs)) |v| v.isUndefDeep() else false;
    if (src_val_is_undefined) {
        try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
        return try storeUndefined(f, ptr_info.pointee_type, ptr_val);
    }

    const target = f.object.dg.module.getTarget();
    const is_aligned = ptr_info.@"align" == 0 or
        ptr_info.@"align" >= ptr_info.pointee_type.abiAlignment(target);
    const is_array = lowersToArray(ptr_info.pointee_type, target);
    const need_memcpy = !is_aligned or is_array;
    const writer = f.object.writer();

    const src_val = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

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
        try f.renderType(writer, src_ty);
        try writer.writeAll("))");
        if (src_val == .constant) {
            try freeLocal(f, inst, array_src.new_local, 0);
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
        try writer.writeByte('(');
        const cant_cast = host_ty.isInt() and host_ty.bitSize(target) > 64;
        if (cant_cast) {
            if (src_ty.bitSize(target) > 64) return f.fail("TODO: C backend: implement casting between types > 64 bits", .{});
            try writer.writeAll("zig_make_");
            try f.object.dg.renderTypeForBuiltinFnName(writer, host_ty);
            try writer.writeAll("(0, ");
        } else {
            try writer.writeByte('(');
            try f.renderType(writer, host_ty);
            try writer.writeByte(')');
        }

        if (src_ty.isPtrAtRuntime()) {
            try writer.writeByte('(');
            try f.renderType(writer, Type.usize);
            try writer.writeByte(')');
        }
        try f.writeCValue(writer, src_val, .Other);
        if (cant_cast) try writer.writeByte(')');
        try writer.print(", {}))", .{try f.fmtIntLiteral(bit_offset_ty, bit_offset_val)});
    } else {
        try f.writeCValueDeref(writer, ptr_val);
        try writer.writeAll(" = ");
        try f.writeCValue(writer, src_val, .Other);
    }
    try writer.writeAll(";\n");
    return .none;
}

fn airOverflow(f: *Function, inst: Air.Inst.Index, operation: []const u8, info: BuiltinInfo) !CValue {
    const ty_pl = f.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = f.air.extraData(Air.Bin, ty_pl.payload).data;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
        return .none;
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
    const inst_ty = f.air.typeOfIndex(inst);
    if (inst_ty.tag() != .bool)
        return try airUnBuiltinCall(f, inst, "not", .Bits);

    const ty_op = f.air.instructions.items(.data)[inst].ty_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ty_op.operand});
        return .none;
    }

    const op = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);

    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = ");
    try writer.writeByte('!');
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

    if (f.liveness.isUnused(inst)) return .none;

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
        return .none;
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
        return .none;
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
        return .none;
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
        return .none;
    }

    const lhs = try f.resolveInst(bin_op.lhs);
    const rhs = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const inst_ty = f.air.typeOfIndex(inst);
    const elem_ty = inst_ty.elemType2();

    const local = try f.allocLocal(inst, inst_ty);
    const writer = f.object.writer();
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = ");

    if (elem_ty.hasRuntimeBitsIgnoreComptime()) {
        // We must convert to and from integer types to prevent UB if the operation
        // results in a NULL pointer, or if LHS is NULL. The operation is only UB
        // if the result is NULL and then dereferenced.
        try writer.writeByte('(');
        try f.renderType(writer, inst_ty);
        try writer.writeAll(")(((uintptr_t)");
        try f.writeCValue(writer, lhs, .Other);
        try writer.writeAll(") ");
        try writer.writeByte(operator);
        try writer.writeAll(" (");
        try f.writeCValue(writer, rhs, .Other);
        try writer.writeAll("*sizeof(");
        try f.renderType(writer, elem_ty);
        try writer.writeAll(")))");
    } else try f.writeCValue(writer, lhs, .Initializer);

    try writer.writeAll(";\n");
    return local;
}

fn airMinMax(f: *Function, inst: Air.Inst.Index, operator: u8, operation: []const u8) !CValue {
    const bin_op = f.air.instructions.items(.data)[inst].bin_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
        return .none;
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
        return .none;
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
    try f.renderType(writer, inst_ty.slicePtrFieldType(&buf));
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
    modifier: std.builtin.CallModifier,
) !CValue {
    // Not even allowed to call panic in a naked function.
    if (f.object.dg.decl) |decl| if (decl.ty.fnCallingConvention() == .Naked) return .none;

    const gpa = f.object.dg.gpa;
    const module = f.object.dg.module;
    const target = module.getTarget();
    const writer = f.object.writer();

    const pl_op = f.air.instructions.items(.data)[inst].pl_op;
    const extra = f.air.extraData(Air.Call, pl_op.payload);
    const args = @ptrCast([]const Air.Inst.Ref, f.air.extra[extra.end..][0..extra.data.args_len]);

    const resolved_args = try gpa.alloc(CValue, args.len);
    defer gpa.free(resolved_args);
    for (resolved_args, args) |*resolved_arg, arg| {
        const arg_ty = f.air.typeOf(arg);
        const arg_cty = try f.typeToIndex(arg_ty, .parameter);
        if (f.indexToCType(arg_cty).tag() == .void) {
            resolved_arg.* = .none;
            continue;
        }
        resolved_arg.* = try f.resolveInst(arg);
        if (arg_cty != try f.typeToIndex(arg_ty, .complete)) {
            var lowered_arg_buf: LowerFnRetTyBuffer = undefined;
            const lowered_arg_ty = lowerFnRetTy(arg_ty, &lowered_arg_buf, target);

            const array_local = try f.allocLocal(inst, try lowered_arg_ty.copy(f.arena.allocator()));
            try writer.writeAll("memcpy(");
            try f.writeCValueMember(writer, array_local, .{ .identifier = "array" });
            try writer.writeAll(", ");
            try f.writeCValue(writer, resolved_arg.*, .FunctionArgument);
            try writer.writeAll(", sizeof(");
            try f.renderType(writer, lowered_arg_ty);
            try writer.writeAll("));\n");
            resolved_arg.* = array_local;
        }
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

    const ret_ty = fn_ty.fnReturnType();
    var lowered_ret_buf: LowerFnRetTyBuffer = undefined;
    const lowered_ret_ty = lowerFnRetTy(ret_ty, &lowered_ret_buf, target);

    const result_local = if (modifier == .always_tail) r: {
        try writer.writeAll("zig_always_tail return ");
        break :r .none;
    } else if (!lowered_ret_ty.hasRuntimeBitsIgnoreComptime())
        .none
    else if (f.liveness.isUnused(inst)) r: {
        try writer.writeByte('(');
        try f.renderType(writer, Type.void);
        try writer.writeByte(')');
        break :r .none;
    } else r: {
        const local = try f.allocLocal(inst, try lowered_ret_ty.copy(f.arena.allocator()));
        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(" = ");
        break :r local;
    };

    callee: {
        known: {
            const fn_decl = fn_decl: {
                const callee_val = f.air.value(pl_op.operand) orelse break :known;
                break :fn_decl switch (callee_val.tag()) {
                    .extern_fn => callee_val.castTag(.extern_fn).?.data.owner_decl,
                    .function => callee_val.castTag(.function).?.data.owner_decl,
                    .decl_ref => callee_val.castTag(.decl_ref).?.data,
                    else => break :known,
                };
            };
            switch (modifier) {
                .auto, .always_tail => try f.object.dg.renderDeclName(writer, fn_decl, 0),
                inline .never_tail, .never_inline => |mod| try writer.writeAll(try f.getLazyFnName(
                    @unionInit(LazyFnKey, @tagName(mod), fn_decl),
                    @unionInit(LazyFnValue.Data, @tagName(mod), {}),
                )),
                else => unreachable,
            }
            break :callee;
        }
        switch (modifier) {
            .auto, .always_tail => {},
            .never_tail => return f.fail("CBE: runtime callee with never_tail attribute unsupported", .{}),
            .never_inline => return f.fail("CBE: runtime callee with never_inline attribute unsupported", .{}),
            else => unreachable,
        }
        // Fall back to function pointer call.
        try f.writeCValue(writer, callee, .Other);
    }

    try writer.writeByte('(');
    var args_written: usize = 0;
    for (resolved_args) |resolved_arg| {
        if (resolved_arg == .none) continue;
        if (args_written != 0) try writer.writeAll(", ");
        try f.writeCValue(writer, resolved_arg, .FunctionArgument);
        if (resolved_arg == .new_local) try freeLocal(f, inst, resolved_arg.new_local, 0);
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
        try f.writeCValueMember(writer, result_local, .{ .identifier = "array" });
        try writer.writeAll(", sizeof(");
        try f.renderType(writer, ret_ty);
        try writer.writeAll("));\n");
        try freeLocal(f, inst, result_local.new_local, 0);
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
    return .none;
}

fn airDbgInline(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_pl = f.air.instructions.items(.data)[inst].ty_pl;
    const writer = f.object.writer();
    const function = f.air.values[ty_pl.payload].castTag(.function).?.data;
    const mod = f.object.dg.module;
    try writer.print("/* dbg func:{s} */\n", .{mod.declPtr(function.owner_decl).name});
    return .none;
}

fn airDbgVar(f: *Function, inst: Air.Inst.Index) !CValue {
    const pl_op = f.air.instructions.items(.data)[inst].pl_op;
    const name = f.air.nullTerminatedString(pl_op.payload);
    const operand_is_undef = if (f.air.value(pl_op.operand)) |v| v.isUndefDeep() else false;
    if (!operand_is_undef) _ = try f.resolveInst(pl_op.operand);

    try reap(f, inst, &.{pl_op.operand});
    const writer = f.object.writer();
    try writer.print("/* var:{s} */\n", .{name});
    return .none;
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
        .none;

    try f.blocks.putNoClobber(f.object.dg.gpa, inst, .{
        .block_id = block_id,
        .result = result,
    });

    try genBodyInner(f, body);
    try f.object.indent_writer.insertNewline();
    // label might be unused, add a dummy goto
    // label must be followed by an expression, add an empty one.
    try writer.print("goto zig_block_{d};\nzig_block_{d}: (void)0;\n", .{ block_id, block_id });
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
            return .none;
        } else {
            return err_union;
        }
    }

    try reap(f, inst, &.{operand});

    if (f.liveness.isUnused(inst)) {
        return .none;
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
        try f.renderType(writer, payload_ty);
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
            try f.renderType(writer, operand_ty);
            try writer.writeAll("))");
        } else {
            try f.writeCValue(writer, result, .Other);
            try writer.writeAll(" = ");
            try f.writeCValue(writer, operand, .Other);
        }
        try writer.writeAll(";\n");
    }

    try writer.print("goto zig_block_{d};\n", .{block.block_id});
    return .none;
}

fn airBitcast(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    const dest_ty = f.air.typeOfIndex(inst);
    // No IgnoreComptime until Sema stops giving us garbage Air.
    // https://github.com/ziglang/zig/issues/13410
    if (f.liveness.isUnused(inst) or !dest_ty.hasRuntimeBits()) {
        try reap(f, inst, &.{ty_op.operand});
        return .none;
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
        try f.renderType(writer, dest_ty);
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
    try f.renderType(writer, dest_ty);
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
        try freeLocal(f, inst, operand_lval.new_local, 0);
    }

    return local;
}

fn airBreakpoint(writer: anytype) !CValue {
    try writer.writeAll("zig_breakpoint();\n");
    return .none;
}

fn airRetAddr(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst)) return .none;
    const writer = f.object.writer();
    const local = try f.allocLocal(inst, Type.usize);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = (");
    try f.renderType(writer, Type.usize);
    try writer.writeAll(")zig_return_address();\n");
    return local;
}

fn airFrameAddress(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst)) return .none;
    const writer = f.object.writer();
    const local = try f.allocLocal(inst, Type.usize);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = (");
    try f.renderType(writer, Type.usize);
    try writer.writeAll(")zig_frame_address();\n");
    return local;
}

fn airFence(f: *Function, inst: Air.Inst.Index) !CValue {
    const atomic_order = f.air.instructions.items(.data)[inst].fence;
    const writer = f.object.writer();

    try writer.writeAll("zig_fence(");
    try writeMemoryOrder(writer, atomic_order);
    try writer.writeAll(");\n");

    return .none;
}

fn airUnreach(f: *Function) !CValue {
    // Not even allowed to call unreachable in a naked function.
    if (f.object.dg.decl) |decl| if (decl.ty.fnCallingConvention() == .Naked) return .none;

    try f.object.writer().writeAll("zig_unreachable();\n");
    return .none;
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
        const gop = try old_free_locals.getOrPut(gpa, entry.key_ptr.*);
        if (gop.found_existing) {
            try gop.value_ptr.ensureUnusedCapacity(gpa, entry.value_ptr.count());
            for (entry.value_ptr.keys()) |local_index| {
                gop.value_ptr.putAssumeCapacityNoClobber(local_index, {});
            }
        } else gop.value_ptr.* = entry.value_ptr.move();
    }
    deinitFreeLocalsMap(gpa, new_free_locals);
    new_free_locals.* = old_free_locals.move();

    return .none;
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
    // Remember how many allocs there were before entering the then branch so
    // that we can notice and make sure not to use them in the else branch.
    // Any new allocs must be removed from the free list.
    const pre_allocs_len = @intCast(LocalIndex, f.allocs.count());
    const pre_clone_depth = f.free_locals_clone_depth;
    f.free_locals_clone_depth = @intCast(LoopDepth, f.free_locals_stack.items.len);

    for (liveness_condbr.then_deaths) |operand| {
        try die(f, inst, Air.indexToRef(operand));
    }

    try writer.writeAll("if (");
    try f.writeCValue(writer, cond, .Other);
    try writer.writeAll(") ");
    try genBody(f, then_body);

    // TODO: If body ends in goto, elide the else block?
    const needs_else = then_body.len <= 0 or f.air.instructions.items(.tag)[then_body[then_body.len - 1]] != .br;
    if (needs_else) {
        try writer.writeAll(" else ");
    } else {
        try writer.writeByte('\n');
    }

    f.value_map.deinit();
    f.value_map = cloned_map.move();
    const free_locals = f.getFreeLocals();
    deinitFreeLocalsMap(gpa, free_locals);
    free_locals.* = cloned_frees.move();
    f.free_locals_clone_depth = pre_clone_depth;
    for (liveness_condbr.else_deaths) |operand| {
        try die(f, inst, Air.indexToRef(operand));
    }

    try noticeBranchFrees(f, pre_locals_len, pre_allocs_len, inst);

    if (needs_else) {
        try genBody(f, else_body);
    } else {
        try genBodyInner(f, else_body);
    }

    try f.object.indent_writer.insertNewline();

    return .none;
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
        try f.renderType(writer, Type.u1);
        try writer.writeByte(')');
    } else if (condition_ty.isPtrAtRuntime()) {
        try writer.writeByte('(');
        try f.renderType(writer, Type.usize);
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
    for (0..switch_br.data.cases_len) |case_i| {
        const case = f.air.extraData(Air.SwitchBr.Case, extra_index);
        const items = @ptrCast([]const Air.Inst.Ref, f.air.extra[case.end..][0..case.data.items_len]);
        const case_body = f.air.extra[case.end + items.len ..][0..case.data.body_len];
        extra_index = case.end + case.data.items_len + case_body.len;

        for (items) |item| {
            try f.object.indent_writer.insertNewline();
            try writer.writeAll("case ");
            if (condition_ty.isPtrAtRuntime()) {
                try writer.writeByte('(');
                try f.renderType(writer, Type.usize);
                try writer.writeByte(')');
            }
            try f.object.dg.renderValue(writer, condition_ty, f.air.value(item).?, .Other);
            try writer.writeByte(':');
        }
        try writer.writeByte(' ');

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
            // Remember how many allocs there were before entering each branch so that
            // we can notice and make sure not to use them in subsequent branches.
            // Any new allocs must be removed from the free list.
            const pre_allocs_len = @intCast(LocalIndex, f.allocs.count());
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

            try noticeBranchFrees(f, pre_locals_len, pre_allocs_len, inst);
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
    return .none;
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

    const result = r: {
        if (!is_volatile and f.liveness.isUnused(inst)) break :r .none;

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
                try f.object.dg.renderTypeAndName(writer, output_ty, local_value, .{}, alignment, .complete);
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
                try f.object.dg.renderTypeAndName(writer, input_ty, local_value, Const, alignment, .complete);
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
        for (0..clobbers_len) |_| {
            const clobber = std.mem.sliceTo(std.mem.sliceAsBytes(f.air.extra[extra_i..]), 0);
            // This equation accounts for the fact that even if we have exactly 4 bytes
            // for the string, we still use the next u32 for the null terminator.
            extra_i += clobber.len / 4 + 1;
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
            try writer.print("({s}", .{fmtStringLiteral(fixed_asm_source[0..dst_i], null)});
        }

        extra_i = constraints_extra_begin;
        var locals_index = locals_begin;
        try writer.writeByte(':');
        for (outputs, 0..) |output, index| {
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
            try writer.print("{s}(", .{fmtStringLiteral(if (is_reg) "=r" else constraint, null)});
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
        for (inputs, 0..) |input, index| {
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
            try writer.print("{s}(", .{fmtStringLiteral(if (is_reg) "r" else constraint, null)});
            try f.writeCValue(writer, if (asmInputNeedsLocal(constraint, input_val)) local: {
                const input_local = .{ .local = locals_index };
                locals_index += 1;
                break :local input_local;
            } else input_val, .Other);
            try writer.writeByte(')');
        }
        try writer.writeByte(':');
        for (0..clobbers_len) |clobber_i| {
            const clobber = std.mem.sliceTo(std.mem.sliceAsBytes(f.air.extra[extra_i..]), 0);
            // This equation accounts for the fact that even if we have exactly 4 bytes
            // for the string, we still use the next u32 for the null terminator.
            extra_i += clobber.len / 4 + 1;

            if (clobber.len == 0) continue;

            if (clobber_i > 0) try writer.writeByte(',');
            try writer.print(" {s}", .{fmtStringLiteral(clobber, null)});
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
                    .{ .local_ref = local.new_local }
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
        return .none;
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
        return .none;
    }

    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const opt_ty = f.air.typeOf(ty_op.operand);

    var buf: Type.Payload.ElemType = undefined;
    const payload_ty = opt_ty.optionalChild(&buf);

    if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
        return .none;
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
        try f.renderType(writer, inst_ty);
        try writer.writeAll("))");
    }
    try writer.writeAll(";\n");
    return local;
}

fn airOptionalPayloadPtr(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ty_op.operand});
        return .none;
    }

    const writer = f.object.writer();
    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const ptr_ty = f.air.typeOf(ty_op.operand);
    const opt_ty = ptr_ty.childType();
    const inst_ty = f.air.typeOfIndex(inst);

    if (!inst_ty.childType().hasRuntimeBitsIgnoreComptime()) {
        return .{ .undef = inst_ty };
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
            return .none;
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
            return .none;
        }

        const local = try f.allocLocal(inst, inst_ty);
        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(" = &");
        try f.writeCValueDeref(writer, operand);
        try writer.writeAll(".payload;\n");
        return local;
    }
}

fn fieldLocation(
    container_ty: Type,
    field_ptr_ty: Type,
    field_index: u32,
    target: std.Target,
) union(enum) {
    begin: void,
    field: CValue,
    byte_offset: u32,
    end: void,
} {
    return switch (container_ty.zigTypeTag()) {
        .Struct => switch (container_ty.containerLayout()) {
            .Auto, .Extern => for (field_index..container_ty.structFieldCount()) |next_field_index| {
                if (container_ty.structFieldIsComptime(next_field_index)) continue;
                const field_ty = container_ty.structFieldType(next_field_index);
                if (!field_ty.hasRuntimeBitsIgnoreComptime()) continue;
                break .{ .field = if (container_ty.isSimpleTuple())
                    .{ .field = next_field_index }
                else
                    .{ .identifier = container_ty.structFieldName(next_field_index) } };
            } else if (container_ty.hasRuntimeBitsIgnoreComptime()) .end else .begin,
            .Packed => if (field_ptr_ty.ptrInfo().data.host_size == 0)
                .{ .byte_offset = container_ty.packedStructFieldByteOffset(field_index, target) }
            else
                .begin,
        },
        .Union => switch (container_ty.containerLayout()) {
            .Auto, .Extern => {
                const field_ty = container_ty.structFieldType(field_index);
                if (!field_ty.hasRuntimeBitsIgnoreComptime())
                    return if (container_ty.unionTagTypeSafety() != null and
                        !container_ty.unionHasAllZeroBitFieldTypes())
                        .{ .field = .{ .identifier = "payload" } }
                    else
                        .begin;
                const field_name = container_ty.unionFields().keys()[field_index];
                return .{ .field = if (container_ty.unionTagTypeSafety()) |_|
                    .{ .payload_identifier = field_name }
                else
                    .{ .identifier = field_name } };
            },
            .Packed => .begin,
        },
        .Pointer => switch (container_ty.ptrSize()) {
            .Slice => switch (field_index) {
                0 => .{ .field = .{ .identifier = "ptr" } },
                1 => .{ .field = .{ .identifier = "len" } },
                else => unreachable,
            },
            .One, .Many, .C => unreachable,
        },
        else => unreachable,
    };
}

fn airStructFieldPtr(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_pl = f.air.instructions.items(.data)[inst].ty_pl;
    const extra = f.air.extraData(Air.StructField, ty_pl.payload).data;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{extra.struct_operand});
        return .none;
    }

    const container_ptr_val = try f.resolveInst(extra.struct_operand);
    try reap(f, inst, &.{extra.struct_operand});
    const container_ptr_ty = f.air.typeOf(extra.struct_operand);
    return fieldPtr(f, inst, container_ptr_ty, container_ptr_val, extra.field_index);
}

fn airStructFieldPtrIndex(f: *Function, inst: Air.Inst.Index, index: u8) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ty_op.operand});
        return .none;
    }

    const container_ptr_val = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const container_ptr_ty = f.air.typeOf(ty_op.operand);
    return fieldPtr(f, inst, container_ptr_ty, container_ptr_val, index);
}

fn airFieldParentPtr(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_pl = f.air.instructions.items(.data)[inst].ty_pl;
    const extra = f.air.extraData(Air.FieldParentPtr, ty_pl.payload).data;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{extra.field_ptr});
        return .none;
    }

    const target = f.object.dg.module.getTarget();
    const container_ptr_ty = f.air.typeOfIndex(inst);
    const container_ty = container_ptr_ty.childType();

    const field_ptr_ty = f.air.typeOf(extra.field_ptr);
    const field_ptr_val = try f.resolveInst(extra.field_ptr);
    try reap(f, inst, &.{extra.field_ptr});

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, container_ptr_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = (");
    try f.renderType(writer, container_ptr_ty);
    try writer.writeByte(')');

    switch (fieldLocation(container_ty, field_ptr_ty, extra.field_index, target)) {
        .begin => try f.writeCValue(writer, field_ptr_val, .Initializer),
        .field => |field| {
            var u8_ptr_pl = field_ptr_ty.ptrInfo();
            u8_ptr_pl.data.pointee_type = Type.u8;
            const u8_ptr_ty = Type.initPayload(&u8_ptr_pl.base);

            try writer.writeAll("((");
            try f.renderType(writer, u8_ptr_ty);
            try writer.writeByte(')');
            try f.writeCValue(writer, field_ptr_val, .Other);
            try writer.writeAll(" - offsetof(");
            try f.renderType(writer, container_ty);
            try writer.writeAll(", ");
            try f.writeCValue(writer, field, .Other);
            try writer.writeAll("))");
        },
        .byte_offset => |byte_offset| {
            var u8_ptr_pl = field_ptr_ty.ptrInfo();
            u8_ptr_pl.data.pointee_type = Type.u8;
            const u8_ptr_ty = Type.initPayload(&u8_ptr_pl.base);

            var byte_offset_pl = Value.Payload.U64{
                .base = .{ .tag = .int_u64 },
                .data = byte_offset,
            };
            const byte_offset_val = Value.initPayload(&byte_offset_pl.base);

            try writer.writeAll("((");
            try f.renderType(writer, u8_ptr_ty);
            try writer.writeByte(')');
            try f.writeCValue(writer, field_ptr_val, .Other);
            try writer.print(" - {})", .{try f.fmtIntLiteral(Type.usize, byte_offset_val)});
        },
        .end => {
            try f.writeCValue(writer, field_ptr_val, .Other);
            try writer.print(" - {}", .{try f.fmtIntLiteral(Type.usize, Value.one)});
        },
    }

    try writer.writeAll(";\n");
    return local;
}

fn fieldPtr(
    f: *Function,
    inst: Air.Inst.Index,
    container_ptr_ty: Type,
    container_ptr_val: CValue,
    field_index: u32,
) !CValue {
    const target = f.object.dg.module.getTarget();
    const container_ty = container_ptr_ty.elemType();
    const field_ptr_ty = f.air.typeOfIndex(inst);

    // Ensure complete type definition is visible before accessing fields.
    _ = try f.typeToIndex(container_ty, .complete);

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, field_ptr_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = (");
    try f.renderType(writer, field_ptr_ty);
    try writer.writeByte(')');

    switch (fieldLocation(container_ty, field_ptr_ty, field_index, target)) {
        .begin => try f.writeCValue(writer, container_ptr_val, .Initializer),
        .field => |field| {
            try writer.writeByte('&');
            try f.writeCValueDerefMember(writer, container_ptr_val, field);
        },
        .byte_offset => |byte_offset| {
            var u8_ptr_pl = field_ptr_ty.ptrInfo();
            u8_ptr_pl.data.pointee_type = Type.u8;
            const u8_ptr_ty = Type.initPayload(&u8_ptr_pl.base);

            var byte_offset_pl = Value.Payload.U64{
                .base = .{ .tag = .int_u64 },
                .data = byte_offset,
            };
            const byte_offset_val = Value.initPayload(&byte_offset_pl.base);

            try writer.writeAll("((");
            try f.renderType(writer, u8_ptr_ty);
            try writer.writeByte(')');
            try f.writeCValue(writer, container_ptr_val, .Other);
            try writer.print(" + {})", .{try f.fmtIntLiteral(Type.usize, byte_offset_val)});
        },
        .end => {
            try writer.writeByte('(');
            try f.writeCValue(writer, container_ptr_val, .Other);
            try writer.print(" + {})", .{try f.fmtIntLiteral(Type.usize, Value.one)});
        },
    }

    try writer.writeAll(";\n");
    return local;
}

fn airStructFieldVal(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_pl = f.air.instructions.items(.data)[inst].ty_pl;
    const extra = f.air.extraData(Air.StructField, ty_pl.payload).data;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{extra.struct_operand});
        return .none;
    }

    const inst_ty = f.air.typeOfIndex(inst);
    if (!inst_ty.hasRuntimeBitsIgnoreComptime()) {
        try reap(f, inst, &.{extra.struct_operand});
        return .none;
    }

    const target = f.object.dg.module.getTarget();
    const struct_byval = try f.resolveInst(extra.struct_operand);
    try reap(f, inst, &.{extra.struct_operand});
    const struct_ty = f.air.typeOf(extra.struct_operand);
    const writer = f.object.writer();

    // Ensure complete type definition is visible before accessing fields.
    _ = try f.typeToIndex(struct_ty, .complete);

    const field_name: CValue = switch (struct_ty.tag()) {
        .tuple, .anon_struct, .@"struct" => switch (struct_ty.containerLayout()) {
            .Auto, .Extern => if (struct_ty.isSimpleTuple())
                .{ .field = extra.field_index }
            else
                .{ .identifier = struct_ty.structFieldName(extra.field_index) },
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
                try f.renderType(writer, field_int_ty);
                try writer.writeByte(')');
                const cant_cast = int_info.bits > 64;
                if (cant_cast) {
                    if (field_int_ty.bitSize(target) > 64) return f.fail("TODO: C backend: implement casting between types > 64 bits", .{});
                    try writer.writeAll("zig_lo_");
                    try f.object.dg.renderTypeForBuiltinFnName(writer, struct_ty);
                    try writer.writeByte('(');
                }
                try writer.writeAll("zig_shr_");
                try f.object.dg.renderTypeForBuiltinFnName(writer, struct_ty);
                try writer.writeByte('(');
                try f.writeCValue(writer, struct_byval, .Other);
                try writer.writeAll(", ");
                try f.object.dg.renderValue(writer, bit_offset_ty, bit_offset_val, .FunctionArgument);
                try writer.writeByte(')');
                if (cant_cast) try writer.writeByte(')');
                try f.object.dg.renderBuiltinInfo(writer, field_int_ty, .Bits);
                try writer.writeAll(");\n");
                if (inst_ty.eql(field_int_ty, f.object.dg.module)) return temp_local;

                const local = try f.allocLocal(inst, inst_ty);
                try writer.writeAll("memcpy(");
                try f.writeCValue(writer, .{ .local_ref = local.new_local }, .FunctionArgument);
                try writer.writeAll(", ");
                try f.writeCValue(writer, .{ .local_ref = temp_local.new_local }, .FunctionArgument);
                try writer.writeAll(", sizeof(");
                try f.renderType(writer, inst_ty);
                try writer.writeAll("));\n");
                try freeLocal(f, inst, temp_local.new_local, 0);
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
            try f.renderType(writer, inst_ty);
            try writer.writeAll("));\n");

            if (struct_byval == .constant) {
                try freeLocal(f, inst, operand_lval.new_local, 0);
            }

            return local;
        } else field_name: {
            const name = struct_ty.unionFields().keys()[extra.field_index];
            break :field_name if (struct_ty.unionTagTypeSafety()) |_|
                .{ .payload_identifier = name }
            else
                .{ .identifier = name };
        },
        else => unreachable,
    };

    const local = try f.allocLocal(inst, inst_ty);
    if (lowersToArray(inst_ty, target)) {
        try writer.writeAll("memcpy(");
        try f.writeCValue(writer, local, .FunctionArgument);
        try writer.writeAll(", ");
        try f.writeCValueMember(writer, struct_byval, field_name);
        try writer.writeAll(", sizeof(");
        try f.renderType(writer, inst_ty);
        try writer.writeAll("))");
    } else {
        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(" = ");
        try f.writeCValueMember(writer, struct_byval, field_name);
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
        return .none;
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
        return .none;
    }

    const inst_ty = f.air.typeOfIndex(inst);
    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const operand_ty = f.air.typeOf(ty_op.operand);
    const operand_is_ptr = operand_ty.zigTypeTag() == .Pointer;
    const error_union_ty = if (operand_is_ptr) operand_ty.childType() else operand_ty;

    if (!error_union_ty.errorUnionPayload().hasRuntimeBits()) {
        if (!is_ptr) return .none;

        const w = f.object.writer();
        const local = try f.allocLocal(inst, inst_ty);
        try f.writeCValue(w, local, .Other);
        try w.writeAll(" = (");
        try f.renderType(w, inst_ty);
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
        return .none;
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
        try f.renderType(writer, payload_ty);
        try writer.writeAll("));\n");
    }
    return local;
}

fn airWrapErrUnionErr(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ty_op.operand});
        return .none;
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
    if (f.liveness.isUnused(inst)) return .none;

    const local = try f.allocLocal(inst, f.air.typeOfIndex(inst));
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = &(");
    try f.writeCValueDeref(writer, operand);
    try writer.writeAll(").payload;\n");
    return local;
}

fn airErrReturnTrace(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst)) return .none;
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
        return .none;
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
        try f.renderType(writer, payload_ty);
        try writer.writeAll("));\n");
    }
    return local;
}

fn airIsErr(f: *Function, inst: Air.Inst.Index, is_ptr: bool, operator: []const u8) !CValue {
    const un_op = f.air.instructions.items(.data)[inst].un_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{un_op});
        return .none;
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
        return .none;
    }

    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const inst_ty = f.air.typeOfIndex(inst);
    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const array_ty = f.air.typeOf(ty_op.operand).childType();

    try f.writeCValueMember(writer, local, .{ .identifier = "ptr" });
    try writer.writeAll(" = ");
    // Unfortunately, C does not support any equivalent to
    // &(*(void *)p)[0], although LLVM does via GetElementPtr
    if (operand == .undef) {
        var buf: Type.SlicePtrFieldTypeBuffer = undefined;
        try f.writeCValue(writer, .{ .undef = inst_ty.slicePtrFieldType(&buf) }, .Initializer);
    } else if (array_ty.hasRuntimeBitsIgnoreComptime()) {
        try writer.writeAll("&(");
        try f.writeCValueDeref(writer, operand);
        try writer.print(")[{}]", .{try f.fmtIntLiteral(Type.usize, Value.zero)});
    } else try f.writeCValue(writer, operand, .Initializer);
    try writer.writeAll("; ");

    const array_len = array_ty.arrayLen();
    var len_pl: Value.Payload.U64 = .{ .base = .{ .tag = .int_u64 }, .data = array_len };
    const len_val = Value.initPayload(&len_pl.base);
    try f.writeCValueMember(writer, local, .{ .identifier = "len" });
    try writer.print(" = {};\n", .{try f.fmtIntLiteral(Type.usize, len_val)});

    return local;
}

fn airFloatCast(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ty_op.operand});
        return .none;
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
        return .none;
    }

    const operand = try f.resolveInst(un_op);
    try reap(f, inst, &.{un_op});
    const inst_ty = f.air.typeOfIndex(inst);
    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);

    try writer.writeAll(" = (");
    try f.renderType(writer, inst_ty);
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
        return .none;
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
        return .none;
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
        try f.renderType(writer, ptr_ty.childType());
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
        try writer.writeAll(", ");
        try f.object.dg.renderTypeForBuiltinFnName(writer, ptr_ty.childType());
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
        try f.renderType(writer, ptr_ty.childType());
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
        try writer.writeAll(", ");
        try f.object.dg.renderTypeForBuiltinFnName(writer, ptr_ty.childType());
        try writer.writeByte(')');
        try writer.writeAll(";\n");
    }

    if (f.liveness.isUnused(inst)) {
        try freeLocal(f, inst, local.new_local, 0);
        return .none;
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
            try f.renderType(writer, ptr_ty.elemType());
            try writer.writeByte(')');
        },
        .Nand, .Min, .Max => {
            // These are missing from stdatomic.h, so no atomic types for now.
            try f.renderType(writer, ptr_ty.elemType());
        },
    }
    if (ptr_ty.isVolatilePtr()) try writer.writeAll(" volatile");
    try writer.writeAll(" *)");
    try f.writeCValue(writer, ptr, .Other);
    try writer.writeAll(", ");
    try f.writeCValue(writer, operand, .FunctionArgument);
    try writer.writeAll(", ");
    try writeMemoryOrder(writer, extra.ordering());
    try writer.writeAll(", ");
    try f.object.dg.renderTypeForBuiltinFnName(writer, ptr_ty.childType());
    try writer.writeAll(");\n");

    if (f.liveness.isUnused(inst)) {
        try freeLocal(f, inst, local.new_local, 0);
        return .none;
    }

    return local;
}

fn airAtomicLoad(f: *Function, inst: Air.Inst.Index) !CValue {
    const atomic_load = f.air.instructions.items(.data)[inst].atomic_load;
    const ptr = try f.resolveInst(atomic_load.ptr);
    try reap(f, inst, &.{atomic_load.ptr});
    const ptr_ty = f.air.typeOf(atomic_load.ptr);
    if (!ptr_ty.isVolatilePtr() and f.liveness.isUnused(inst)) {
        return .none;
    }

    const inst_ty = f.air.typeOfIndex(inst);
    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);

    try writer.writeAll(" = zig_atomic_load((zig_atomic(");
    try f.renderType(writer, ptr_ty.elemType());
    try writer.writeByte(')');
    if (ptr_ty.isVolatilePtr()) try writer.writeAll(" volatile");
    try writer.writeAll(" *)");
    try f.writeCValue(writer, ptr, .Other);
    try writer.writeAll(", ");
    try writeMemoryOrder(writer, atomic_load.order);
    try writer.writeAll(", ");
    try f.object.dg.renderTypeForBuiltinFnName(writer, ptr_ty.childType());
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
    try f.renderType(writer, ptr_ty.elemType());
    try writer.writeByte(')');
    if (ptr_ty.isVolatilePtr()) try writer.writeAll(" volatile");
    try writer.writeAll(" *)");
    try f.writeCValue(writer, ptr, .Other);
    try writer.writeAll(", ");
    try f.writeCValue(writer, element, .FunctionArgument);
    try writer.print(", {s}, ", .{order});
    try f.object.dg.renderTypeForBuiltinFnName(writer, ptr_ty.childType());
    try writer.writeAll(");\n");

    return .none;
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
        try f.renderType(writer, u8_ptr_ty);
        try writer.writeByte(')');
        try f.writeCValue(writer, dest_ptr, .FunctionArgument);
        try writer.writeAll(")[");
        try f.writeCValue(writer, index, .Other);
        try writer.writeAll("] = ");
        try f.writeCValue(writer, value, .FunctionArgument);
        try writer.writeAll(";\n");

        try reap(f, inst, &.{ pl_op.operand, extra.lhs, extra.rhs });
        try freeLocal(f, inst, index.new_local, 0);

        return .none;
    }

    try reap(f, inst, &.{ pl_op.operand, extra.lhs, extra.rhs });
    try writer.writeAll("memset(");
    try f.writeCValue(writer, dest_ptr, .FunctionArgument);
    try writer.writeAll(", ");
    try f.writeCValue(writer, value, .FunctionArgument);
    try writer.writeAll(", ");
    try f.writeCValue(writer, len, .FunctionArgument);
    try writer.writeAll(");\n");

    return .none;
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

    return .none;
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
    if (layout.tag_size == 0) return .none;

    try writer.writeByte('(');
    try f.writeCValue(writer, union_ptr, .Other);
    try writer.writeAll(")->tag = ");
    try f.writeCValue(writer, new_tag, .Other);
    try writer.writeAll(";\n");

    return .none;
}

fn airGetUnionTag(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ty_op.operand});
        return .none;
    }

    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});

    const un_ty = f.air.typeOf(ty_op.operand);

    const target = f.object.dg.module.getTarget();
    const layout = un_ty.unionGetLayout(target);
    if (layout.tag_size == 0) return .none;

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
        return .none;
    }

    const inst_ty = f.air.typeOfIndex(inst);
    const enum_ty = f.air.typeOf(un_op);
    const operand = try f.resolveInst(un_op);
    try reap(f, inst, &.{un_op});

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.print(" = {s}(", .{
        try f.getLazyFnName(.{ .tag_name = enum_ty.getOwnerDecl() }, .{ .tag_name = enum_ty }),
    });
    try f.writeCValue(writer, operand, .Other);
    try writer.writeAll(");\n");

    return local;
}

fn airErrorName(f: *Function, inst: Air.Inst.Index) !CValue {
    const un_op = f.air.instructions.items(.data)[inst].un_op;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{un_op});
        return .none;
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
        return .none;
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
    if (f.liveness.isUnused(inst)) return .none;

    return f.fail("TODO: C backend: implement airSelect", .{});
}

fn airShuffle(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst)) return .none;

    return f.fail("TODO: C backend: implement airShuffle", .{});
}

fn airReduce(f: *Function, inst: Air.Inst.Index) !CValue {
    const reduce = f.air.instructions.items(.data)[inst].reduce;

    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{reduce.operand});
        return .none;
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
    //     var accum: T = init;
    //     for (vec) : (elem) {
    //       accum = func(accum, elem);
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

    try freeLocal(f, inst, it.new_local, 0);

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
    for (resolved_elements, elements) |*resolved_element, element| {
        resolved_element.* = try f.resolveInst(element);
    }
    {
        var bt = iterateBigTomb(f, inst);
        for (elements) |element| {
            try bt.feed(element);
        }
    }

    if (f.liveness.isUnused(inst)) return .none;

    const target = f.object.dg.module.getTarget();

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    switch (inst_ty.zigTypeTag()) {
        .Array, .Vector => {
            const elem_ty = inst_ty.childType();
            for (resolved_elements, 0..) |element, i| {
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
                try f.renderType(writer, inst_ty);
                try writer.writeAll(")");
                try writer.writeByte('{');
                var empty = true;
                for (elements, resolved_elements, 0..) |element, resolved_element, field_i| {
                    if (inst_ty.structFieldValueComptime(field_i)) |_| continue;

                    if (!empty) try writer.writeAll(", ");

                    const field_name: CValue = if (inst_ty.isSimpleTuple())
                        .{ .field = field_i }
                    else
                        .{ .identifier = inst_ty.structFieldName(field_i) };
                    try writer.writeByte('.');
                    try f.object.dg.writeCValue(writer, field_name);
                    try writer.writeAll(" = ");

                    const element_ty = f.air.typeOf(element);
                    try f.writeCValue(writer, switch (element_ty.zigTypeTag()) {
                        .Array => .{ .undef = element_ty },
                        else => resolved_element,
                    }, .Initializer);
                    empty = false;
                }
                try writer.writeAll("};\n");

                for (elements, resolved_elements, 0..) |element, resolved_element, field_i| {
                    if (inst_ty.structFieldValueComptime(field_i)) |_| continue;

                    const element_ty = f.air.typeOf(element);
                    if (element_ty.zigTypeTag() != .Array) continue;

                    const field_name: CValue = if (inst_ty.isSimpleTuple())
                        .{ .field = field_i }
                    else
                        .{ .identifier = inst_ty.structFieldName(field_i) };

                    try writer.writeAll(";\n");
                    try writer.writeAll("memcpy(");
                    try f.writeCValueMember(writer, local, field_name);
                    try writer.writeAll(", ");
                    try f.writeCValue(writer, resolved_element, .FunctionArgument);
                    try writer.writeAll(", sizeof(");
                    try f.renderType(writer, element_ty);
                    try writer.writeAll("));\n");
                }
            },
            .Packed => {
                try f.writeCValue(writer, local, .Other);
                try writer.writeAll(" = ");
                const int_info = inst_ty.intInfo(target);

                var bit_offset_ty_pl = Type.Payload.Bits{
                    .base = .{ .tag = .int_unsigned },
                    .data = Type.smallestUnsignedBits(int_info.bits - 1),
                };
                const bit_offset_ty = Type.initPayload(&bit_offset_ty_pl.base);

                var bit_offset_val_pl: Value.Payload.U64 = .{ .base = .{ .tag = .int_u64 }, .data = 0 };
                const bit_offset_val = Value.initPayload(&bit_offset_val_pl.base);

                var empty = true;
                for (0..elements.len) |index| {
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
                for (resolved_elements, 0..) |element, index| {
                    const field_ty = inst_ty.structFieldType(index);
                    if (!field_ty.hasRuntimeBitsIgnoreComptime()) continue;

                    if (!empty) try writer.writeAll(", ");
                    // TODO: Skip this entire shift if val is 0?
                    try writer.writeAll("zig_shlw_");
                    try f.object.dg.renderTypeForBuiltinFnName(writer, inst_ty);
                    try writer.writeByte('(');

                    if (inst_ty.isAbiInt() and (field_ty.isAbiInt() or field_ty.isPtrAtRuntime())) {
                        try f.renderIntCast(writer, inst_ty, element, field_ty, .FunctionArgument);
                    } else {
                        try writer.writeByte('(');
                        try f.renderType(writer, inst_ty);
                        try writer.writeByte(')');
                        if (field_ty.isPtrAtRuntime()) {
                            try writer.writeByte('(');
                            try f.renderType(writer, switch (int_info.signedness) {
                                .unsigned => Type.usize,
                                .signed => Type.isize,
                            });
                            try writer.writeByte(')');
                        }
                        try f.writeCValue(writer, element, .Other);
                    }

                    try writer.writeAll(", ");
                    try f.object.dg.renderValue(writer, bit_offset_ty, bit_offset_val, .FunctionArgument);
                    try f.object.dg.renderBuiltinInfo(writer, inst_ty, .Bits);
                    try writer.writeByte(')');
                    if (!empty) try writer.writeByte(')');

                    bit_offset_val_pl.data += field_ty.bitSize(target);
                    empty = false;
                }

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
        return .none;
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

    const field: CValue = if (union_ty.unionTagTypeSafety()) |tag_ty| field: {
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
        break :field .{ .payload_identifier = field_name };
    } else .{ .identifier = field_name };

    try f.writeCValueMember(writer, local, field);
    try writer.writeAll(" = ");
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
        .instruction => return .none,
    }
    const ptr = try f.resolveInst(prefetch.ptr);
    try reap(f, inst, &.{prefetch.ptr});
    const writer = f.object.writer();
    try writer.writeAll("zig_prefetch(");
    try f.writeCValue(writer, ptr, .FunctionArgument);
    try writer.print(", {d}, {d});\n", .{
        @enumToInt(prefetch.rw), prefetch.locality,
    });
    return .none;
}

fn airWasmMemorySize(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst)) return .none;

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
        return .none;
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
        return .none;
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
        return .none;
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
        return .none;
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

fn airCVaStart(f: *Function, inst: Air.Inst.Index) !CValue {
    if (f.liveness.isUnused(inst)) return .none;

    const inst_ty = f.air.typeOfIndex(inst);
    const fn_cty = try f.typeToCType(f.object.dg.decl.?.ty, .complete);
    const param_len = fn_cty.castTag(.varargs_function).?.data.param_types.len;

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try writer.writeAll("va_start(*(va_list *)&");
    try f.writeCValue(writer, local, .Other);
    if (param_len > 0) {
        try writer.writeAll(", ");
        try f.writeCValue(writer, .{ .arg = param_len - 1 }, .FunctionArgument);
    }
    try writer.writeAll(");\n");
    return local;
}

fn airCVaArg(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ty_op.operand});
        return .none;
    }

    const inst_ty = f.air.typeOfIndex(inst);
    const va_list = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = va_arg(*(va_list *)");
    try f.writeCValue(writer, va_list, .Other);
    try writer.writeAll(", ");
    try f.renderType(writer, f.air.getRefType(ty_op.ty));
    try writer.writeAll(");\n");
    return local;
}

fn airCVaEnd(f: *Function, inst: Air.Inst.Index) !CValue {
    const un_op = f.air.instructions.items(.data)[inst].un_op;

    const va_list = try f.resolveInst(un_op);
    try reap(f, inst, &.{un_op});

    const writer = f.object.writer();
    try writer.writeAll("va_end(*(va_list *)");
    try f.writeCValue(writer, va_list, .Other);
    try writer.writeAll(");\n");
    return .none;
}

fn airCVaCopy(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[inst].ty_op;
    if (f.liveness.isUnused(inst)) {
        try reap(f, inst, &.{ty_op.operand});
        return .none;
    }

    const inst_ty = f.air.typeOfIndex(inst);
    const va_list = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try writer.writeAll("va_copy(*(va_list *)&");
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(", *(va_list *)");
    try f.writeCValue(writer, va_list, .Other);
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

fn toCallingConvention(call_conv: std.builtin.CallingConvention) ?[]const u8 {
    return switch (call_conv) {
        .Stdcall => "stdcall",
        .Fastcall => "fastcall",
        .Vectorcall => "vectorcall",
        else => null,
    };
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

fn StringLiteral(comptime WriterType: type) type {
    // MSVC has a length limit of 16380 per string literal (before concatenation)
    const max_char_len = 4;
    const max_len = 16380 - max_char_len;

    return struct {
        cur_len: u64 = 0,
        counting_writer: std.io.CountingWriter(WriterType),

        pub const Error = WriterType.Error;

        const Self = @This();

        pub fn start(self: *Self) Error!void {
            const writer = self.counting_writer.writer();
            try writer.writeByte('\"');
        }

        pub fn end(self: *Self) Error!void {
            const writer = self.counting_writer.writer();
            try writer.writeByte('\"');
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

        pub fn writeChar(self: *Self, c: u8) Error!void {
            const writer = self.counting_writer.writer();

            if (self.cur_len == 0 and self.counting_writer.bytes_written > 1)
                try writer.writeAll("\"\"");

            const len = self.counting_writer.bytes_written;
            try writeStringLiteralChar(writer, c);

            const char_length = self.counting_writer.bytes_written - len;
            assert(char_length <= max_char_len);
            self.cur_len += char_length;

            if (self.cur_len >= max_len) self.cur_len = 0;
        }
    };
}

fn stringLiteral(child_stream: anytype) StringLiteral(@TypeOf(child_stream)) {
    return .{ .counting_writer = std.io.countingWriter(child_stream) };
}

const FormatStringContext = struct { str: []const u8, sentinel: ?u8 };
fn formatStringLiteral(
    data: FormatStringContext,
    comptime fmt: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    if (fmt.len != 1 or fmt[0] != 's') @compileError("Invalid fmt: " ++ fmt);

    var literal = stringLiteral(writer);
    try literal.start();
    for (data.str) |c| try literal.writeChar(c);
    if (data.sentinel) |sentinel| if (sentinel != 0) try literal.writeChar(sentinel);
    try literal.end();
}

fn fmtStringLiteral(str: []const u8, sentinel: ?u8) std.fmt.Formatter(formatStringLiteral) {
    return .{ .data = .{ .str = str, .sentinel = sentinel } };
}

fn undefPattern(comptime IntType: type) IntType {
    const int_info = @typeInfo(IntType).Int;
    const UnsignedType = std.meta.Int(.unsigned, int_info.bits);
    return @bitCast(IntType, @as(UnsignedType, (1 << (int_info.bits | 1)) / 3));
}

const FormatIntLiteralContext = struct { ty: Type, val: Value, mod: *Module, location: ?ValueRenderLocation = null };
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

    var use_twos_comp = false;
    if (!int.positive) {
        if (c_bits > 64) {
            // TODO: Can this be done for decimal literals as well?
            if (fmt.len == 1 and fmt[0] != 'd') {
                use_twos_comp = true;
            } else {
                // TODO: Use fmtIntLiteral for 0?
                try writer.print("zig_sub_{c}{d}(zig_make_{c}{d}(0, 0), ", .{ signAbbrev(int_info.signedness), c_bits, signAbbrev(int_info.signedness), c_bits });
            }
        } else {
            try writer.writeByte('-');
        }
    }

    switch (data.ty.tag()) {
        .c_short, .c_ushort, .c_int, .c_uint, .c_long, .c_ulong, .c_longlong, .c_ulonglong => {},
        else => {
            if (int_info.bits <= 64) {
                try writer.print("{s}INT{d}_C(", .{ switch (int_info.signedness) {
                    .signed => "",
                    .unsigned => "U",
                }, c_bits });
            } else if (data.location != null and data.location.? == .StaticInitializer) {
                // MSVC treats casting the struct initializer as not constant (C2099), so an alternate form is used in global initializers
                try writer.print("zig_make_constant_{c}{d}(", .{ signAbbrev(int_info.signedness), c_bits });
            } else {
                try writer.print("zig_make_{c}{d}(", .{ signAbbrev(int_info.signedness), c_bits });
            }
        },
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
        var twos_comp_limbs: [BigInt.calcTwosCompLimbCount(128)]BigIntLimb = undefined;

        // Adding a negation in the C code before the doesn't work in all cases:
        // - struct versions would require an extra zig_sub_ call to negate, which wouldn't work in constant expressions
        // - negating the f80 int representation (i128) doesn't make sense
        // Instead we write out the literal as a negative number in twos complement
        var limbs = int.limbs;

        if (use_twos_comp) {
            var twos_comp = BigInt.Mutable{
                .limbs = &twos_comp_limbs,
                .positive = undefined,
                .len = undefined,
            };

            twos_comp.convertToTwosComplement(int, .signed, int_info.bits);
            limbs = twos_comp.limbs;
        }

        var upper_pl = Value.Payload.BigInt{
            .base = .{ .tag = .int_big_positive },
            .data = limbs[split..],
        };
        const upper_val = Value.initPayload(&upper_pl.base);
        try formatIntLiteral(.{
            .ty = switch (int_info.signedness) {
                .unsigned => Type.u64,
                .signed => if (use_twos_comp) Type.u64 else Type.i64,
            },
            .val = upper_val,
            .mod = data.mod,
        }, fmt, options, writer);

        try writer.writeAll(", ");

        var lower_pl = Value.Payload.BigInt{
            .base = .{ .tag = .int_big_positive },
            .data = limbs[0..split],
        };
        const lower_val = Value.initPayload(&lower_pl.base);
        try formatIntLiteral(.{
            .ty = Type.u64,
            .val = lower_val,
            .mod = data.mod,
        }, fmt, options, writer);

        if (!int.positive and c_bits > 64 and !use_twos_comp) try writer.writeByte(')');
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
    names: [1][]const u8,
    types: [1]Type,
    values: [1]Value,
    payload: Type.Payload.AnonStruct,
};
fn lowerFnRetTy(ret_ty: Type, buffer: *LowerFnRetTyBuffer, target: std.Target) Type {
    if (ret_ty.zigTypeTag() == .NoReturn) return Type.initTag(.noreturn);

    if (lowersToArray(ret_ty, target)) {
        buffer.names = [1][]const u8{"array"};
        buffer.types = [1]Type{ret_ty};
        buffer.values = [1]Value{Value.initTag(.unreachable_value)};
        buffer.payload = .{ .data = .{
            .names = &buffer.names,
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
        .local, .new_local => |l| l,
        else => return,
    };
    try freeLocal(f, inst, local_index, ref_inst);
}

fn freeLocal(f: *Function, inst: Air.Inst.Index, local_index: LocalIndex, ref_inst: Air.Inst.Index) !void {
    const gpa = f.object.dg.gpa;
    const local = &f.locals.items[local_index];
    log.debug("%{d}: freeing t{d} (operand %{d})", .{ inst, local_index, ref_inst });
    if (local.loop_depth < f.free_locals_clone_depth) return;
    const gop = try f.free_locals_stack.items[local.loop_depth].getOrPut(gpa, local.getType());
    if (!gop.found_existing) gop.value_ptr.* = .{};
    if (std.debug.runtime_safety) {
        // If this trips, an unfreeable allocation was attempted to be freed.
        assert(!f.allocs.contains(local_index));
    }
    // If this trips, it means a local is being inserted into the
    // free_locals map while it already exists in the map, which is not
    // allowed.
    try gop.value_ptr.putNoClobber(gpa, local_index, {});
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

fn noticeBranchFrees(
    f: *Function,
    pre_locals_len: LocalIndex,
    pre_allocs_len: LocalIndex,
    inst: Air.Inst.Index,
) !void {
    const free_locals = f.getFreeLocals();

    for (f.locals.items[pre_locals_len..], pre_locals_len..) |*local, local_i| {
        const local_index = @intCast(LocalIndex, local_i);
        if (f.allocs.contains(local_index)) {
            if (std.debug.runtime_safety) {
                // new allocs are no longer freeable, so make sure they aren't in the free list
                if (free_locals.getPtr(local.getType())) |locals_list| {
                    assert(!locals_list.contains(local_index));
                }
            }
            continue;
        }

        // free more deeply nested locals from other branches at current depth
        assert(local.loop_depth >= f.free_locals_stack.items.len - 1);
        local.loop_depth = @intCast(LoopDepth, f.free_locals_stack.items.len - 1);
        try freeLocal(f, inst, local_index, 0);
    }

    for (f.allocs.keys()[pre_allocs_len..]) |local_i| {
        const local_index = @intCast(LocalIndex, local_i);
        const local = &f.locals.items[local_index];
        // new allocs are no longer freeable, so remove them from the free list
        if (free_locals.getPtr(local.getType())) |locals_list| _ = locals_list.swapRemove(local_index);
    }
}
