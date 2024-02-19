const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const mem = std.mem;
const log = std.log.scoped(.c);

const link = @import("../link.zig");
const Module = @import("../Module.zig");
const Compilation = @import("../Compilation.zig");
const Value = @import("../Value.zig");
const Type = @import("../type.zig").Type;
const TypedValue = @import("../TypedValue.zig");
const C = link.File.C;
const Decl = Module.Decl;
const trace = @import("../tracy.zig").trace;
const LazySrcLoc = Module.LazySrcLoc;
const Air = @import("../Air.zig");
const Liveness = @import("../Liveness.zig");
const InternPool = @import("../InternPool.zig");
const Alignment = InternPool.Alignment;

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
    constant: InternPool.Index,
    /// Index into the parameters
    arg: usize,
    /// The array field of a parameter
    arg_array: usize,
    /// Index into a tuple's fields
    field: usize,
    /// By-value
    decl: InternPool.DeclIndex,
    decl_ref: InternPool.DeclIndex,
    /// An undefined value (cannot be dereferenced)
    undef: Type,
    /// Render the slice as an identifier (using fmtIdent)
    identifier: []const u8,
    /// Render the slice as an payload.identifier (using fmtIdent)
    payload_identifier: []const u8,
};

const BlockData = struct {
    block_id: usize,
    result: CValue,
};

pub const CValueMap = std.AutoHashMap(Air.Inst.Ref, CValue);

pub const LazyFnKey = union(enum) {
    tag_name: InternPool.DeclIndex,
    never_tail: InternPool.DeclIndex,
    never_inline: InternPool.DeclIndex,
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
    alignas: CType.AlignAs,

    pub fn getType(local: Local) LocalType {
        return .{ .cty_idx = local.cty_idx, .alignas = local.alignas };
    }
};

const LocalIndex = u16;
const LocalType = struct { cty_idx: CType.Index, alignas: CType.AlignAs };
const LocalsList = std.AutoArrayHashMapUnmanaged(LocalIndex, void);
const LocalsMap = std.AutoArrayHashMapUnmanaged(LocalType, LocalsList);

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

const BuiltinInfo = enum { none, bits };

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
    .{ "extern", {} },
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
    .{ "while", {} },

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
    } else if (mem.startsWith(u8, ident, "DUMMYSTRUCTNAME") or
        mem.startsWith(u8, ident, "DUMMYUNIONNAME"))
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

// Returns true if `formatIdent` would make any edits to ident.
// This must be kept in sync with `formatIdent`.
pub fn isMangledIdent(ident: []const u8, solo: bool) bool {
    if (solo and isReservedIdent(ident)) return true;
    for (ident, 0..) |c, i| {
        switch (c) {
            'a'...'z', 'A'...'Z', '_' => {},
            '0'...'9' => if (i == 0) return true,
            else => return true,
        }
    }
    return false;
}

/// This data is available when outputting .c code for a `InternPool.Index`
/// that corresponds to `func`.
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
    func_index: InternPool.Index,
    /// All the locals, to be emitted at the top of the function.
    locals: std.ArrayListUnmanaged(Local) = .{},
    /// Which locals are available for reuse, based on Type.
    free_locals_map: LocalsMap = .{},
    /// Locals which will not be freed by Liveness. This is used after a
    /// Function body is lowered in order to make `free_locals_map` have
    /// 100% of the locals within so that it can be used to render the block
    /// of variable declarations at the top of a function, sorted descending
    /// by type alignment.
    /// The value is whether the alloc needs to be emitted in the header.
    allocs: std.AutoArrayHashMapUnmanaged(LocalIndex, bool) = .{},

    fn resolveInst(f: *Function, ref: Air.Inst.Ref) !CValue {
        const gop = try f.value_map.getOrPut(ref);
        if (gop.found_existing) return gop.value_ptr.*;

        const mod = f.object.dg.module;
        const val = (try f.air.value(ref, mod)).?;
        const ty = f.typeOf(ref);

        const result: CValue = if (lowersToArray(ty, mod)) result: {
            const writer = f.object.codeHeaderWriter();
            const alignment: Alignment = .none;
            const decl_c_value = try f.allocLocalValue(ty, alignment);
            const gpa = f.object.dg.gpa;
            try f.allocs.put(gpa, decl_c_value.new_local, false);
            try writer.writeAll("static ");
            try f.object.dg.renderTypeAndName(writer, ty, decl_c_value, Const, alignment, .complete);
            try writer.writeAll(" = ");
            try f.object.dg.renderValue(writer, ty, val, .StaticInitializer);
            try writer.writeAll(";\n ");
            break :result decl_c_value;
        } else .{ .constant = val.toIntern() };

        gop.value_ptr.* = result;
        return result;
    }

    fn wantSafety(f: *Function) bool {
        return switch (f.object.dg.module.optimizeMode()) {
            .Debug, .ReleaseSafe => true,
            .ReleaseFast, .ReleaseSmall => false,
        };
    }

    /// Skips the reuse logic. This function should be used for any persistent allocation, i.e.
    /// those which go into `allocs`. This function does not add the resulting local into `allocs`;
    /// that responsibility lies with the caller.
    fn allocLocalValue(f: *Function, ty: Type, alignment: Alignment) !CValue {
        const mod = f.object.dg.module;
        const gpa = f.object.dg.gpa;
        try f.locals.append(gpa, .{
            .cty_idx = try f.typeToIndex(ty, .complete),
            .alignas = CType.AlignAs.init(alignment, ty.abiAlignment(mod)),
        });
        return .{ .new_local = @intCast(f.locals.items.len - 1) };
    }

    fn allocLocal(f: *Function, inst: ?Air.Inst.Index, ty: Type) !CValue {
        const result = try f.allocAlignedLocal(ty, .{}, .none);
        if (inst) |i| {
            log.debug("%{d}: allocating t{d}", .{ i, result.new_local });
        } else {
            log.debug("allocating t{d}", .{result.new_local});
        }
        return result;
    }

    /// Only allocates the local; does not print anything. Will attempt to re-use locals, so should
    /// not be used for persistent locals (i.e. those in `allocs`).
    fn allocAlignedLocal(f: *Function, ty: Type, _: CQualifiers, alignment: Alignment) !CValue {
        const mod = f.object.dg.module;
        if (f.free_locals_map.getPtr(.{
            .cty_idx = try f.typeToIndex(ty, .complete),
            .alignas = CType.AlignAs.init(alignment, ty.abiAlignment(mod)),
        })) |locals_list| {
            if (locals_list.popOrNull()) |local_entry| {
                return .{ .new_local = local_entry.key };
            }
        }

        return try f.allocLocalValue(ty, alignment);
    }

    fn writeCValue(f: *Function, w: anytype, c_value: CValue, location: ValueRenderLocation) !void {
        switch (c_value) {
            .constant => |val| try f.object.dg.renderValue(
                w,
                Type.fromInterned(f.object.dg.module.intern_pool.typeOf(val)),
                Value.fromInterned(val),
                location,
            ),
            .undef => |ty| try f.object.dg.renderValue(w, ty, Value.undef, location),
            else => try f.object.dg.writeCValue(w, c_value),
        }
    }

    fn writeCValueDeref(f: *Function, w: anytype, c_value: CValue) !void {
        switch (c_value) {
            .constant => |val| {
                try w.writeAll("(*");
                try f.object.dg.renderValue(
                    w,
                    Type.fromInterned(f.object.dg.module.intern_pool.typeOf(val)),
                    Value.fromInterned(val),
                    .Other,
                );
                try w.writeByte(')');
            },
            else => try f.object.dg.writeCValueDeref(w, c_value),
        }
    }

    fn writeCValueMember(f: *Function, w: anytype, c_value: CValue, member: CValue) !void {
        switch (c_value) {
            .constant => |val| {
                try f.object.dg.renderValue(
                    w,
                    Type.fromInterned(f.object.dg.module.intern_pool.typeOf(val)),
                    Value.fromInterned(val),
                    .Other,
                );
                try w.writeByte('.');
                try f.writeCValue(w, member, .Other);
            },
            else => try f.object.dg.writeCValueMember(w, c_value, member),
        }
    }

    fn writeCValueDerefMember(f: *Function, w: anytype, c_value: CValue, member: CValue) !void {
        switch (c_value) {
            .constant => |val| {
                try w.writeByte('(');
                try f.object.dg.renderValue(
                    w,
                    Type.fromInterned(f.object.dg.module.intern_pool.typeOf(val)),
                    Value.fromInterned(val),
                    .Other,
                );
                try w.writeAll(")->");
                try f.writeCValue(w, member, .Other);
            },
            else => try f.object.dg.writeCValueDerefMember(w, c_value, member),
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

    fn byteSize(f: *Function, cty: CType) u64 {
        return f.object.dg.byteSize(cty);
    }

    fn renderType(f: *Function, w: anytype, t: Type) !void {
        return f.object.dg.renderType(w, t);
    }

    fn renderCType(f: *Function, w: anytype, t: CType.Index) !void {
        return f.object.dg.renderCType(w, t);
    }

    fn renderIntCast(f: *Function, w: anytype, dest_ty: Type, src: CValue, v: Vectorize, src_ty: Type, location: ValueRenderLocation) !void {
        return f.object.dg.renderIntCast(w, dest_ty, .{ .c_value = .{ .f = f, .value = src, .v = v } }, src_ty, location);
    }

    fn fmtIntLiteral(f: *Function, ty: Type, val: Value) !std.fmt.Formatter(formatIntLiteral) {
        return f.object.dg.fmtIntLiteral(ty, val, .Other);
    }

    fn getLazyFnName(f: *Function, key: LazyFnKey, data: LazyFnValue.Data) ![]const u8 {
        const gpa = f.object.dg.gpa;
        const gop = try f.lazy_fns.getOrPut(gpa, key);
        if (!gop.found_existing) {
            errdefer _ = f.lazy_fns.pop();

            var promoted = f.object.dg.ctypes.promote(gpa);
            defer f.object.dg.ctypes.demote(promoted);
            const arena = promoted.arena.allocator();
            const mod = f.object.dg.module;

            gop.value_ptr.* = .{
                .fn_name = switch (key) {
                    .tag_name,
                    .never_tail,
                    .never_inline,
                    => |owner_decl| try std.fmt.allocPrint(arena, "zig_{s}_{}__{d}", .{
                        @tagName(key),
                        fmtIdent(mod.intern_pool.stringToSlice(mod.declPtr(owner_decl).name)),
                        @intFromEnum(owner_decl),
                    }),
                },
                .data = switch (key) {
                    .tag_name => .{ .tag_name = data.tag_name },
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
        deinitFreeLocalsMap(gpa, &f.free_locals_map);
        f.blocks.deinit(gpa);
        f.value_map.deinit();
        f.lazy_fns.deinit(gpa);
        f.object.dg.ctypes.deinit(gpa);
    }

    fn typeOf(f: *Function, inst: Air.Inst.Ref) Type {
        const mod = f.object.dg.module;
        return f.air.typeOf(inst, &mod.intern_pool);
    }

    fn typeOfIndex(f: *Function, inst: Air.Inst.Index) Type {
        const mod = f.object.dg.module;
        return f.air.typeOfIndex(inst, &mod.intern_pool);
    }
};

/// This data is available when outputting .c code for a `Module`.
/// It is not available when generating .h file.
pub const Object = struct {
    dg: DeclGen,
    /// This is a borrowed reference from `link.C`.
    code: std.ArrayList(u8),
    /// Goes before code. Initialized and deinitialized in `genFunc`.
    code_header: std.ArrayList(u8) = undefined,
    indent_writer: IndentWriter(std.ArrayList(u8).Writer),

    fn writer(o: *Object) IndentWriter(std.ArrayList(u8).Writer).Writer {
        return o.indent_writer.writer();
    }

    fn codeHeaderWriter(o: *Object) ArrayListWriter {
        return arrayListWriter(&o.code_header);
    }
};

/// This data is available both when outputting .c code and when outputting an .h file.
pub const DeclGen = struct {
    gpa: mem.Allocator,
    module: *Module,
    pass: Pass,
    is_naked_fn: bool,
    /// This is a borrowed reference from `link.C`.
    fwd_decl: std.ArrayList(u8),
    error_msg: ?*Module.ErrorMsg,
    ctypes: CType.Store,
    /// Keeps track of anonymous decls that need to be rendered before this
    /// (named) Decl in the output C code.
    anon_decl_deps: std.AutoArrayHashMapUnmanaged(InternPool.Index, C.DeclBlock),
    aligned_anon_decls: std.AutoArrayHashMapUnmanaged(InternPool.Index, Alignment),

    pub const Pass = union(enum) {
        decl: InternPool.DeclIndex,
        anon: InternPool.Index,
        flush,
    };

    fn fwdDeclWriter(dg: *DeclGen) ArrayListWriter {
        return arrayListWriter(&dg.fwd_decl);
    }

    fn fail(dg: *DeclGen, comptime format: []const u8, args: anytype) error{ AnalysisFail, OutOfMemory } {
        @setCold(true);
        const mod = dg.module;
        const decl_index = dg.pass.decl;
        const decl = mod.declPtr(decl_index);
        const src = LazySrcLoc.nodeOffset(0);
        const src_loc = src.toSrcLoc(decl, mod);
        dg.error_msg = try Module.ErrorMsg.create(dg.gpa, src_loc, format, args);
        return error.AnalysisFail;
    }

    fn renderAnonDeclValue(
        dg: *DeclGen,
        writer: anytype,
        ty: Type,
        ptr_val: Value,
        anon_decl: InternPool.Key.Ptr.Addr.AnonDecl,
        location: ValueRenderLocation,
    ) error{ OutOfMemory, AnalysisFail }!void {
        const mod = dg.module;
        const ip = &mod.intern_pool;
        const decl_val = anon_decl.val;
        const decl_ty = Type.fromInterned(ip.typeOf(decl_val));

        // Render an undefined pointer if we have a pointer to a zero-bit or comptime type.
        if (ty.isPtrAtRuntime(mod) and !decl_ty.isFnOrHasRuntimeBits(mod)) {
            return dg.writeCValue(writer, .{ .undef = ty });
        }

        // Chase function values in order to be able to reference the original function.
        if (Value.fromInterned(decl_val).getFunction(mod)) |func| {
            _ = func;
            _ = ptr_val;
            _ = location;
            @panic("TODO");
        }
        if (Value.fromInterned(decl_val).getExternFunc(mod)) |extern_func| {
            _ = extern_func;
            _ = ptr_val;
            _ = location;
            @panic("TODO");
        }

        assert(Value.fromInterned(decl_val).getVariable(mod) == null);

        // We shouldn't cast C function pointers as this is UB (when you call
        // them).  The analysis until now should ensure that the C function
        // pointers are compatible.  If they are not, then there is a bug
        // somewhere and we should let the C compiler tell us about it.
        const need_typecast = if (ty.castPtrToFn(mod)) |_| false else !ty.childType(mod).eql(decl_ty, mod);
        if (need_typecast) {
            try writer.writeAll("((");
            try dg.renderType(writer, ty);
            try writer.writeByte(')');
        }
        try writer.writeByte('&');
        try renderAnonDeclName(writer, decl_val);
        if (need_typecast) try writer.writeByte(')');

        // Indicate that the anon decl should be rendered to the output so that
        // our reference above is not undefined.
        const ptr_type = ip.indexToKey(anon_decl.orig_ty).ptr_type;
        const gop = try dg.anon_decl_deps.getOrPut(dg.gpa, decl_val);
        if (!gop.found_existing) gop.value_ptr.* = .{};

        // Only insert an alignment entry if the alignment is greater than ABI
        // alignment. If there is already an entry, keep the greater alignment.
        const explicit_alignment = ptr_type.flags.alignment;
        if (explicit_alignment != .none) {
            const abi_alignment = Type.fromInterned(ptr_type.child).abiAlignment(mod);
            if (explicit_alignment.compareStrict(.gt, abi_alignment)) {
                const aligned_gop = try dg.aligned_anon_decls.getOrPut(dg.gpa, decl_val);
                aligned_gop.value_ptr.* = if (aligned_gop.found_existing)
                    aligned_gop.value_ptr.maxStrict(explicit_alignment)
                else
                    explicit_alignment;
            }
        }
    }

    fn renderDeclValue(
        dg: *DeclGen,
        writer: anytype,
        ty: Type,
        val: Value,
        decl_index: InternPool.DeclIndex,
        location: ValueRenderLocation,
    ) error{ OutOfMemory, AnalysisFail }!void {
        const mod = dg.module;
        const decl = mod.declPtr(decl_index);
        assert(decl.has_tv);

        // Render an undefined pointer if we have a pointer to a zero-bit or comptime type.
        if (ty.isPtrAtRuntime(mod) and !decl.ty.isFnOrHasRuntimeBits(mod)) {
            return dg.writeCValue(writer, .{ .undef = ty });
        }

        // Chase function values in order to be able to reference the original function.
        if (decl.val.getFunction(mod)) |func| if (func.owner_decl != decl_index)
            return dg.renderDeclValue(writer, ty, val, func.owner_decl, location);
        if (decl.val.getExternFunc(mod)) |extern_func| if (extern_func.decl != decl_index)
            return dg.renderDeclValue(writer, ty, val, extern_func.decl, location);

        if (decl.val.getVariable(mod)) |variable| try dg.renderFwdDecl(decl_index, variable, .tentative);

        // We shouldn't cast C function pointers as this is UB (when you call
        // them).  The analysis until now should ensure that the C function
        // pointers are compatible.  If they are not, then there is a bug
        // somewhere and we should let the C compiler tell us about it.
        const need_typecast = if (ty.castPtrToFn(mod)) |_| false else !ty.childType(mod).eql(decl.ty, mod);
        if (need_typecast) {
            try writer.writeAll("((");
            try dg.renderType(writer, ty);
            try writer.writeByte(')');
        }
        try writer.writeByte('&');
        try dg.renderDeclName(writer, decl_index, 0);
        if (need_typecast) try writer.writeByte(')');
    }

    /// Renders a "parent" pointer by recursing to the root decl/variable
    /// that its contents are defined with respect to.
    fn renderParentPtr(
        dg: *DeclGen,
        writer: anytype,
        ptr_val: InternPool.Index,
        location: ValueRenderLocation,
    ) error{ OutOfMemory, AnalysisFail }!void {
        const mod = dg.module;
        const ptr_ty = Type.fromInterned(mod.intern_pool.typeOf(ptr_val));
        const ptr_cty = try dg.typeToIndex(ptr_ty, .complete);
        const ptr = mod.intern_pool.indexToKey(ptr_val).ptr;
        switch (ptr.addr) {
            .decl => |d| try dg.renderDeclValue(writer, ptr_ty, Value.fromInterned(ptr_val), d, location),
            .mut_decl => |md| try dg.renderDeclValue(writer, ptr_ty, Value.fromInterned(ptr_val), md.decl, location),
            .anon_decl => |anon_decl| try dg.renderAnonDeclValue(writer, ptr_ty, Value.fromInterned(ptr_val), anon_decl, location),
            .int => |int| {
                try writer.writeByte('(');
                try dg.renderCType(writer, ptr_cty);
                try writer.print("){x}", .{try dg.fmtIntLiteral(Type.usize, Value.fromInterned(int), .Other)});
            },
            .eu_payload, .opt_payload => |base| {
                const ptr_base_ty = Type.fromInterned(mod.intern_pool.typeOf(base));
                const base_ty = ptr_base_ty.childType(mod);
                // Ensure complete type definition is visible before accessing fields.
                _ = try dg.typeToIndex(base_ty, .complete);
                const payload_ty = switch (ptr.addr) {
                    .eu_payload => base_ty.errorUnionPayload(mod),
                    .opt_payload => base_ty.optionalChild(mod),
                    else => unreachable,
                };
                const ptr_payload_ty = try mod.adjustPtrTypeChild(ptr_base_ty, payload_ty);
                const ptr_payload_cty = try dg.typeToIndex(ptr_payload_ty, .complete);
                if (ptr_cty != ptr_payload_cty) {
                    try writer.writeByte('(');
                    try dg.renderCType(writer, ptr_cty);
                    try writer.writeByte(')');
                }
                try writer.writeAll("&(");
                try dg.renderParentPtr(writer, base, location);
                try writer.writeAll(")->payload");
            },
            .elem => |elem| {
                const ptr_base_ty = Type.fromInterned(mod.intern_pool.typeOf(elem.base));
                const elem_ty = ptr_base_ty.elemType2(mod);
                const ptr_elem_ty = try mod.adjustPtrTypeChild(ptr_base_ty, elem_ty);
                const ptr_elem_cty = try dg.typeToIndex(ptr_elem_ty, .complete);
                if (ptr_cty != ptr_elem_cty) {
                    try writer.writeByte('(');
                    try dg.renderCType(writer, ptr_cty);
                    try writer.writeByte(')');
                }
                try writer.writeAll("&(");
                if (mod.intern_pool.indexToKey(ptr_base_ty.toIntern()).ptr_type.flags.size == .One)
                    try writer.writeByte('*');
                try dg.renderParentPtr(writer, elem.base, location);
                try writer.print(")[{d}]", .{elem.index});
            },
            .field => |field| {
                const ptr_base_ty = Type.fromInterned(mod.intern_pool.typeOf(field.base));
                const base_ty = ptr_base_ty.childType(mod);
                // Ensure complete type definition is visible before accessing fields.
                _ = try dg.typeToIndex(base_ty, .complete);
                const field_ty = switch (mod.intern_pool.indexToKey(base_ty.toIntern())) {
                    .anon_struct_type, .struct_type, .union_type => base_ty.structFieldType(@as(usize, @intCast(field.index)), mod),
                    .ptr_type => |ptr_type| switch (ptr_type.flags.size) {
                        .One, .Many, .C => unreachable,
                        .Slice => switch (field.index) {
                            Value.slice_ptr_index => base_ty.slicePtrFieldType(mod),
                            Value.slice_len_index => Type.usize,
                            else => unreachable,
                        },
                    },
                    else => unreachable,
                };
                const ptr_field_ty = try mod.adjustPtrTypeChild(ptr_base_ty, field_ty);
                const ptr_field_cty = try dg.typeToIndex(ptr_field_ty, .complete);
                if (ptr_cty != ptr_field_cty) {
                    try writer.writeByte('(');
                    try dg.renderCType(writer, ptr_cty);
                    try writer.writeByte(')');
                }
                switch (fieldLocation(ptr_base_ty, ptr_ty, @as(u32, @intCast(field.index)), mod)) {
                    .begin => try dg.renderParentPtr(writer, field.base, location),
                    .field => |name| {
                        try writer.writeAll("&(");
                        try dg.renderParentPtr(writer, field.base, location);
                        try writer.writeAll(")->");
                        try dg.writeCValue(writer, name);
                    },
                    .byte_offset => |byte_offset| {
                        const u8_ptr_ty = try mod.adjustPtrTypeChild(ptr_ty, Type.u8);
                        const byte_offset_val = try mod.intValue(Type.usize, byte_offset);

                        try writer.writeAll("((");
                        try dg.renderType(writer, u8_ptr_ty);
                        try writer.writeByte(')');
                        try dg.renderParentPtr(writer, field.base, location);
                        try writer.print(" + {})", .{
                            try dg.fmtIntLiteral(Type.usize, byte_offset_val, .Other),
                        });
                    },
                    .end => {
                        try writer.writeAll("((");
                        try dg.renderParentPtr(writer, field.base, location);
                        try writer.print(") + {})", .{
                            try dg.fmtIntLiteral(Type.usize, try mod.intValue(Type.usize, 1), .Other),
                        });
                    },
                }
            },
            .comptime_field => unreachable,
        }
    }

    fn renderValue(
        dg: *DeclGen,
        writer: anytype,
        ty: Type,
        val: Value,
        location: ValueRenderLocation,
    ) error{ OutOfMemory, AnalysisFail }!void {
        const mod = dg.module;
        const ip = &mod.intern_pool;

        const target = mod.getTarget();
        const initializer_type: ValueRenderLocation = switch (location) {
            .StaticInitializer => .StaticInitializer,
            else => .Initializer,
        };

        const safety_on = switch (mod.optimizeMode()) {
            .Debug, .ReleaseSafe => true,
            .ReleaseFast, .ReleaseSmall => false,
        };

        if (val.isUndefDeep(mod)) {
            switch (ty.zigTypeTag(mod)) {
                .Bool => {
                    if (safety_on) {
                        return writer.writeAll("0xaa");
                    } else {
                        return writer.writeAll("false");
                    }
                },
                .Int, .Enum, .ErrorSet => return writer.print("{x}", .{try dg.fmtIntLiteral(ty, val, location)}),
                .Float => {
                    const bits = ty.floatBits(target);
                    // All unsigned ints matching float types are pre-allocated.
                    const repr_ty = mod.intType(.unsigned, bits) catch unreachable;

                    try writer.writeAll("zig_make_");
                    try dg.renderTypeForBuiltinFnName(writer, ty);
                    try writer.writeByte('(');
                    switch (bits) {
                        16 => try writer.print("{x}", .{@as(f16, @bitCast(undefPattern(i16)))}),
                        32 => try writer.print("{x}", .{@as(f32, @bitCast(undefPattern(i32)))}),
                        64 => try writer.print("{x}", .{@as(f64, @bitCast(undefPattern(i64)))}),
                        80 => try writer.print("{x}", .{@as(f80, @bitCast(undefPattern(i80)))}),
                        128 => try writer.print("{x}", .{@as(f128, @bitCast(undefPattern(i128)))}),
                        else => unreachable,
                    }
                    try writer.writeAll(", ");
                    try dg.renderValue(writer, repr_ty, Value.undef, .FunctionArgument);
                    return writer.writeByte(')');
                },
                .Pointer => if (ty.isSlice(mod)) {
                    if (!location.isInitializer()) {
                        try writer.writeByte('(');
                        try dg.renderType(writer, ty);
                        try writer.writeByte(')');
                    }

                    try writer.writeAll("{(");
                    const ptr_ty = ty.slicePtrFieldType(mod);
                    try dg.renderType(writer, ptr_ty);
                    return writer.print("){x}, {0x}}}", .{try dg.fmtIntLiteral(Type.usize, val, .Other)});
                } else {
                    try writer.writeAll("((");
                    try dg.renderType(writer, ty);
                    return writer.print("){x})", .{try dg.fmtIntLiteral(Type.usize, val, .Other)});
                },
                .Optional => {
                    const payload_ty = ty.optionalChild(mod);

                    if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                        return dg.renderValue(writer, Type.bool, val, location);
                    }

                    if (ty.optionalReprIsPayload(mod)) {
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
                .Struct => switch (ty.containerLayout(mod)) {
                    .Auto, .Extern => {
                        if (!location.isInitializer()) {
                            try writer.writeByte('(');
                            try dg.renderType(writer, ty);
                            try writer.writeByte(')');
                        }

                        try writer.writeByte('{');
                        var empty = true;
                        for (0..ty.structFieldCount(mod)) |field_index| {
                            if (ty.structFieldIsComptime(field_index, mod)) continue;
                            const field_ty = ty.structFieldType(field_index, mod);
                            if (!field_ty.hasRuntimeBits(mod)) continue;

                            if (!empty) try writer.writeByte(',');
                            try dg.renderValue(writer, field_ty, val, initializer_type);

                            empty = false;
                        }

                        return writer.writeByte('}');
                    },
                    .Packed => return writer.print("{x}", .{try dg.fmtIntLiteral(ty, Value.undef, .Other)}),
                },
                .Union => {
                    if (!location.isInitializer()) {
                        try writer.writeByte('(');
                        try dg.renderType(writer, ty);
                        try writer.writeByte(')');
                    }

                    try writer.writeByte('{');
                    if (ty.unionTagTypeSafety(mod)) |tag_ty| {
                        const layout = ty.unionGetLayout(mod);
                        if (layout.tag_size != 0) {
                            try writer.writeAll(" .tag = ");
                            try dg.renderValue(writer, tag_ty, val, initializer_type);
                        }
                        if (ty.unionHasAllZeroBitFieldTypes(mod)) return try writer.writeByte('}');
                        if (layout.tag_size != 0) try writer.writeByte(',');
                        try writer.writeAll(" .payload = {");
                    }
                    const union_obj = mod.typeToUnion(ty).?;
                    for (0..union_obj.field_types.len) |field_index| {
                        const field_ty = Type.fromInterned(union_obj.field_types.get(ip)[field_index]);
                        if (!field_ty.hasRuntimeBits(mod)) continue;
                        try dg.renderValue(writer, field_ty, val, initializer_type);
                        break;
                    }
                    if (ty.unionTagTypeSafety(mod)) |_| try writer.writeByte('}');
                    return writer.writeByte('}');
                },
                .ErrorUnion => {
                    const payload_ty = ty.errorUnionPayload(mod);
                    const error_ty = ty.errorUnionSet(mod);

                    if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                        return dg.renderValue(writer, error_ty, val, location);
                    }

                    if (!location.isInitializer()) {
                        try writer.writeByte('(');
                        try dg.renderType(writer, ty);
                        try writer.writeByte(')');
                    }

                    try writer.writeAll("{ .payload = ");
                    try dg.renderValue(writer, payload_ty, val, initializer_type);
                    try writer.writeAll(", .error = ");
                    try dg.renderValue(writer, error_ty, val, initializer_type);
                    return writer.writeAll(" }");
                },
                .Array, .Vector => {
                    const ai = ty.arrayInfo(mod);
                    if (ai.elem_type.eql(Type.u8, mod)) {
                        var literal = stringLiteral(writer);
                        try literal.start();
                        const c_len = ty.arrayLenIncludingSentinel(mod);
                        var index: u64 = 0;
                        while (index < c_len) : (index += 1)
                            try literal.writeChar(0xaa);
                        return literal.end();
                    } else {
                        if (!location.isInitializer()) {
                            try writer.writeByte('(');
                            try dg.renderType(writer, ty);
                            try writer.writeByte(')');
                        }

                        try writer.writeByte('{');
                        const c_len = ty.arrayLenIncludingSentinel(mod);
                        var index: u64 = 0;
                        while (index < c_len) : (index += 1) {
                            if (index > 0) try writer.writeAll(", ");
                            try dg.renderValue(writer, ty.childType(mod), val, initializer_type);
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

        switch (ip.indexToKey(val.ip_index)) {
            // types, not values
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
            // memoization, not values
            .memoized_call,
            => unreachable,

            .undef => unreachable, // handled above
            .simple_value => |simple_value| switch (simple_value) {
                // non-runtime values
                .undefined => unreachable,
                .void => unreachable,
                .null => unreachable,
                .empty_struct => unreachable,
                .@"unreachable" => unreachable,
                .generic_poison => unreachable,

                .false => try writer.writeAll("false"),
                .true => try writer.writeAll("true"),
            },
            .variable,
            .extern_func,
            .func,
            .enum_literal,
            .empty_enum_value,
            => unreachable, // non-runtime values
            .int => |int| switch (int.storage) {
                .u64, .i64, .big_int => try writer.print("{}", .{try dg.fmtIntLiteral(ty, val, location)}),
                .lazy_align, .lazy_size => {
                    try writer.writeAll("((");
                    try dg.renderType(writer, ty);
                    return writer.print("){x})", .{try dg.fmtIntLiteral(Type.usize, val, .Other)});
                },
            },
            .err => |err| try writer.print("zig_error_{}", .{
                fmtIdent(ip.stringToSlice(err.name)),
            }),
            .error_union => |error_union| {
                const payload_ty = ty.errorUnionPayload(mod);
                const error_ty = ty.errorUnionSet(mod);
                const err_int_ty = try mod.errorIntType();
                if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                    switch (error_union.val) {
                        .err_name => |err_name| return dg.renderValue(
                            writer,
                            error_ty,
                            Value.fromInterned((try mod.intern(.{ .err = .{
                                .ty = error_ty.toIntern(),
                                .name = err_name,
                            } }))),
                            location,
                        ),
                        .payload => return dg.renderValue(
                            writer,
                            err_int_ty,
                            try mod.intValue(err_int_ty, 0),
                            location,
                        ),
                    }
                }

                if (!location.isInitializer()) {
                    try writer.writeByte('(');
                    try dg.renderType(writer, ty);
                    try writer.writeByte(')');
                }

                try writer.writeAll("{ .payload = ");
                try dg.renderValue(
                    writer,
                    payload_ty,
                    Value.fromInterned(switch (error_union.val) {
                        .err_name => try mod.intern(.{ .undef = payload_ty.ip_index }),
                        .payload => |payload| payload,
                    }),
                    initializer_type,
                );
                try writer.writeAll(", .error = ");
                switch (error_union.val) {
                    .err_name => |err_name| try dg.renderValue(
                        writer,
                        error_ty,
                        Value.fromInterned((try mod.intern(.{ .err = .{
                            .ty = error_ty.toIntern(),
                            .name = err_name,
                        } }))),
                        location,
                    ),
                    .payload => try dg.renderValue(
                        writer,
                        err_int_ty,
                        try mod.intValue(err_int_ty, 0),
                        location,
                    ),
                }
                try writer.writeAll(" }");
            },
            .enum_tag => {
                const enum_tag = ip.indexToKey(val.ip_index).enum_tag;
                const int_tag_ty = ip.typeOf(enum_tag.int);
                try dg.renderValue(writer, Type.fromInterned(int_tag_ty), Value.fromInterned(enum_tag.int), location);
            },
            .float => {
                const bits = ty.floatBits(target);
                const f128_val = val.toFloat(f128, mod);

                // All unsigned ints matching float types are pre-allocated.
                const repr_ty = mod.intType(.unsigned, bits) catch unreachable;

                assert(bits <= 128);
                var repr_val_limbs: [BigInt.calcTwosCompLimbCount(128)]BigIntLimb = undefined;
                var repr_val_big = BigInt.Mutable{
                    .limbs = &repr_val_limbs,
                    .len = undefined,
                    .positive = undefined,
                };

                switch (bits) {
                    16 => repr_val_big.set(@as(u16, @bitCast(val.toFloat(f16, mod)))),
                    32 => repr_val_big.set(@as(u32, @bitCast(val.toFloat(f32, mod)))),
                    64 => repr_val_big.set(@as(u64, @bitCast(val.toFloat(f64, mod)))),
                    80 => repr_val_big.set(@as(u80, @bitCast(val.toFloat(f80, mod)))),
                    128 => repr_val_big.set(@as(u128, @bitCast(f128_val))),
                    else => unreachable,
                }

                const repr_val = try mod.intValue_big(repr_ty, repr_val_big.toConst());

                var empty = true;
                if (std.math.isFinite(f128_val)) {
                    try writer.writeAll("zig_make_");
                    try dg.renderTypeForBuiltinFnName(writer, ty);
                    try writer.writeByte('(');
                    switch (bits) {
                        16 => try writer.print("{x}", .{val.toFloat(f16, mod)}),
                        32 => try writer.print("{x}", .{val.toFloat(f32, mod)}),
                        64 => try writer.print("{x}", .{val.toFloat(f64, mod)}),
                        80 => try writer.print("{x}", .{val.toFloat(f80, mod)}),
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
                        // if (std.math.isNan(f128_val) and f128_val != std.math.nan(f128))
                        //     return dg.fail("Only quiet nans are supported in global variable initializers", .{});
                    }

                    try writer.writeAll("zig_");
                    try writer.writeAll(if (location == .StaticInitializer) "init" else "make");
                    try writer.writeAll("_special_");
                    try dg.renderTypeForBuiltinFnName(writer, ty);
                    try writer.writeByte('(');
                    if (std.math.signbit(f128_val)) try writer.writeByte('-');
                    try writer.writeAll(", ");
                    try writer.writeAll(operation);
                    try writer.writeAll(", ");
                    if (std.math.isNan(f128_val)) switch (bits) {
                        // We only actually need to pass the significand, but it will get
                        // properly masked anyway, so just pass the whole value.
                        16 => try writer.print("\"0x{x}\"", .{@as(u16, @bitCast(val.toFloat(f16, mod)))}),
                        32 => try writer.print("\"0x{x}\"", .{@as(u32, @bitCast(val.toFloat(f32, mod)))}),
                        64 => try writer.print("\"0x{x}\"", .{@as(u64, @bitCast(val.toFloat(f64, mod)))}),
                        80 => try writer.print("\"0x{x}\"", .{@as(u80, @bitCast(val.toFloat(f80, mod)))}),
                        128 => try writer.print("\"0x{x}\"", .{@as(u128, @bitCast(f128_val))}),
                        else => unreachable,
                    };
                    try writer.writeAll(", ");
                    empty = false;
                }
                try writer.print("{x}", .{try dg.fmtIntLiteral(repr_ty, repr_val, location)});
                if (!empty) try writer.writeByte(')');
            },
            .slice => |slice| {
                if (!location.isInitializer()) {
                    try writer.writeByte('(');
                    try dg.renderType(writer, ty);
                    try writer.writeByte(')');
                }
                try writer.writeByte('{');
                try dg.renderValue(writer, ty.slicePtrFieldType(mod), Value.fromInterned(slice.ptr), initializer_type);
                try writer.writeAll(", ");
                try dg.renderValue(writer, Type.usize, Value.fromInterned(slice.len), initializer_type);
                try writer.writeByte('}');
            },
            .ptr => |ptr| switch (ptr.addr) {
                .decl => |d| try dg.renderDeclValue(writer, ty, val, d, location),
                .mut_decl => |md| try dg.renderDeclValue(writer, ty, val, md.decl, location),
                .anon_decl => |decl_val| try dg.renderAnonDeclValue(writer, ty, val, decl_val, location),
                .int => |int| {
                    try writer.writeAll("((");
                    try dg.renderType(writer, ty);
                    try writer.print("){x})", .{
                        try dg.fmtIntLiteral(Type.usize, Value.fromInterned(int), location),
                    });
                },
                .eu_payload,
                .opt_payload,
                .elem,
                .field,
                => try dg.renderParentPtr(writer, val.ip_index, location),
                .comptime_field => unreachable,
            },
            .opt => |opt| {
                const payload_ty = ty.optionalChild(mod);

                const is_null_val = Value.makeBool(opt.val == .none);
                if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod))
                    return dg.renderValue(writer, Type.bool, is_null_val, location);

                if (ty.optionalReprIsPayload(mod)) return dg.renderValue(
                    writer,
                    payload_ty,
                    switch (opt.val) {
                        .none => switch (payload_ty.zigTypeTag(mod)) {
                            .ErrorSet => try mod.intValue(try mod.errorIntType(), 0),
                            .Pointer => try mod.getCoerced(val, payload_ty),
                            else => unreachable,
                        },
                        else => |payload| Value.fromInterned(payload),
                    },
                    location,
                );

                if (!location.isInitializer()) {
                    try writer.writeByte('(');
                    try dg.renderType(writer, ty);
                    try writer.writeByte(')');
                }

                try writer.writeAll("{ .payload = ");
                try dg.renderValue(writer, payload_ty, Value.fromInterned(switch (opt.val) {
                    .none => try mod.intern(.{ .undef = payload_ty.ip_index }),
                    else => |payload| payload,
                }), initializer_type);
                try writer.writeAll(", .is_null = ");
                try dg.renderValue(writer, Type.bool, is_null_val, initializer_type);
                try writer.writeAll(" }");
            },
            .aggregate => switch (ip.indexToKey(ty.ip_index)) {
                .array_type, .vector_type => {
                    if (location == .FunctionArgument) {
                        try writer.writeByte('(');
                        try dg.renderType(writer, ty);
                        try writer.writeByte(')');
                    }
                    // Fall back to generic implementation.

                    // MSVC throws C2078 if an array of size 65536 or greater is initialized with a string literal
                    const max_string_initializer_len = 65535;

                    const ai = ty.arrayInfo(mod);
                    if (ai.elem_type.eql(Type.u8, mod)) {
                        if (ai.len <= max_string_initializer_len) {
                            var literal = stringLiteral(writer);
                            try literal.start();
                            var index: usize = 0;
                            while (index < ai.len) : (index += 1) {
                                const elem_val = try val.elemValue(mod, index);
                                const elem_val_u8: u8 = if (elem_val.isUndef(mod))
                                    undefPattern(u8)
                                else
                                    @intCast(elem_val.toUnsignedInt(mod));
                                try literal.writeChar(elem_val_u8);
                            }
                            if (ai.sentinel) |s| {
                                const s_u8: u8 = @intCast(s.toUnsignedInt(mod));
                                if (s_u8 != 0) try literal.writeChar(s_u8);
                            }
                            try literal.end();
                        } else {
                            try writer.writeByte('{');
                            var index: usize = 0;
                            while (index < ai.len) : (index += 1) {
                                if (index != 0) try writer.writeByte(',');
                                const elem_val = try val.elemValue(mod, index);
                                const elem_val_u8: u8 = if (elem_val.isUndef(mod))
                                    undefPattern(u8)
                                else
                                    @intCast(elem_val.toUnsignedInt(mod));
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
                            const elem_val = try val.elemValue(mod, index);
                            try dg.renderValue(writer, ai.elem_type, elem_val, initializer_type);
                        }
                        if (ai.sentinel) |s| {
                            if (index != 0) try writer.writeByte(',');
                            try dg.renderValue(writer, ai.elem_type, s, initializer_type);
                        }
                        try writer.writeByte('}');
                    }
                },
                .anon_struct_type => |tuple| {
                    if (!location.isInitializer()) {
                        try writer.writeByte('(');
                        try dg.renderType(writer, ty);
                        try writer.writeByte(')');
                    }

                    try writer.writeByte('{');
                    var empty = true;
                    for (0..tuple.types.len) |field_index| {
                        const comptime_val = tuple.values.get(ip)[field_index];
                        if (comptime_val != .none) continue;
                        const field_ty = Type.fromInterned(tuple.types.get(ip)[field_index]);
                        if (!field_ty.hasRuntimeBitsIgnoreComptime(mod)) continue;

                        if (!empty) try writer.writeByte(',');

                        const field_val = Value.fromInterned(switch (ip.indexToKey(val.ip_index).aggregate.storage) {
                            .bytes => |bytes| try ip.get(mod.gpa, .{ .int = .{
                                .ty = field_ty.toIntern(),
                                .storage = .{ .u64 = bytes[field_index] },
                            } }),
                            .elems => |elems| elems[field_index],
                            .repeated_elem => |elem| elem,
                        });
                        try dg.renderValue(writer, field_ty, field_val, initializer_type);

                        empty = false;
                    }
                    try writer.writeByte('}');
                },
                .struct_type => |struct_type| switch (struct_type.layout) {
                    .Auto, .Extern => {
                        if (!location.isInitializer()) {
                            try writer.writeByte('(');
                            try dg.renderType(writer, ty);
                            try writer.writeByte(')');
                        }

                        try writer.writeByte('{');
                        var empty = true;
                        for (0..struct_type.field_types.len) |field_index| {
                            const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[field_index]);
                            if (struct_type.fieldIsComptime(ip, field_index)) continue;
                            if (!field_ty.hasRuntimeBitsIgnoreComptime(mod)) continue;

                            if (!empty) try writer.writeByte(',');
                            const field_val = switch (ip.indexToKey(val.ip_index).aggregate.storage) {
                                .bytes => |bytes| try ip.get(mod.gpa, .{ .int = .{
                                    .ty = field_ty.toIntern(),
                                    .storage = .{ .u64 = bytes[field_index] },
                                } }),
                                .elems => |elems| elems[field_index],
                                .repeated_elem => |elem| elem,
                            };
                            try dg.renderValue(writer, field_ty, Value.fromInterned(field_val), initializer_type);

                            empty = false;
                        }
                        try writer.writeByte('}');
                    },
                    .Packed => {
                        const int_info = ty.intInfo(mod);

                        const bits = Type.smallestUnsignedBits(int_info.bits - 1);
                        const bit_offset_ty = try mod.intType(.unsigned, bits);

                        var bit_offset: u64 = 0;
                        var eff_num_fields: usize = 0;

                        for (0..struct_type.field_types.len) |field_index| {
                            const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[field_index]);
                            if (!field_ty.hasRuntimeBitsIgnoreComptime(mod)) continue;
                            eff_num_fields += 1;
                        }

                        if (eff_num_fields == 0) {
                            try writer.writeByte('(');
                            try dg.renderValue(writer, ty, Value.undef, initializer_type);
                            try writer.writeByte(')');
                        } else if (ty.bitSize(mod) > 64) {
                            // zig_or_u128(zig_or_u128(zig_shl_u128(a, a_off), zig_shl_u128(b, b_off)), zig_shl_u128(c, c_off))
                            var num_or = eff_num_fields - 1;
                            while (num_or > 0) : (num_or -= 1) {
                                try writer.writeAll("zig_or_");
                                try dg.renderTypeForBuiltinFnName(writer, ty);
                                try writer.writeByte('(');
                            }

                            var eff_index: usize = 0;
                            var needs_closing_paren = false;
                            for (0..struct_type.field_types.len) |field_index| {
                                const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[field_index]);
                                if (!field_ty.hasRuntimeBitsIgnoreComptime(mod)) continue;

                                const field_val = switch (ip.indexToKey(val.ip_index).aggregate.storage) {
                                    .bytes => |bytes| try ip.get(mod.gpa, .{ .int = .{
                                        .ty = field_ty.toIntern(),
                                        .storage = .{ .u64 = bytes[field_index] },
                                    } }),
                                    .elems => |elems| elems[field_index],
                                    .repeated_elem => |elem| elem,
                                };
                                const cast_context = IntCastContext{ .value = .{ .value = Value.fromInterned(field_val) } };
                                if (bit_offset != 0) {
                                    try writer.writeAll("zig_shl_");
                                    try dg.renderTypeForBuiltinFnName(writer, ty);
                                    try writer.writeByte('(');
                                    try dg.renderIntCast(writer, ty, cast_context, field_ty, .FunctionArgument);
                                    try writer.writeAll(", ");
                                    const bit_offset_val = try mod.intValue(bit_offset_ty, bit_offset);
                                    try dg.renderValue(writer, bit_offset_ty, bit_offset_val, .FunctionArgument);
                                    try writer.writeByte(')');
                                } else {
                                    try dg.renderIntCast(writer, ty, cast_context, field_ty, .FunctionArgument);
                                }

                                if (needs_closing_paren) try writer.writeByte(')');
                                if (eff_index != eff_num_fields - 1) try writer.writeAll(", ");

                                bit_offset += field_ty.bitSize(mod);
                                needs_closing_paren = true;
                                eff_index += 1;
                            }
                        } else {
                            try writer.writeByte('(');
                            // a << a_off | b << b_off | c << c_off
                            var empty = true;
                            for (0..struct_type.field_types.len) |field_index| {
                                const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[field_index]);
                                if (!field_ty.hasRuntimeBitsIgnoreComptime(mod)) continue;

                                if (!empty) try writer.writeAll(" | ");
                                try writer.writeByte('(');
                                try dg.renderType(writer, ty);
                                try writer.writeByte(')');

                                const field_val = switch (ip.indexToKey(val.ip_index).aggregate.storage) {
                                    .bytes => |bytes| try ip.get(mod.gpa, .{ .int = .{
                                        .ty = field_ty.toIntern(),
                                        .storage = .{ .u64 = bytes[field_index] },
                                    } }),
                                    .elems => |elems| elems[field_index],
                                    .repeated_elem => |elem| elem,
                                };

                                if (bit_offset != 0) {
                                    try dg.renderValue(writer, field_ty, Value.fromInterned(field_val), .Other);
                                    try writer.writeAll(" << ");
                                    const bit_offset_val = try mod.intValue(bit_offset_ty, bit_offset);
                                    try dg.renderValue(writer, bit_offset_ty, bit_offset_val, .FunctionArgument);
                                } else {
                                    try dg.renderValue(writer, field_ty, Value.fromInterned(field_val), .Other);
                                }

                                bit_offset += field_ty.bitSize(mod);
                                empty = false;
                            }
                            try writer.writeByte(')');
                        }
                    },
                },
                else => unreachable,
            },
            .un => |un| {
                const union_obj = mod.typeToUnion(ty).?;
                if (un.tag == .none) {
                    const backing_ty = try ty.unionBackingType(mod);
                    switch (union_obj.getLayout(ip)) {
                        .Packed => {
                            if (!location.isInitializer()) {
                                try writer.writeByte('(');
                                try dg.renderType(writer, backing_ty);
                                try writer.writeByte(')');
                            }
                            try dg.renderValue(writer, backing_ty, Value.fromInterned(un.val), initializer_type);
                        },
                        .Extern => {
                            if (location == .StaticInitializer) {
                                return dg.fail("TODO: C backend: implement extern union backing type rendering in static initializers", .{});
                            }

                            const ptr_ty = try mod.singleConstPtrType(ty);
                            try writer.writeAll("*((");
                            try dg.renderType(writer, ptr_ty);
                            try writer.writeAll(")(");
                            try dg.renderType(writer, backing_ty);
                            try writer.writeAll("){");
                            try dg.renderValue(writer, backing_ty, Value.fromInterned(un.val), initializer_type);
                            try writer.writeAll("})");
                        },
                        else => unreachable,
                    }
                } else {
                    if (!location.isInitializer()) {
                        try writer.writeByte('(');
                        try dg.renderType(writer, ty);
                        try writer.writeByte(')');
                    }

                    const field_index = mod.unionTagFieldIndex(union_obj, Value.fromInterned(un.tag)).?;
                    const field_ty = Type.fromInterned(union_obj.field_types.get(ip)[field_index]);
                    const field_name = union_obj.field_names.get(ip)[field_index];
                    if (union_obj.getLayout(ip) == .Packed) {
                        if (field_ty.hasRuntimeBits(mod)) {
                            if (field_ty.isPtrAtRuntime(mod)) {
                                try writer.writeByte('(');
                                try dg.renderType(writer, ty);
                                try writer.writeByte(')');
                            } else if (field_ty.zigTypeTag(mod) == .Float) {
                                try writer.writeByte('(');
                                try dg.renderType(writer, ty);
                                try writer.writeByte(')');
                            }
                            try dg.renderValue(writer, field_ty, Value.fromInterned(un.val), initializer_type);
                        } else {
                            try writer.writeAll("0");
                        }
                        return;
                    }

                    try writer.writeByte('{');
                    if (ty.unionTagTypeSafety(mod)) |tag_ty| {
                        const layout = mod.getUnionLayout(union_obj);
                        if (layout.tag_size != 0) {
                            try writer.writeAll(" .tag = ");
                            try dg.renderValue(writer, tag_ty, Value.fromInterned(un.tag), initializer_type);
                        }
                        if (ty.unionHasAllZeroBitFieldTypes(mod)) return try writer.writeByte('}');
                        if (layout.tag_size != 0) try writer.writeByte(',');
                        try writer.writeAll(" .payload = {");
                    }
                    if (field_ty.hasRuntimeBits(mod)) {
                        try writer.print(" .{ } = ", .{fmtIdent(ip.stringToSlice(field_name))});
                        try dg.renderValue(writer, field_ty, Value.fromInterned(un.val), initializer_type);
                        try writer.writeByte(' ');
                    } else for (0..union_obj.field_types.len) |this_field_index| {
                        const this_field_ty = Type.fromInterned(union_obj.field_types.get(ip)[this_field_index]);
                        if (!this_field_ty.hasRuntimeBits(mod)) continue;
                        try dg.renderValue(writer, this_field_ty, Value.undef, initializer_type);
                        break;
                    }
                    if (ty.unionTagTypeSafety(mod)) |_| try writer.writeByte('}');
                    try writer.writeByte('}');
                }
            },
        }
    }

    fn renderFunctionSignature(
        dg: *DeclGen,
        w: anytype,
        fn_decl_index: InternPool.DeclIndex,
        kind: CType.Kind,
        name: union(enum) {
            export_index: u32,
            ident: []const u8,
        },
    ) !void {
        const store = &dg.ctypes.set;
        const mod = dg.module;
        const ip = &mod.intern_pool;

        const fn_decl = mod.declPtr(fn_decl_index);
        const fn_cty_idx = try dg.typeToIndex(fn_decl.ty, kind);

        const fn_info = mod.typeToFunc(fn_decl.ty).?;
        if (fn_info.cc == .Naked) {
            switch (kind) {
                .forward => try w.writeAll("zig_naked_decl "),
                .complete => try w.writeAll("zig_naked "),
                else => unreachable,
            }
        }
        if (fn_decl.val.getFunction(mod)) |func| if (func.analysis(ip).is_cold)
            try w.writeAll("zig_cold ");
        if (fn_info.return_type == .noreturn_type) try w.writeAll("zig_noreturn ");

        var trailing = try renderTypePrefix(dg.pass, store.*, mod, w, fn_cty_idx, .suffix, .{});

        if (toCallingConvention(fn_info.cc)) |call_conv| {
            try w.print("{}zig_callconv({s})", .{ trailing, call_conv });
            trailing = .maybe_space;
        }

        switch (kind) {
            .forward => {},
            .complete => if (fn_info.alignment.toByteUnitsOptional()) |a| {
                try w.print("{}zig_align_fn({})", .{ trailing, a });
                trailing = .maybe_space;
            },
            else => unreachable,
        }

        switch (name) {
            .export_index => |export_index| {
                try w.print("{}", .{trailing});
                try dg.renderDeclName(w, fn_decl_index, export_index);
            },
            .ident => |ident| try w.print("{}{ }", .{ trailing, fmtIdent(ident) }),
        }

        try renderTypeSuffix(
            dg.pass,
            store.*,
            mod,
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
            .forward => {
                if (fn_info.alignment.toByteUnitsOptional()) |a| {
                    try w.print(" zig_align_fn({})", .{a});
                }
                switch (name) {
                    .export_index => |export_index| mangled: {
                        const maybe_exports = mod.decl_exports.get(fn_decl_index);
                        const external_name = ip.stringToSlice(
                            if (maybe_exports) |exports|
                                exports.items[export_index].opts.name
                            else if (fn_decl.isExtern(mod))
                                fn_decl.name
                            else
                                break :mangled,
                        );
                        const is_mangled = isMangledIdent(external_name, true);
                        const is_export = export_index > 0;
                        if (is_mangled and is_export) {
                            try w.print(" zig_mangled_export({ }, {s}, {s})", .{
                                fmtIdent(external_name),
                                fmtStringLiteral(external_name, null),
                                fmtStringLiteral(
                                    ip.stringToSlice(maybe_exports.?.items[0].opts.name),
                                    null,
                                ),
                            });
                        } else if (is_mangled) {
                            try w.print(" zig_mangled_final({ }, {s})", .{
                                fmtIdent(external_name), fmtStringLiteral(external_name, null),
                            });
                        } else if (is_export) {
                            try w.print(" zig_export({s}, {s})", .{
                                fmtStringLiteral(
                                    ip.stringToSlice(maybe_exports.?.items[0].opts.name),
                                    null,
                                ),
                                fmtStringLiteral(external_name, null),
                            });
                        }
                    },
                    .ident => {},
                }
            },
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

    fn byteSize(dg: *DeclGen, cty: CType) u64 {
        return cty.byteSize(dg.ctypes.set, dg.module.getTarget());
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
        try dg.renderCType(w, try dg.typeToIndex(t, .complete));
    }

    fn renderCType(dg: *DeclGen, w: anytype, idx: CType.Index) error{ OutOfMemory, AnalysisFail }!void {
        const store = &dg.ctypes.set;
        const mod = dg.module;
        _ = try renderTypePrefix(dg.pass, store.*, mod, w, idx, .suffix, .{});
        try renderTypeSuffix(dg.pass, store.*, mod, w, idx, .suffix, .{});
    }

    const IntCastContext = union(enum) {
        c_value: struct {
            f: *Function,
            value: CValue,
            v: Vectorize,
        },
        value: struct {
            value: Value,
        },

        pub fn writeValue(self: *const IntCastContext, dg: *DeclGen, w: anytype, value_ty: Type, location: ValueRenderLocation) !void {
            switch (self.*) {
                .c_value => |v| {
                    try v.f.writeCValue(w, v.value, location);
                    try v.v.elem(v.f, w);
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
        const mod = dg.module;
        const dest_bits = dest_ty.bitSize(mod);
        const dest_int_info = dest_ty.intInfo(mod);

        const src_is_ptr = src_ty.isPtrAtRuntime(mod);
        const src_eff_ty: Type = if (src_is_ptr) switch (dest_int_info.signedness) {
            .unsigned => Type.usize,
            .signed => Type.isize,
        } else src_ty;

        const src_bits = src_eff_ty.bitSize(mod);
        const src_int_info = if (src_eff_ty.isAbiInt(mod)) src_eff_ty.intInfo(mod) else null;
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
        alignment: Alignment,
        kind: CType.Kind,
    ) error{ OutOfMemory, AnalysisFail }!void {
        const mod = dg.module;
        const alignas = CType.AlignAs.init(alignment, ty.abiAlignment(mod));
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
        const mod = dg.module;

        switch (alignas.abiOrder()) {
            .lt => try w.print("zig_under_align({}) ", .{alignas.toByteUnits()}),
            .eq => {},
            .gt => try w.print("zig_align({}) ", .{alignas.toByteUnits()}),
        }

        const trailing = try renderTypePrefix(dg.pass, store.*, mod, w, cty_idx, .suffix, qualifiers);
        try w.print("{}", .{trailing});
        try dg.writeCValue(w, name);
        try renderTypeSuffix(dg.pass, store.*, mod, w, cty_idx, .suffix, .{});
    }

    fn declIsGlobal(dg: *DeclGen, tv: TypedValue) bool {
        const mod = dg.module;
        return switch (mod.intern_pool.indexToKey(tv.val.ip_index)) {
            .variable => |variable| mod.decl_exports.contains(variable.decl),
            .extern_func => true,
            .func => |func| mod.decl_exports.contains(func.owner_decl),
            else => unreachable,
        };
    }

    fn writeCValue(dg: *DeclGen, w: anytype, c_value: CValue) !void {
        switch (c_value) {
            .none => unreachable,
            .local, .new_local => |i| return w.print("t{d}", .{i}),
            .local_ref => |i| return w.print("&t{d}", .{i}),
            .constant => |val| return renderAnonDeclName(w, val),
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
        }
    }

    fn writeCValueMember(
        dg: *DeclGen,
        writer: anytype,
        c_value: CValue,
        member: CValue,
    ) error{ OutOfMemory, AnalysisFail }!void {
        try dg.writeCValue(writer, c_value);
        try writer.writeByte('.');
        try dg.writeCValue(writer, member);
    }

    fn writeCValueDerefMember(dg: *DeclGen, writer: anytype, c_value: CValue, member: CValue) !void {
        switch (c_value) {
            .none, .constant, .field, .undef => unreachable,
            .new_local, .local, .arg, .arg_array, .decl, .identifier, .payload_identifier => {
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

    fn renderFwdDecl(
        dg: *DeclGen,
        decl_index: InternPool.DeclIndex,
        variable: InternPool.Key.Variable,
        fwd_kind: enum { tentative, final },
    ) !void {
        const decl = dg.module.declPtr(decl_index);
        const fwd = dg.fwdDeclWriter();
        const is_global = variable.is_extern or dg.declIsGlobal(.{ .ty = decl.ty, .val = decl.val });
        try fwd.writeAll(if (is_global) "zig_extern " else "static ");
        const maybe_exports = dg.module.decl_exports.get(decl_index);
        const export_weak_linkage = if (maybe_exports) |exports|
            exports.items[0].opts.linkage == .Weak
        else
            false;
        if (variable.is_weak_linkage or export_weak_linkage) try fwd.writeAll("zig_weak_linkage ");
        if (variable.is_threadlocal) try fwd.writeAll("zig_threadlocal ");
        try dg.renderTypeAndName(
            fwd,
            decl.ty,
            .{ .decl = decl_index },
            CQualifiers.init(.{ .@"const" = variable.is_const }),
            decl.alignment,
            .complete,
        );
        mangled: {
            const external_name = dg.module.intern_pool.stringToSlice(if (maybe_exports) |exports|
                exports.items[0].opts.name
            else if (variable.is_extern)
                decl.name
            else
                break :mangled);
            if (isMangledIdent(external_name, true)) {
                try fwd.print(" zig_mangled_{s}({ }, {s})", .{
                    @tagName(fwd_kind),
                    fmtIdent(external_name),
                    fmtStringLiteral(external_name, null),
                });
            }
        }
        try fwd.writeAll(";\n");
    }

    fn renderDeclName(dg: *DeclGen, writer: anytype, decl_index: InternPool.DeclIndex, export_index: u32) !void {
        const mod = dg.module;
        const decl = mod.declPtr(decl_index);
        try mod.markDeclAlive(decl);

        if (mod.decl_exports.get(decl_index)) |exports| {
            try writer.print("{ }", .{
                fmtIdent(mod.intern_pool.stringToSlice(exports.items[export_index].opts.name)),
            });
        } else if (decl.getExternDecl(mod).unwrap()) |extern_decl_index| {
            try writer.print("{ }", .{
                fmtIdent(mod.intern_pool.stringToSlice(mod.declPtr(extern_decl_index).name)),
            });
        } else {
            // MSVC has a limit of 4095 character token length limit, and fmtIdent can (worst case),
            // expand to 3x the length of its input, but let's cut it off at a much shorter limit.
            var name: [100]u8 = undefined;
            var name_stream = std.io.fixedBufferStream(&name);
            decl.renderFullyQualifiedName(mod, name_stream.writer()) catch |err| switch (err) {
                error.NoSpaceLeft => {},
            };
            try writer.print("{}__{d}", .{
                fmtIdent(name_stream.getWritten()),
                @intFromEnum(decl_index),
            });
        }
    }

    fn renderAnonDeclName(writer: anytype, anon_decl_val: InternPool.Index) !void {
        return writer.print("__anon_{d}", .{@intFromEnum(anon_decl_val)});
    }

    fn renderTypeForBuiltinFnName(dg: *DeclGen, writer: anytype, ty: Type) !void {
        try dg.renderCTypeForBuiltinFnName(writer, try dg.typeToCType(ty, .complete));
    }

    fn renderCTypeForBuiltinFnName(dg: *DeclGen, writer: anytype, cty: CType) !void {
        switch (cty.tag()) {
            else => try writer.print("{c}{d}", .{
                if (cty.isBool())
                    signAbbrev(.unsigned)
                else if (cty.isInteger())
                    signAbbrev(cty.signedness(dg.module.getTarget()))
                else if (cty.isFloat())
                    @as(u8, 'f')
                else if (cty.isPointer())
                    @as(u8, 'p')
                else
                    return dg.fail("TODO: CBE: implement renderTypeForBuiltinFnName for type {}", .{
                        cty.tag(),
                    }),
                if (cty.isFloat()) cty.floatActiveBits(dg.module.getTarget()) else dg.byteSize(cty) * 8,
            }),
            .array => try writer.writeAll("big"),
        }
    }

    fn renderBuiltinInfo(dg: *DeclGen, writer: anytype, ty: Type, info: BuiltinInfo) !void {
        const cty = try dg.typeToCType(ty, .complete);
        const is_big = cty.tag() == .array;

        switch (info) {
            .none => if (!is_big) return,
            .bits => {},
        }

        const mod = dg.module;
        const int_info = if (ty.isAbiInt(mod)) ty.intInfo(mod) else std.builtin.Type.Int{
            .signedness = .unsigned,
            .bits = @as(u16, @intCast(ty.bitSize(mod))),
        };

        if (is_big) try writer.print(", {}", .{int_info.signedness == .signed});

        const bits_ty = if (is_big) Type.u16 else Type.u8;
        try writer.print(", {}", .{try dg.fmtIntLiteral(
            bits_ty,
            try mod.intValue(bits_ty, int_info.bits),
            .FunctionArgument,
        )});
    }

    fn fmtIntLiteral(
        dg: *DeclGen,
        ty: Type,
        val: Value,
        loc: ValueRenderLocation,
    ) !std.fmt.Formatter(formatIntLiteral) {
        const mod = dg.module;
        const kind: CType.Kind = switch (loc) {
            .FunctionArgument => .parameter,
            .Initializer, .Other => .complete,
            .StaticInitializer => .global,
        };
        return std.fmt.Formatter(formatIntLiteral){ .data = .{
            .dg = dg,
            .int_info = ty.intInfo(mod),
            .kind = kind,
            .cty = try dg.typeToCType(ty, kind),
            .val = val,
        } };
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
                fmtIdent(mod.intern_pool.stringToSlice(mod.declPtr(owner_decl).name)),
                @intFromEnum(owner_decl),
            });
        },
    }
}
fn renderTypePrefix(
    pass: DeclGen.Pass,
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
                pass,
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
            const child_trailing =
                try renderTypePrefix(pass, store, mod, w, child_idx, .suffix, qualifiers);
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
        => switch (pass) {
            .decl => |decl_index| try w.print("decl__{d}_{d}", .{ @intFromEnum(decl_index), idx }),
            .anon => |anon_decl| try w.print("anon__{d}_{d}", .{ @intFromEnum(anon_decl), idx }),
            .flush => try renderTypeName(mod, w, idx, cty, ""),
        },

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
            pass,
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
                pass,
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
    pass: DeclGen.Pass,
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
            pass,
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
                pass,
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
                    try renderTypePrefix(pass, store, mod, w, param_type, .suffix, qualifiers);
                if (qualifiers.contains(.@"const")) try w.print("{}a{d}", .{ trailing, param_i });
                try renderTypeSuffix(pass, store, mod, w, param_type, .suffix, .{});
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

            try renderTypeSuffix(pass, store, mod, w, data.return_type, .suffix, .{});
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
        switch (field.alignas.abiOrder()) {
            .lt => try writer.print("zig_under_align({}) ", .{field.alignas.toByteUnits()}),
            .eq => {},
            .gt => try writer.print("zig_align({}) ", .{field.alignas.toByteUnits()}),
        }
        const trailing = try renderTypePrefix(.flush, store, mod, writer, field.type, .suffix, .{});
        try writer.print("{}{ }", .{ trailing, fmtIdent(mem.span(field.name)) });
        try renderTypeSuffix(.flush, store, mod, writer, field.type, .suffix, .{});
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
    pass: DeclGen.Pass,
    decl_store: CType.Store.Set,
    decl_idx: CType.Index,
    found_existing: bool,
) !void {
    const global_cty = global_store.indexToCType(global_idx);
    switch (global_cty.tag()) {
        .fwd_anon_struct => if (pass != .flush) {
            try writer.writeAll("typedef ");
            _ = try renderTypePrefix(.flush, global_store, mod, writer, global_idx, .suffix, .{});
            try writer.writeByte(' ');
            _ = try renderTypePrefix(pass, decl_store, mod, writer, decl_idx, .suffix, .{});
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
                    _ = try renderTypePrefix(
                        .flush,
                        global_store,
                        mod,
                        writer,
                        global_idx,
                        .suffix,
                        .{},
                    );
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
    for (mod.global_assembly.values()) |asm_source| {
        try writer.print("__asm({s});\n", .{fmtStringLiteral(asm_source, null)});
    }
}

pub fn genErrDecls(o: *Object) !void {
    const mod = o.dg.module;
    const ip = &mod.intern_pool;
    const writer = o.writer();

    var max_name_len: usize = 0;
    // do not generate an invalid empty enum when the global error set is empty
    if (mod.global_error_set.keys().len > 1) {
        try writer.writeAll("enum {\n");
        o.indent_writer.pushIndent();
        for (mod.global_error_set.keys()[1..], 1..) |name_nts, value| {
            const name = ip.stringToSlice(name_nts);
            max_name_len = @max(name.len, max_name_len);
            const err_val = try mod.intern(.{ .err = .{
                .ty = .anyerror_type,
                .name = name_nts,
            } });
            try o.dg.renderValue(writer, Type.anyerror, Value.fromInterned(err_val), .Other);
            try writer.print(" = {d}u,\n", .{value});
        }
        o.indent_writer.popIndent();
        try writer.writeAll("};\n");
    }
    const array_identifier = "zig_errorName";
    const name_prefix = array_identifier ++ "_";
    const name_buf = try o.dg.gpa.alloc(u8, name_prefix.len + max_name_len);
    defer o.dg.gpa.free(name_buf);

    @memcpy(name_buf[0..name_prefix.len], name_prefix);
    for (mod.global_error_set.keys()) |name_ip| {
        const name = ip.stringToSlice(name_ip);
        @memcpy(name_buf[name_prefix.len..][0..name.len], name);
        const identifier = name_buf[0 .. name_prefix.len + name.len];

        const name_ty = try mod.arrayType(.{
            .len = name.len,
            .child = .u8_type,
            .sentinel = .zero_u8,
        });
        const name_val = try mod.intern(.{ .aggregate = .{
            .ty = name_ty.toIntern(),
            .storage = .{ .bytes = name },
        } });

        try writer.writeAll("static ");
        try o.dg.renderTypeAndName(writer, name_ty, .{ .identifier = identifier }, Const, .none, .complete);
        try writer.writeAll(" = ");
        try o.dg.renderValue(writer, name_ty, Value.fromInterned(name_val), .StaticInitializer);
        try writer.writeAll(";\n");
    }

    const name_array_ty = try mod.arrayType(.{
        .len = mod.global_error_set.count(),
        .child = .slice_const_u8_sentinel_0_type,
    });

    try writer.writeAll("static ");
    try o.dg.renderTypeAndName(writer, name_array_ty, .{ .identifier = array_identifier }, Const, .none, .complete);
    try writer.writeAll(" = {");
    for (mod.global_error_set.keys(), 0..) |name_nts, value| {
        const name = ip.stringToSlice(name_nts);
        if (value != 0) try writer.writeByte(',');

        const len_val = try mod.intValue(Type.usize, name.len);

        try writer.print("{{" ++ name_prefix ++ "{}, {}}}", .{
            fmtIdent(name), try o.dg.fmtIntLiteral(Type.usize, len_val, .StaticInitializer),
        });
    }
    try writer.writeAll("};\n");
}

fn genExports(o: *Object) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const mod = o.dg.module;
    const ip = &mod.intern_pool;
    const decl_index = switch (o.dg.pass) {
        .decl => |decl| decl,
        .anon, .flush => return,
    };
    const decl = mod.declPtr(decl_index);
    const tv: TypedValue = .{ .ty = decl.ty, .val = Value.fromInterned((try decl.internValue(mod))) };
    const fwd = o.dg.fwdDeclWriter();

    const exports = mod.decl_exports.get(decl_index) orelse return;
    if (exports.items.len < 2) return;

    const is_variable_const = switch (ip.indexToKey(tv.val.toIntern())) {
        .func => return for (exports.items[1..], 1..) |@"export", i| {
            try fwd.writeAll("zig_extern ");
            if (@"export".opts.linkage == .Weak) try fwd.writeAll("zig_weak_linkage_fn ");
            try o.dg.renderFunctionSignature(
                fwd,
                decl_index,
                .forward,
                .{ .export_index = @intCast(i) },
            );
            try fwd.writeAll(";\n");
        },
        .extern_func => {
            // TODO: when sema allows re-exporting extern decls
            unreachable;
        },
        .variable => |variable| variable.is_const,
        else => true,
    };
    for (exports.items[1..]) |@"export"| {
        try fwd.writeAll("zig_extern ");
        if (@"export".opts.linkage == .Weak) try fwd.writeAll("zig_weak_linkage ");
        const export_name = ip.stringToSlice(@"export".opts.name);
        try o.dg.renderTypeAndName(
            fwd,
            decl.ty,
            .{ .identifier = export_name },
            CQualifiers.init(.{ .@"const" = is_variable_const }),
            decl.alignment,
            .complete,
        );
        if (isMangledIdent(export_name, true)) {
            try fwd.print(" zig_mangled_export({ }, {s}, {s})", .{
                fmtIdent(export_name),
                fmtStringLiteral(export_name, null),
                fmtStringLiteral(ip.stringToSlice(exports.items[0].opts.name), null),
            });
        } else {
            try fwd.print(" zig_export({s}, {s})", .{
                fmtStringLiteral(ip.stringToSlice(exports.items[0].opts.name), null),
                fmtStringLiteral(export_name, null),
            });
        }
        try fwd.writeAll(";\n");
    }
}

pub fn genLazyFn(o: *Object, lazy_fn: LazyFnMap.Entry) !void {
    const mod = o.dg.module;
    const ip = &mod.intern_pool;
    const w = o.writer();
    const key = lazy_fn.key_ptr.*;
    const val = lazy_fn.value_ptr;
    const fn_name = val.fn_name;
    switch (key) {
        .tag_name => {
            const enum_ty = val.data.tag_name;

            const name_slice_ty = Type.slice_const_u8_sentinel_0;

            try w.writeAll("static ");
            try o.dg.renderType(w, name_slice_ty);
            try w.writeByte(' ');
            try w.writeAll(fn_name);
            try w.writeByte('(');
            try o.dg.renderTypeAndName(w, enum_ty, .{ .identifier = "tag" }, Const, .none, .complete);
            try w.writeAll(") {\n switch (tag) {\n");
            const tag_names = enum_ty.enumFields(mod);
            for (0..tag_names.len) |tag_index| {
                const tag_name = ip.stringToSlice(tag_names.get(ip)[tag_index]);
                const tag_val = try mod.enumValueFieldIndex(enum_ty, @intCast(tag_index));

                const int_val = try tag_val.intFromEnum(enum_ty, mod);

                const name_ty = try mod.arrayType(.{
                    .len = tag_name.len,
                    .child = .u8_type,
                    .sentinel = .zero_u8,
                });
                const name_val = try mod.intern(.{ .aggregate = .{
                    .ty = name_ty.toIntern(),
                    .storage = .{ .bytes = tag_name },
                } });
                const len_val = try mod.intValue(Type.usize, tag_name.len);

                try w.print("  case {}: {{\n   static ", .{
                    try o.dg.fmtIntLiteral(enum_ty, int_val, .Other),
                });
                try o.dg.renderTypeAndName(w, name_ty, .{ .identifier = "name" }, Const, .none, .complete);
                try w.writeAll(" = ");
                try o.dg.renderValue(w, name_ty, Value.fromInterned(name_val), .Initializer);
                try w.writeAll(";\n   return (");
                try o.dg.renderType(w, name_slice_ty);
                try w.print("){{{}, {}}};\n", .{
                    fmtIdent("name"), try o.dg.fmtIntLiteral(Type.usize, len_val, .Other),
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
            const fn_decl = mod.declPtr(fn_decl_index);
            const fn_cty = try o.dg.typeToCType(fn_decl.ty, .complete);
            const fn_info = fn_cty.cast(CType.Payload.Function).?.data;

            const fwd_decl_writer = o.dg.fwdDeclWriter();
            try fwd_decl_writer.print("static zig_{s} ", .{@tagName(key)});
            try o.dg.renderFunctionSignature(
                fwd_decl_writer,
                fn_decl_index,
                .forward,
                .{ .ident = fn_name },
            );
            try fwd_decl_writer.writeAll(";\n");

            try w.print("static zig_{s} ", .{@tagName(key)});
            try o.dg.renderFunctionSignature(w, fn_decl_index, .complete, .{ .ident = fn_name });
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
    const mod = o.dg.module;
    const gpa = o.dg.gpa;
    const decl_index = o.dg.pass.decl;
    const decl = mod.declPtr(decl_index);
    const tv: TypedValue = .{
        .ty = decl.ty,
        .val = decl.val,
    };

    o.code_header = std.ArrayList(u8).init(gpa);
    defer o.code_header.deinit();

    const is_global = o.dg.declIsGlobal(tv);
    const fwd_decl_writer = o.dg.fwdDeclWriter();
    try fwd_decl_writer.writeAll(if (is_global) "zig_extern " else "static ");

    if (mod.decl_exports.get(decl_index)) |exports|
        if (exports.items[0].opts.linkage == .Weak) try fwd_decl_writer.writeAll("zig_weak_linkage_fn ");
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

    f.free_locals_map.clearRetainingCapacity();

    const main_body = f.air.getMainBody();
    try genBodyResolveState(f, undefined, &.{}, main_body, false);

    try o.indent_writer.insertNewline();

    // Take advantage of the free_locals map to bucket locals per type. All
    // locals corresponding to AIR instructions should be in there due to
    // Liveness analysis, however, locals from alloc instructions will be
    // missing. These are added now to complete the map. Then we can sort by
    // alignment, descending.
    const free_locals = &f.free_locals_map;
    assert(f.value_map.count() == 0); // there must not be any unfreed locals
    for (f.allocs.keys(), f.allocs.values()) |local_index, should_emit| {
        if (!should_emit) continue;
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
            return lhs_ty.alignas.order(rhs_ty.alignas).compare(.gt);
        }
    };
    free_locals.sort(SortContext{ .keys = free_locals.keys() });

    const w = o.codeHeaderWriter();
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

    const mod = o.dg.module;
    const decl_index = o.dg.pass.decl;
    const decl = mod.declPtr(decl_index);
    const tv: TypedValue = .{ .ty = decl.ty, .val = Value.fromInterned((try decl.internValue(mod))) };

    if (!tv.ty.isFnOrHasRuntimeBitsIgnoreComptime(mod)) return;
    if (tv.val.getExternFunc(mod)) |_| {
        const fwd_decl_writer = o.dg.fwdDeclWriter();
        try fwd_decl_writer.writeAll("zig_extern ");
        try o.dg.renderFunctionSignature(fwd_decl_writer, decl_index, .forward, .{ .export_index = 0 });
        try fwd_decl_writer.writeAll(";\n");
        try genExports(o);
    } else if (tv.val.getVariable(mod)) |variable| {
        try o.dg.renderFwdDecl(decl_index, variable, .final);
        try genExports(o);

        if (variable.is_extern) return;

        const is_global = variable.is_extern or o.dg.declIsGlobal(tv);
        const w = o.writer();
        if (!is_global) try w.writeAll("static ");
        if (variable.is_weak_linkage) try w.writeAll("zig_weak_linkage ");
        if (variable.is_threadlocal) try w.writeAll("zig_threadlocal ");
        if (mod.intern_pool.stringToSliceUnwrap(decl.@"linksection")) |s|
            try w.print("zig_linksection(\"{s}\", ", .{s});
        const decl_c_value = .{ .decl = decl_index };
        try o.dg.renderTypeAndName(w, tv.ty, decl_c_value, .{}, decl.alignment, .complete);
        if (decl.@"linksection" != .none) try w.writeAll(", read, write)");
        try w.writeAll(" = ");
        try o.dg.renderValue(w, tv.ty, Value.fromInterned(variable.init), .StaticInitializer);
        try w.writeByte(';');
        try o.indent_writer.insertNewline();
    } else {
        const is_global = o.dg.module.decl_exports.contains(decl_index);
        const decl_c_value = .{ .decl = decl_index };
        try genDeclValue(o, tv, is_global, decl_c_value, decl.alignment, decl.@"linksection");
    }
}

pub fn genDeclValue(
    o: *Object,
    tv: TypedValue,
    is_global: bool,
    decl_c_value: CValue,
    alignment: Alignment,
    link_section: InternPool.OptionalNullTerminatedString,
) !void {
    const mod = o.dg.module;
    const fwd_decl_writer = o.dg.fwdDeclWriter();

    try fwd_decl_writer.writeAll(if (is_global) "zig_extern " else "static ");
    try o.dg.renderTypeAndName(fwd_decl_writer, tv.ty, decl_c_value, Const, alignment, .complete);
    switch (o.dg.pass) {
        .decl => |decl_index| {
            if (mod.decl_exports.get(decl_index)) |exports| {
                const export_name = mod.intern_pool.stringToSlice(exports.items[0].opts.name);
                if (isMangledIdent(export_name, true)) {
                    try fwd_decl_writer.print(" zig_mangled_final({ }, {s})", .{
                        fmtIdent(export_name), fmtStringLiteral(export_name, null),
                    });
                }
            }
        },
        .anon => {},
        .flush => unreachable,
    }
    try fwd_decl_writer.writeAll(";\n");
    try genExports(o);

    const w = o.writer();
    if (!is_global) try w.writeAll("static ");

    if (mod.intern_pool.stringToSliceUnwrap(link_section)) |s|
        try w.print("zig_linksection(\"{s}\", ", .{s});
    try o.dg.renderTypeAndName(w, tv.ty, decl_c_value, Const, alignment, .complete);
    if (link_section != .none) try w.writeAll(", read)");
    try w.writeAll(" = ");
    try o.dg.renderValue(w, tv.ty, tv.val, .StaticInitializer);
    try w.writeAll(";\n");
}

pub fn genHeader(dg: *DeclGen) error{ AnalysisFail, OutOfMemory }!void {
    const tracy = trace(@src());
    defer tracy.end();

    const mod = dg.module;
    const decl_index = dg.pass.decl;
    const decl = mod.declPtr(decl_index);
    const tv: TypedValue = .{
        .ty = decl.ty,
        .val = decl.val,
    };
    const writer = dg.fwdDeclWriter();

    switch (tv.ty.zigTypeTag(mod)) {
        .Fn => if (dg.declIsGlobal(tv)) {
            try writer.writeAll("zig_extern ");
            try dg.renderFunctionSignature(writer, dg.pass.decl, .complete, .{ .export_index = 0 });
            try dg.fwd_decl.appendSlice(";\n");
        },
        else => {},
    }
}

/// Generate code for an entire body which ends with a `noreturn` instruction. The states of
/// `value_map` and `free_locals_map` are undefined after the generation, and new locals may not
/// have been added to `free_locals_map`. For a version of this function that restores this state,
/// see `genBodyResolveState`.
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

/// Generate code for an entire body which ends with a `noreturn` instruction. The states of
/// `value_map` and `free_locals_map` are restored to their original values, and any non-allocated
/// locals introduced within the body are correctly added to `free_locals_map`. Operands in
/// `leading_deaths` have their deaths processed before the body is generated.
/// A scope is introduced (using braces) only if `inner` is `false`.
/// If `leading_deaths` is empty, `inst` may be `undefined`.
fn genBodyResolveState(f: *Function, inst: Air.Inst.Index, leading_deaths: []const Air.Inst.Index, body: []const Air.Inst.Index, inner: bool) error{ AnalysisFail, OutOfMemory }!void {
    if (body.len == 0) {
        // Don't go to the expense of cloning everything!
        if (!inner) try f.object.writer().writeAll("{}");
        return;
    }

    // TODO: we can probably avoid the copies in some other common cases too.

    const gpa = f.object.dg.gpa;

    // Save the original value_map and free_locals_map so that we can restore them after the body.
    var old_value_map = try f.value_map.clone();
    defer old_value_map.deinit();
    var old_free_locals = try cloneFreeLocalsMap(gpa, &f.free_locals_map);
    defer deinitFreeLocalsMap(gpa, &old_free_locals);

    // Remember how many locals there were before entering the body so that we can free any that
    // were newly introduced. Any new locals must necessarily be logically free after the then
    // branch is complete.
    const pre_locals_len = @as(LocalIndex, @intCast(f.locals.items.len));

    for (leading_deaths) |death| {
        try die(f, inst, death.toRef());
    }

    if (inner) {
        try genBodyInner(f, body);
    } else {
        try genBody(f, body);
    }

    f.value_map.deinit();
    f.value_map = old_value_map.move();
    deinitFreeLocalsMap(gpa, &f.free_locals_map);
    f.free_locals_map = old_free_locals.move();

    // Now, use the lengths we stored earlier to detect any locals the body generated, and free
    // them, unless they were used to store allocs.

    for (pre_locals_len..f.locals.items.len) |local_i| {
        const local_index: LocalIndex = @intCast(local_i);
        if (f.allocs.contains(local_index)) {
            continue;
        }
        try freeLocal(f, inst, local_index, null);
    }
}

fn genBodyInner(f: *Function, body: []const Air.Inst.Index) error{ AnalysisFail, OutOfMemory }!void {
    const mod = f.object.dg.module;
    const ip = &mod.intern_pool;
    const air_tags = f.air.instructions.items(.tag);

    for (body) |inst| {
        if (f.liveness.isUnused(inst) and !f.air.mustLower(inst, ip))
            continue;

        const result_value = switch (air_tags[@intFromEnum(inst)]) {
            // zig fmt: off
            .inferred_alloc, .inferred_alloc_comptime => unreachable,

            .arg      => try airArg(f, inst),

            .trap       => try airTrap(f, f.object.writer()),
            .breakpoint => try airBreakpoint(f.object.writer()),
            .ret_addr   => try airRetAddr(f, inst),
            .frame_addr => try airFrameAddress(f, inst),
            .unreach    => try airUnreach(f),
            .fence      => try airFence(f, inst),

            .ptr_add => try airPtrAddSub(f, inst, '+'),
            .ptr_sub => try airPtrAddSub(f, inst, '-'),

            // TODO use a different strategy for add, sub, mul, div
            // that communicates to the optimizer that wrapping is UB.
            .add => try airBinOp(f, inst, "+", "add", .none),
            .sub => try airBinOp(f, inst, "-", "sub", .none),
            .mul => try airBinOp(f, inst, "*", "mul", .none),

            .neg => try airFloatNeg(f, inst),
            .div_float => try airBinBuiltinCall(f, inst, "div", .none),

            .div_trunc, .div_exact => try airBinOp(f, inst, "/", "div_trunc", .none),
            .rem => blk: {
                const bin_op = f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
                const lhs_scalar_ty = f.typeOf(bin_op.lhs).scalarType(mod);
                // For binary operations @TypeOf(lhs)==@TypeOf(rhs),
                // so we only check one.
                break :blk if (lhs_scalar_ty.isInt(mod))
                    try airBinOp(f, inst, "%", "rem", .none)
                else
                    try airBinFloatOp(f, inst, "fmod");
            },
            .div_floor => try airBinBuiltinCall(f, inst, "div_floor", .none),
            .mod       => try airBinBuiltinCall(f, inst, "mod", .none),
            .abs       => try airAbs(f, inst),

            .add_wrap => try airBinBuiltinCall(f, inst, "addw", .bits),
            .sub_wrap => try airBinBuiltinCall(f, inst, "subw", .bits),
            .mul_wrap => try airBinBuiltinCall(f, inst, "mulw", .bits),

            .add_sat => try airBinBuiltinCall(f, inst, "adds", .bits),
            .sub_sat => try airBinBuiltinCall(f, inst, "subs", .bits),
            .mul_sat => try airBinBuiltinCall(f, inst, "muls", .bits),
            .shl_sat => try airBinBuiltinCall(f, inst, "shls", .bits),

            .sqrt        => try airUnFloatOp(f, inst, "sqrt"),
            .sin         => try airUnFloatOp(f, inst, "sin"),
            .cos         => try airUnFloatOp(f, inst, "cos"),
            .tan         => try airUnFloatOp(f, inst, "tan"),
            .exp         => try airUnFloatOp(f, inst, "exp"),
            .exp2        => try airUnFloatOp(f, inst, "exp2"),
            .log         => try airUnFloatOp(f, inst, "log"),
            .log2        => try airUnFloatOp(f, inst, "log2"),
            .log10       => try airUnFloatOp(f, inst, "log10"),
            .floor       => try airUnFloatOp(f, inst, "floor"),
            .ceil        => try airUnFloatOp(f, inst, "ceil"),
            .round       => try airUnFloatOp(f, inst, "round"),
            .trunc_float => try airUnFloatOp(f, inst, "trunc"),

            .mul_add => try airMulAdd(f, inst),

            .add_with_overflow => try airOverflow(f, inst, "add", .bits),
            .sub_with_overflow => try airOverflow(f, inst, "sub", .bits),
            .mul_with_overflow => try airOverflow(f, inst, "mul", .bits),
            .shl_with_overflow => try airOverflow(f, inst, "shl", .bits),

            .min => try airMinMax(f, inst, '<', "fmin"),
            .max => try airMinMax(f, inst, '>', "fmax"),

            .slice => try airSlice(f, inst),

            .cmp_gt  => try airCmpOp(f, inst, f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op, .gt),
            .cmp_gte => try airCmpOp(f, inst, f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op, .gte),
            .cmp_lt  => try airCmpOp(f, inst, f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op, .lt),
            .cmp_lte => try airCmpOp(f, inst, f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op, .lte),

            .cmp_eq  => try airEquality(f, inst, .eq),
            .cmp_neq => try airEquality(f, inst, .neq),

            .cmp_vector => blk: {
                const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
                const extra = f.air.extraData(Air.VectorCmp, ty_pl.payload).data;
                break :blk try airCmpOp(f, inst, extra, extra.compareOperator());
            },
            .cmp_lt_errors_len => try airCmpLtErrorsLen(f, inst),

            // bool_and and bool_or are non-short-circuit operations
            .bool_and, .bit_and => try airBinOp(f, inst, "&",  "and", .none),
            .bool_or,  .bit_or  => try airBinOp(f, inst, "|",  "or",  .none),
            .xor                => try airBinOp(f, inst, "^",  "xor", .none),
            .shr, .shr_exact    => try airBinBuiltinCall(f, inst, "shr", .none),
            .shl,               => try airBinBuiltinCall(f, inst, "shlw", .bits),
            .shl_exact          => try airBinOp(f, inst, "<<", "shl", .none),
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
            .int_from_bool      => try airIntFromBool(f, inst),
            .load             => try airLoad(f, inst),
            .ret              => try airRet(f, inst, false),
            .ret_safe         => try airRet(f, inst, false), // TODO
            .ret_load         => try airRet(f, inst, true),
            .store            => try airStore(f, inst, false),
            .store_safe       => try airStore(f, inst, true),
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
            .memset           => try airMemset(f, inst, false),
            .memset_safe      => try airMemset(f, inst, true),
            .memcpy           => try airMemcpy(f, inst),
            .set_union_tag    => try airSetUnionTag(f, inst),
            .get_union_tag    => try airGetUnionTag(f, inst),
            .clz              => try airUnBuiltinCall(f, inst, "clz", .bits),
            .ctz              => try airUnBuiltinCall(f, inst, "ctz", .bits),
            .popcount         => try airUnBuiltinCall(f, inst, "popcount", .bits),
            .byte_swap        => try airUnBuiltinCall(f, inst, "byte_swap", .bits),
            .bit_reverse      => try airUnBuiltinCall(f, inst, "bit_reverse", .bits),
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

            .float_from_int,
            .int_from_float,
            .fptrunc,
            .fpext,
            => try airFloatCast(f, inst),

            .int_from_ptr => try airIntFromPtr(f, inst),

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
            .sub_optimized,
            .mul_optimized,
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
            .int_from_float_optimized,
            => return f.fail("TODO implement optimized float mode", .{}),

            .add_safe,
            .sub_safe,
            .mul_safe,
            => return f.fail("TODO implement safety_checked_instructions", .{}),

            .is_named_enum_value => return f.fail("TODO: C backend: implement is_named_enum_value", .{}),
            .error_set_has_value => return f.fail("TODO: C backend: implement error_set_has_value", .{}),
            .vector_store_elem => return f.fail("TODO: C backend: implement vector_store_elem", .{}),

            .c_va_start => try airCVaStart(f, inst),
            .c_va_arg => try airCVaArg(f, inst),
            .c_va_end => try airCVaEnd(f, inst),
            .c_va_copy => try airCVaCopy(f, inst),

            .work_item_id,
            .work_group_size,
            .work_group_id,
            => unreachable,
            // zig fmt: on
        };
        if (result_value == .new_local) {
            log.debug("map %{d} to t{d}", .{ inst, result_value.new_local });
        }
        try f.value_map.putNoClobber(inst.toRef(), switch (result_value) {
            .none => continue,
            .new_local => |i| .{ .local = i },
            else => result_value,
        });
    }
}

fn airSliceField(f: *Function, inst: Air.Inst.Index, is_ptr: bool, field_name: []const u8) !CValue {
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const inst_ty = f.typeOfIndex(inst);
    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const a = try Assignment.start(f, writer, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try a.assign(f, writer);
    if (is_ptr) {
        try writer.writeByte('&');
        try f.writeCValueDerefMember(writer, operand, .{ .identifier = field_name });
    } else try f.writeCValueMember(writer, operand, .{ .identifier = field_name });
    try a.end(f, writer);
    return local;
}

fn airPtrElemVal(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const inst_ty = f.typeOfIndex(inst);
    const bin_op = f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    if (!inst_ty.hasRuntimeBitsIgnoreComptime(mod)) {
        try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
        return .none;
    }

    const ptr = try f.resolveInst(bin_op.lhs);
    const index = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const a = try Assignment.start(f, writer, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try a.assign(f, writer);
    try f.writeCValue(writer, ptr, .Other);
    try writer.writeByte('[');
    try f.writeCValue(writer, index, .Other);
    try writer.writeByte(']');
    try a.end(f, writer);
    return local;
}

fn airPtrElemPtr(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = f.air.extraData(Air.Bin, ty_pl.payload).data;

    const inst_ty = f.typeOfIndex(inst);
    const ptr_ty = f.typeOf(bin_op.lhs);
    const elem_ty = ptr_ty.childType(mod);
    const elem_has_bits = elem_ty.hasRuntimeBitsIgnoreComptime(mod);

    const ptr = try f.resolveInst(bin_op.lhs);
    const index = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const a = try Assignment.start(f, writer, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try a.assign(f, writer);
    try writer.writeByte('(');
    try f.renderType(writer, inst_ty);
    try writer.writeByte(')');
    if (elem_has_bits) try writer.writeByte('&');
    if (elem_has_bits and ptr_ty.ptrSize(mod) == .One) {
        // It's a pointer to an array, so we need to de-reference.
        try f.writeCValueDeref(writer, ptr);
    } else try f.writeCValue(writer, ptr, .Other);
    if (elem_has_bits) {
        try writer.writeByte('[');
        try f.writeCValue(writer, index, .Other);
        try writer.writeByte(']');
    }
    try a.end(f, writer);
    return local;
}

fn airSliceElemVal(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const inst_ty = f.typeOfIndex(inst);
    const bin_op = f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    if (!inst_ty.hasRuntimeBitsIgnoreComptime(mod)) {
        try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
        return .none;
    }

    const slice = try f.resolveInst(bin_op.lhs);
    const index = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const a = try Assignment.start(f, writer, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try a.assign(f, writer);
    try f.writeCValueMember(writer, slice, .{ .identifier = "ptr" });
    try writer.writeByte('[');
    try f.writeCValue(writer, index, .Other);
    try writer.writeByte(']');
    try a.end(f, writer);
    return local;
}

fn airSliceElemPtr(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = f.air.extraData(Air.Bin, ty_pl.payload).data;

    const inst_ty = f.typeOfIndex(inst);
    const slice_ty = f.typeOf(bin_op.lhs);
    const elem_ty = slice_ty.elemType2(mod);
    const elem_has_bits = elem_ty.hasRuntimeBitsIgnoreComptime(mod);

    const slice = try f.resolveInst(bin_op.lhs);
    const index = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const a = try Assignment.start(f, writer, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try a.assign(f, writer);
    if (elem_has_bits) try writer.writeByte('&');
    try f.writeCValueMember(writer, slice, .{ .identifier = "ptr" });
    if (elem_has_bits) {
        try writer.writeByte('[');
        try f.writeCValue(writer, index, .Other);
        try writer.writeByte(']');
    }
    try a.end(f, writer);
    return local;
}

fn airArrayElemVal(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const bin_op = f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const inst_ty = f.typeOfIndex(inst);
    if (!inst_ty.hasRuntimeBitsIgnoreComptime(mod)) {
        try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
        return .none;
    }

    const array = try f.resolveInst(bin_op.lhs);
    const index = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const a = try Assignment.start(f, writer, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try a.assign(f, writer);
    try f.writeCValue(writer, array, .Other);
    try writer.writeByte('[');
    try f.writeCValue(writer, index, .Other);
    try writer.writeByte(']');
    try a.end(f, writer);
    return local;
}

fn airAlloc(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const inst_ty = f.typeOfIndex(inst);
    const elem_type = inst_ty.childType(mod);
    if (!elem_type.isFnOrHasRuntimeBitsIgnoreComptime(mod)) return .{ .undef = inst_ty };

    const local = try f.allocLocalValue(
        elem_type,
        inst_ty.ptrAlignment(mod),
    );
    log.debug("%{d}: allocated unfreeable t{d}", .{ inst, local.new_local });
    const gpa = f.object.dg.module.gpa;
    try f.allocs.put(gpa, local.new_local, true);
    return .{ .local_ref = local.new_local };
}

fn airRetPtr(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const inst_ty = f.typeOfIndex(inst);
    const elem_ty = inst_ty.childType(mod);
    if (!elem_ty.isFnOrHasRuntimeBitsIgnoreComptime(mod)) return .{ .undef = inst_ty };

    const local = try f.allocLocalValue(
        elem_ty,
        inst_ty.ptrAlignment(mod),
    );
    log.debug("%{d}: allocated unfreeable t{d}", .{ inst, local.new_local });
    const gpa = f.object.dg.module.gpa;
    try f.allocs.put(gpa, local.new_local, true);
    return .{ .local_ref = local.new_local };
}

fn airArg(f: *Function, inst: Air.Inst.Index) !CValue {
    const inst_ty = f.typeOfIndex(inst);
    const inst_cty = try f.typeToIndex(inst_ty, .parameter);

    const i = f.next_arg_index;
    f.next_arg_index += 1;
    const result: CValue = if (inst_cty != try f.typeToIndex(inst_ty, .complete))
        .{ .arg_array = i }
    else
        .{ .arg = i };

    if (f.liveness.isUnused(inst)) {
        const writer = f.object.writer();
        try writer.writeByte('(');
        try f.renderType(writer, Type.void);
        try writer.writeByte(')');
        try f.writeCValue(writer, result, .Other);
        try writer.writeAll(";\n");
        return .none;
    }

    return result;
}

fn airLoad(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const ptr_ty = f.typeOf(ty_op.operand);
    const ptr_scalar_ty = ptr_ty.scalarType(mod);
    const ptr_info = ptr_scalar_ty.ptrInfo(mod);
    const src_ty = Type.fromInterned(ptr_info.child);

    if (!src_ty.hasRuntimeBitsIgnoreComptime(mod)) {
        try reap(f, inst, &.{ty_op.operand});
        return .none;
    }

    const operand = try f.resolveInst(ty_op.operand);

    try reap(f, inst, &.{ty_op.operand});

    const is_aligned = if (ptr_info.flags.alignment != .none)
        ptr_info.flags.alignment.compare(.gte, src_ty.abiAlignment(mod))
    else
        true;
    const is_array = lowersToArray(src_ty, mod);
    const need_memcpy = !is_aligned or is_array;

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, src_ty);
    const v = try Vectorize.start(f, inst, writer, ptr_ty);

    if (need_memcpy) {
        try writer.writeAll("memcpy(");
        if (!is_array) try writer.writeByte('&');
        try f.writeCValue(writer, local, .Other);
        try v.elem(f, writer);
        try writer.writeAll(", (const char *)");
        try f.writeCValue(writer, operand, .Other);
        try v.elem(f, writer);
        try writer.writeAll(", sizeof(");
        try f.renderType(writer, src_ty);
        try writer.writeAll("))");
    } else if (ptr_info.packed_offset.host_size > 0 and ptr_info.flags.vector_index == .none) {
        const host_bits: u16 = ptr_info.packed_offset.host_size * 8;
        const host_ty = try mod.intType(.unsigned, host_bits);

        const bit_offset_ty = try mod.intType(.unsigned, Type.smallestUnsignedBits(host_bits - 1));
        const bit_offset_val = try mod.intValue(bit_offset_ty, ptr_info.packed_offset.bit_offset);

        const field_ty = try mod.intType(.unsigned, @as(u16, @intCast(src_ty.bitSize(mod))));

        try f.writeCValue(writer, local, .Other);
        try v.elem(f, writer);
        try writer.writeAll(" = (");
        try f.renderType(writer, src_ty);
        try writer.writeAll(")zig_wrap_");
        try f.object.dg.renderTypeForBuiltinFnName(writer, field_ty);
        try writer.writeAll("((");
        try f.renderType(writer, field_ty);
        try writer.writeByte(')');
        const cant_cast = host_ty.isInt(mod) and host_ty.bitSize(mod) > 64;
        if (cant_cast) {
            if (field_ty.bitSize(mod) > 64) return f.fail("TODO: C backend: implement casting between types > 64 bits", .{});
            try writer.writeAll("zig_lo_");
            try f.object.dg.renderTypeForBuiltinFnName(writer, host_ty);
            try writer.writeByte('(');
        }
        try writer.writeAll("zig_shr_");
        try f.object.dg.renderTypeForBuiltinFnName(writer, host_ty);
        try writer.writeByte('(');
        try f.writeCValueDeref(writer, operand);
        try v.elem(f, writer);
        try writer.print(", {})", .{try f.fmtIntLiteral(bit_offset_ty, bit_offset_val)});
        if (cant_cast) try writer.writeByte(')');
        try f.object.dg.renderBuiltinInfo(writer, field_ty, .bits);
        try writer.writeByte(')');
    } else {
        try f.writeCValue(writer, local, .Other);
        try v.elem(f, writer);
        try writer.writeAll(" = ");
        try f.writeCValueDeref(writer, operand);
        try v.elem(f, writer);
    }
    try writer.writeAll(";\n");
    try v.end(f, inst, writer);

    return local;
}

fn airRet(f: *Function, inst: Air.Inst.Index, is_ptr: bool) !CValue {
    const mod = f.object.dg.module;
    const un_op = f.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const writer = f.object.writer();
    const op_inst = un_op.toIndex();
    const op_ty = f.typeOf(un_op);
    const ret_ty = if (is_ptr) op_ty.childType(mod) else op_ty;
    const lowered_ret_ty = try lowerFnRetTy(ret_ty, mod);

    if (op_inst != null and f.air.instructions.items(.tag)[@intFromEnum(op_inst.?)] == .call_always_tail) {
        try reap(f, inst, &.{un_op});
        _ = try airCall(f, op_inst.?, .always_tail);
    } else if (lowered_ret_ty.hasRuntimeBitsIgnoreComptime(mod)) {
        const operand = try f.resolveInst(un_op);
        try reap(f, inst, &.{un_op});
        var deref = is_ptr;
        const is_array = lowersToArray(ret_ty, mod);
        const ret_val = if (is_array) ret_val: {
            const array_local = try f.allocLocal(inst, lowered_ret_ty);
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
            try freeLocal(f, inst, ret_val.new_local, null);
        }
    } else {
        try reap(f, inst, &.{un_op});
        // Not even allowed to return void in a naked function.
        if (!f.object.dg.is_naked_fn) try writer.writeAll("return;\n");
    }
    return .none;
}

fn airIntCast(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});

    const inst_ty = f.typeOfIndex(inst);
    const inst_scalar_ty = inst_ty.scalarType(mod);
    const operand_ty = f.typeOf(ty_op.operand);
    const scalar_ty = operand_ty.scalarType(mod);

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const v = try Vectorize.start(f, inst, writer, operand_ty);
    const a = try Assignment.start(f, writer, scalar_ty);
    try f.writeCValue(writer, local, .Other);
    try v.elem(f, writer);
    try a.assign(f, writer);
    try f.renderIntCast(writer, inst_scalar_ty, operand, v, scalar_ty, .Other);
    try a.end(f, writer);
    try v.end(f, inst, writer);

    return local;
}

fn airTrunc(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const inst_ty = f.typeOfIndex(inst);
    const inst_scalar_ty = inst_ty.scalarType(mod);
    const dest_int_info = inst_scalar_ty.intInfo(mod);
    const dest_bits = dest_int_info.bits;
    const dest_c_bits = toCIntBits(dest_int_info.bits) orelse
        return f.fail("TODO: C backend: implement integer types larger than 128 bits", .{});
    const operand_ty = f.typeOf(ty_op.operand);
    const scalar_ty = operand_ty.scalarType(mod);
    const scalar_int_info = scalar_ty.intInfo(mod);

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const v = try Vectorize.start(f, inst, writer, operand_ty);

    try f.writeCValue(writer, local, .Other);
    try v.elem(f, writer);
    try writer.writeAll(" = ");

    if (dest_c_bits < 64) {
        try writer.writeByte('(');
        try f.renderType(writer, inst_scalar_ty);
        try writer.writeByte(')');
    }

    const needs_lo = scalar_int_info.bits > 64 and dest_bits <= 64;
    if (needs_lo) {
        try writer.writeAll("zig_lo_");
        try f.object.dg.renderTypeForBuiltinFnName(writer, scalar_ty);
        try writer.writeByte('(');
    }

    if (dest_bits >= 8 and std.math.isPowerOfTwo(dest_bits)) {
        try f.writeCValue(writer, operand, .Other);
        try v.elem(f, writer);
    } else switch (dest_int_info.signedness) {
        .unsigned => {
            const mask_val = try inst_scalar_ty.maxIntScalar(mod, scalar_ty);
            try writer.writeAll("zig_and_");
            try f.object.dg.renderTypeForBuiltinFnName(writer, scalar_ty);
            try writer.writeByte('(');
            try f.writeCValue(writer, operand, .FunctionArgument);
            try v.elem(f, writer);
            try writer.print(", {x})", .{try f.fmtIntLiteral(scalar_ty, mask_val)});
        },
        .signed => {
            const c_bits = toCIntBits(scalar_int_info.bits) orelse
                return f.fail("TODO: C backend: implement integer types larger than 128 bits", .{});
            const shift_val = try mod.intValue(Type.u8, c_bits - dest_bits);

            try writer.writeAll("zig_shr_");
            try f.object.dg.renderTypeForBuiltinFnName(writer, scalar_ty);
            if (c_bits == 128) {
                try writer.print("(zig_bitCast_i{d}(", .{c_bits});
            } else {
                try writer.print("((int{d}_t)", .{c_bits});
            }
            try writer.print("zig_shl_u{d}(", .{c_bits});
            if (c_bits == 128) {
                try writer.print("zig_bitCast_u{d}(", .{c_bits});
            } else {
                try writer.print("(uint{d}_t)", .{c_bits});
            }
            try f.writeCValue(writer, operand, .FunctionArgument);
            try v.elem(f, writer);
            if (c_bits == 128) try writer.writeByte(')');
            try writer.print(", {})", .{try f.fmtIntLiteral(Type.u8, shift_val)});
            if (c_bits == 128) try writer.writeByte(')');
            try writer.print(", {})", .{try f.fmtIntLiteral(Type.u8, shift_val)});
        },
    }

    if (needs_lo) try writer.writeByte(')');
    try writer.writeAll(";\n");
    try v.end(f, inst, writer);

    return local;
}

fn airIntFromBool(f: *Function, inst: Air.Inst.Index) !CValue {
    const un_op = f.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try f.resolveInst(un_op);
    try reap(f, inst, &.{un_op});
    const writer = f.object.writer();
    const inst_ty = f.typeOfIndex(inst);
    const local = try f.allocLocal(inst, inst_ty);
    const a = try Assignment.start(f, writer, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try a.assign(f, writer);
    try f.writeCValue(writer, operand, .Other);
    try a.end(f, writer);
    return local;
}

fn airStore(f: *Function, inst: Air.Inst.Index, safety: bool) !CValue {
    const mod = f.object.dg.module;
    // *a = b;
    const bin_op = f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const ptr_ty = f.typeOf(bin_op.lhs);
    const ptr_scalar_ty = ptr_ty.scalarType(mod);
    const ptr_info = ptr_scalar_ty.ptrInfo(mod);

    const ptr_val = try f.resolveInst(bin_op.lhs);
    const src_ty = f.typeOf(bin_op.rhs);

    const val_is_undef = if (try f.air.value(bin_op.rhs, mod)) |v| v.isUndefDeep(mod) else false;

    if (val_is_undef) {
        try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
        if (safety and ptr_info.packed_offset.host_size == 0) {
            const writer = f.object.writer();
            try writer.writeAll("memset(");
            try f.writeCValue(writer, ptr_val, .FunctionArgument);
            try writer.writeAll(", 0xaa, sizeof(");
            try f.renderType(writer, Type.fromInterned(ptr_info.child));
            try writer.writeAll("));\n");
        }
        return .none;
    }

    const is_aligned = if (ptr_info.flags.alignment != .none)
        ptr_info.flags.alignment.compare(.gte, src_ty.abiAlignment(mod))
    else
        true;
    const is_array = lowersToArray(Type.fromInterned(ptr_info.child), mod);
    const need_memcpy = !is_aligned or is_array;

    const src_val = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const writer = f.object.writer();
    const v = try Vectorize.start(f, inst, writer, ptr_ty);

    if (need_memcpy) {
        // For this memcpy to safely work we need the rhs to have the same
        // underlying type as the lhs (i.e. they must both be arrays of the same underlying type).
        assert(src_ty.eql(Type.fromInterned(ptr_info.child), f.object.dg.module));

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
        try v.elem(f, writer);
        try writer.writeAll(", ");
        if (!is_array) try writer.writeByte('&');
        try f.writeCValue(writer, array_src, .FunctionArgument);
        try v.elem(f, writer);
        try writer.writeAll(", sizeof(");
        try f.renderType(writer, src_ty);
        try writer.writeAll("))");
        if (src_val == .constant) {
            try freeLocal(f, inst, array_src.new_local, null);
        }
    } else if (ptr_info.packed_offset.host_size > 0 and ptr_info.flags.vector_index == .none) {
        const host_bits = ptr_info.packed_offset.host_size * 8;
        const host_ty = try mod.intType(.unsigned, host_bits);

        const bit_offset_ty = try mod.intType(.unsigned, Type.smallestUnsignedBits(host_bits - 1));
        const bit_offset_val = try mod.intValue(bit_offset_ty, ptr_info.packed_offset.bit_offset);

        const src_bits = src_ty.bitSize(mod);

        const ExpectedContents = [BigInt.Managed.default_capacity]BigIntLimb;
        var stack align(@alignOf(ExpectedContents)) =
            std.heap.stackFallback(@sizeOf(ExpectedContents), f.object.dg.gpa);

        var mask = try BigInt.Managed.initCapacity(stack.get(), BigInt.calcTwosCompLimbCount(host_bits));
        defer mask.deinit();

        try mask.setTwosCompIntLimit(.max, .unsigned, @as(usize, @intCast(src_bits)));
        try mask.shiftLeft(&mask, ptr_info.packed_offset.bit_offset);
        try mask.bitNotWrap(&mask, .unsigned, host_bits);

        const mask_val = try mod.intValue_big(host_ty, mask.toConst());

        try f.writeCValueDeref(writer, ptr_val);
        try v.elem(f, writer);
        try writer.writeAll(" = zig_or_");
        try f.object.dg.renderTypeForBuiltinFnName(writer, host_ty);
        try writer.writeAll("(zig_and_");
        try f.object.dg.renderTypeForBuiltinFnName(writer, host_ty);
        try writer.writeByte('(');
        try f.writeCValueDeref(writer, ptr_val);
        try v.elem(f, writer);
        try writer.print(", {x}), zig_shl_", .{try f.fmtIntLiteral(host_ty, mask_val)});
        try f.object.dg.renderTypeForBuiltinFnName(writer, host_ty);
        try writer.writeByte('(');
        const cant_cast = host_ty.isInt(mod) and host_ty.bitSize(mod) > 64;
        if (cant_cast) {
            if (src_ty.bitSize(mod) > 64) return f.fail("TODO: C backend: implement casting between types > 64 bits", .{});
            try writer.writeAll("zig_make_");
            try f.object.dg.renderTypeForBuiltinFnName(writer, host_ty);
            try writer.writeAll("(0, ");
        } else {
            try writer.writeByte('(');
            try f.renderType(writer, host_ty);
            try writer.writeByte(')');
        }

        if (src_ty.isPtrAtRuntime(mod)) {
            try writer.writeByte('(');
            try f.renderType(writer, Type.usize);
            try writer.writeByte(')');
        }
        try f.writeCValue(writer, src_val, .Other);
        try v.elem(f, writer);
        if (cant_cast) try writer.writeByte(')');
        try writer.print(", {}))", .{try f.fmtIntLiteral(bit_offset_ty, bit_offset_val)});
    } else {
        try f.writeCValueDeref(writer, ptr_val);
        try v.elem(f, writer);
        try writer.writeAll(" = ");
        try f.writeCValue(writer, src_val, .Other);
        try v.elem(f, writer);
    }
    try writer.writeAll(";\n");
    try v.end(f, inst, writer);

    return .none;
}

fn airOverflow(f: *Function, inst: Air.Inst.Index, operation: []const u8, info: BuiltinInfo) !CValue {
    const mod = f.object.dg.module;
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = f.air.extraData(Air.Bin, ty_pl.payload).data;

    const lhs = try f.resolveInst(bin_op.lhs);
    const rhs = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const inst_ty = f.typeOfIndex(inst);
    const operand_ty = f.typeOf(bin_op.lhs);
    const scalar_ty = operand_ty.scalarType(mod);

    const w = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const v = try Vectorize.start(f, inst, w, operand_ty);
    try f.writeCValueMember(w, local, .{ .field = 1 });
    try v.elem(f, w);
    try w.writeAll(" = zig_");
    try w.writeAll(operation);
    try w.writeAll("o_");
    try f.object.dg.renderTypeForBuiltinFnName(w, scalar_ty);
    try w.writeAll("(&");
    try f.writeCValueMember(w, local, .{ .field = 0 });
    try v.elem(f, w);
    try w.writeAll(", ");
    try f.writeCValue(w, lhs, .FunctionArgument);
    try v.elem(f, w);
    try w.writeAll(", ");
    try f.writeCValue(w, rhs, .FunctionArgument);
    try v.elem(f, w);
    try f.object.dg.renderBuiltinInfo(w, scalar_ty, info);
    try w.writeAll(");\n");
    try v.end(f, inst, w);

    return local;
}

fn airNot(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const operand_ty = f.typeOf(ty_op.operand);
    const scalar_ty = operand_ty.scalarType(mod);
    if (scalar_ty.ip_index != .bool_type) return try airUnBuiltinCall(f, inst, "not", .bits);

    const op = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});

    const inst_ty = f.typeOfIndex(inst);

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const v = try Vectorize.start(f, inst, writer, operand_ty);
    try f.writeCValue(writer, local, .Other);
    try v.elem(f, writer);
    try writer.writeAll(" = ");
    try writer.writeByte('!');
    try f.writeCValue(writer, op, .Other);
    try v.elem(f, writer);
    try writer.writeAll(";\n");
    try v.end(f, inst, writer);

    return local;
}

fn airBinOp(
    f: *Function,
    inst: Air.Inst.Index,
    operator: []const u8,
    operation: []const u8,
    info: BuiltinInfo,
) !CValue {
    const mod = f.object.dg.module;
    const bin_op = f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const operand_ty = f.typeOf(bin_op.lhs);
    const scalar_ty = operand_ty.scalarType(mod);
    if ((scalar_ty.isInt(mod) and scalar_ty.bitSize(mod) > 64) or scalar_ty.isRuntimeFloat())
        return try airBinBuiltinCall(f, inst, operation, info);

    const lhs = try f.resolveInst(bin_op.lhs);
    const rhs = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const inst_ty = f.typeOfIndex(inst);

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const v = try Vectorize.start(f, inst, writer, operand_ty);
    try f.writeCValue(writer, local, .Other);
    try v.elem(f, writer);
    try writer.writeAll(" = ");
    try f.writeCValue(writer, lhs, .Other);
    try v.elem(f, writer);
    try writer.writeByte(' ');
    try writer.writeAll(operator);
    try writer.writeByte(' ');
    try f.writeCValue(writer, rhs, .Other);
    try v.elem(f, writer);
    try writer.writeAll(";\n");
    try v.end(f, inst, writer);

    return local;
}

fn airCmpOp(
    f: *Function,
    inst: Air.Inst.Index,
    data: anytype,
    operator: std.math.CompareOperator,
) !CValue {
    const mod = f.object.dg.module;
    const lhs_ty = f.typeOf(data.lhs);
    const scalar_ty = lhs_ty.scalarType(mod);

    const scalar_bits = scalar_ty.bitSize(mod);
    if (scalar_ty.isInt(mod) and scalar_bits > 64)
        return airCmpBuiltinCall(
            f,
            inst,
            data,
            operator,
            .cmp,
            if (scalar_bits > 128) .bits else .none,
        );
    if (scalar_ty.isRuntimeFloat())
        return airCmpBuiltinCall(f, inst, data, operator, .operator, .none);

    const inst_ty = f.typeOfIndex(inst);
    const lhs = try f.resolveInst(data.lhs);
    const rhs = try f.resolveInst(data.rhs);
    try reap(f, inst, &.{ data.lhs, data.rhs });

    const rhs_ty = f.typeOf(data.rhs);
    const need_cast = lhs_ty.isSinglePointer(mod) or rhs_ty.isSinglePointer(mod);
    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const v = try Vectorize.start(f, inst, writer, lhs_ty);
    try f.writeCValue(writer, local, .Other);
    try v.elem(f, writer);
    try writer.writeAll(" = ");
    if (need_cast) try writer.writeAll("(void*)");
    try f.writeCValue(writer, lhs, .Other);
    try v.elem(f, writer);
    try writer.writeByte(' ');
    try writer.writeAll(compareOperatorC(operator));
    try writer.writeByte(' ');
    if (need_cast) try writer.writeAll("(void*)");
    try f.writeCValue(writer, rhs, .Other);
    try v.elem(f, writer);
    try writer.writeAll(";\n");
    try v.end(f, inst, writer);

    return local;
}

fn airEquality(
    f: *Function,
    inst: Air.Inst.Index,
    operator: std.math.CompareOperator,
) !CValue {
    const mod = f.object.dg.module;
    const bin_op = f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const operand_ty = f.typeOf(bin_op.lhs);
    const operand_bits = operand_ty.bitSize(mod);
    if (operand_ty.isInt(mod) and operand_bits > 64)
        return airCmpBuiltinCall(
            f,
            inst,
            bin_op,
            operator,
            .cmp,
            if (operand_bits > 128) .bits else .none,
        );
    if (operand_ty.isRuntimeFloat())
        return airCmpBuiltinCall(f, inst, bin_op, operator, .operator, .none);

    const lhs = try f.resolveInst(bin_op.lhs);
    const rhs = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const writer = f.object.writer();
    const inst_ty = f.typeOfIndex(inst);
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = ");

    if (operand_ty.zigTypeTag(mod) == .Optional and !operand_ty.optionalReprIsPayload(mod)) {
        // (A && B)  || (C && (A == B))
        // A = lhs.is_null  ;  B = rhs.is_null  ;  C = rhs.payload == lhs.payload

        switch (operator) {
            .eq => {},
            .neq => try writer.writeByte('!'),
            else => unreachable,
        }
        try writer.writeAll("((");
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
    try writer.writeAll(compareOperatorC(operator));
    try writer.writeByte(' ');
    try f.writeCValue(writer, rhs, .Other);
    try writer.writeAll(";\n");

    return local;
}

fn airCmpLtErrorsLen(f: *Function, inst: Air.Inst.Index) !CValue {
    const un_op = f.air.instructions.items(.data)[@intFromEnum(inst)].un_op;

    const inst_ty = f.typeOfIndex(inst);
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
    const mod = f.object.dg.module;
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = f.air.extraData(Air.Bin, ty_pl.payload).data;

    const lhs = try f.resolveInst(bin_op.lhs);
    const rhs = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const inst_ty = f.typeOfIndex(inst);
    const inst_scalar_ty = inst_ty.scalarType(mod);
    const elem_ty = inst_scalar_ty.elemType2(mod);

    const local = try f.allocLocal(inst, inst_ty);
    const writer = f.object.writer();
    const v = try Vectorize.start(f, inst, writer, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try v.elem(f, writer);
    try writer.writeAll(" = ");

    if (elem_ty.hasRuntimeBitsIgnoreComptime(mod)) {
        // We must convert to and from integer types to prevent UB if the operation
        // results in a NULL pointer, or if LHS is NULL. The operation is only UB
        // if the result is NULL and then dereferenced.
        try writer.writeByte('(');
        try f.renderType(writer, inst_scalar_ty);
        try writer.writeAll(")(((uintptr_t)");
        try f.writeCValue(writer, lhs, .Other);
        try v.elem(f, writer);
        try writer.writeAll(") ");
        try writer.writeByte(operator);
        try writer.writeAll(" (");
        try f.writeCValue(writer, rhs, .Other);
        try v.elem(f, writer);
        try writer.writeAll("*sizeof(");
        try f.renderType(writer, elem_ty);
        try writer.writeAll(")))");
    } else {
        try f.writeCValue(writer, lhs, .Other);
        try v.elem(f, writer);
    }

    try writer.writeAll(";\n");
    try v.end(f, inst, writer);

    return local;
}

fn airMinMax(f: *Function, inst: Air.Inst.Index, operator: u8, operation: []const u8) !CValue {
    const mod = f.object.dg.module;
    const bin_op = f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const inst_ty = f.typeOfIndex(inst);
    const inst_scalar_ty = inst_ty.scalarType(mod);

    if (inst_scalar_ty.isInt(mod) and inst_scalar_ty.bitSize(mod) > 64)
        return try airBinBuiltinCall(f, inst, operation[1..], .none);
    if (inst_scalar_ty.isRuntimeFloat())
        return try airBinFloatOp(f, inst, operation);

    const lhs = try f.resolveInst(bin_op.lhs);
    const rhs = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const v = try Vectorize.start(f, inst, writer, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try v.elem(f, writer);
    // (lhs <> rhs) ? lhs : rhs
    try writer.writeAll(" = (");
    try f.writeCValue(writer, lhs, .Other);
    try v.elem(f, writer);
    try writer.writeByte(' ');
    try writer.writeByte(operator);
    try writer.writeByte(' ');
    try f.writeCValue(writer, rhs, .Other);
    try v.elem(f, writer);
    try writer.writeAll(") ? ");
    try f.writeCValue(writer, lhs, .Other);
    try v.elem(f, writer);
    try writer.writeAll(" : ");
    try f.writeCValue(writer, rhs, .Other);
    try v.elem(f, writer);
    try writer.writeAll(";\n");
    try v.end(f, inst, writer);

    return local;
}

fn airSlice(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = f.air.extraData(Air.Bin, ty_pl.payload).data;

    const ptr = try f.resolveInst(bin_op.lhs);
    const len = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const inst_ty = f.typeOfIndex(inst);
    const ptr_ty = inst_ty.slicePtrFieldType(mod);

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    {
        const a = try Assignment.start(f, writer, ptr_ty);
        try f.writeCValueMember(writer, local, .{ .identifier = "ptr" });
        try a.assign(f, writer);
        try writer.writeByte('(');
        try f.renderType(writer, ptr_ty);
        try writer.writeByte(')');
        try f.writeCValue(writer, ptr, .Other);
        try a.end(f, writer);
    }
    {
        const a = try Assignment.start(f, writer, Type.usize);
        try f.writeCValueMember(writer, local, .{ .identifier = "len" });
        try a.assign(f, writer);
        try f.writeCValue(writer, len, .Other);
        try a.end(f, writer);
    }
    return local;
}

fn airCall(
    f: *Function,
    inst: Air.Inst.Index,
    modifier: std.builtin.CallModifier,
) !CValue {
    const mod = f.object.dg.module;
    // Not even allowed to call panic in a naked function.
    if (f.object.dg.is_naked_fn) return .none;

    const gpa = f.object.dg.gpa;
    const writer = f.object.writer();

    const pl_op = f.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const extra = f.air.extraData(Air.Call, pl_op.payload);
    const args = @as([]const Air.Inst.Ref, @ptrCast(f.air.extra[extra.end..][0..extra.data.args_len]));

    const resolved_args = try gpa.alloc(CValue, args.len);
    defer gpa.free(resolved_args);
    for (resolved_args, args) |*resolved_arg, arg| {
        const arg_ty = f.typeOf(arg);
        const arg_cty = try f.typeToIndex(arg_ty, .parameter);
        if (f.indexToCType(arg_cty).tag() == .void) {
            resolved_arg.* = .none;
            continue;
        }
        resolved_arg.* = try f.resolveInst(arg);
        if (arg_cty != try f.typeToIndex(arg_ty, .complete)) {
            const lowered_arg_ty = try lowerFnRetTy(arg_ty, mod);

            const array_local = try f.allocLocal(inst, lowered_arg_ty);
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

    const callee_ty = f.typeOf(pl_op.operand);
    const fn_ty = switch (callee_ty.zigTypeTag(mod)) {
        .Fn => callee_ty,
        .Pointer => callee_ty.childType(mod),
        else => unreachable,
    };

    const ret_ty = fn_ty.fnReturnType(mod);
    const lowered_ret_ty = try lowerFnRetTy(ret_ty, mod);

    const result_local = result: {
        if (modifier == .always_tail) {
            try writer.writeAll("zig_always_tail return ");
            break :result .none;
        } else if (!lowered_ret_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            break :result .none;
        } else if (f.liveness.isUnused(inst)) {
            try writer.writeByte('(');
            try f.renderType(writer, Type.void);
            try writer.writeByte(')');
            break :result .none;
        } else {
            const local = try f.allocLocal(inst, lowered_ret_ty);
            try f.writeCValue(writer, local, .Other);
            try writer.writeAll(" = ");
            break :result local;
        }
    };

    callee: {
        known: {
            const fn_decl = fn_decl: {
                const callee_val = (try f.air.value(pl_op.operand, mod)) orelse break :known;
                break :fn_decl switch (mod.intern_pool.indexToKey(callee_val.ip_index)) {
                    .extern_func => |extern_func| extern_func.decl,
                    .func => |func| func.owner_decl,
                    .ptr => |ptr| switch (ptr.addr) {
                        .decl => |decl| decl,
                        else => break :known,
                    },
                    else => break :known,
                };
            };
            switch (modifier) {
                .auto, .always_tail => try f.object.dg.renderDeclName(writer, fn_decl, 0),
                inline .never_tail, .never_inline => |m| try writer.writeAll(try f.getLazyFnName(
                    @unionInit(LazyFnKey, @tagName(m), fn_decl),
                    @unionInit(LazyFnValue.Data, @tagName(m), {}),
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
        if (resolved_arg == .new_local) try freeLocal(f, inst, resolved_arg.new_local, null);
        args_written += 1;
    }
    try writer.writeAll(");\n");

    const result = result: {
        if (result_local == .none or !lowersToArray(ret_ty, mod))
            break :result result_local;

        const array_local = try f.allocLocal(inst, ret_ty);
        try writer.writeAll("memcpy(");
        try f.writeCValue(writer, array_local, .FunctionArgument);
        try writer.writeAll(", ");
        try f.writeCValueMember(writer, result_local, .{ .identifier = "array" });
        try writer.writeAll(", sizeof(");
        try f.renderType(writer, ret_ty);
        try writer.writeAll("));\n");
        try freeLocal(f, inst, result_local.new_local, null);
        break :result array_local;
    };

    return result;
}

fn airDbgStmt(f: *Function, inst: Air.Inst.Index) !CValue {
    const dbg_stmt = f.air.instructions.items(.data)[@intFromEnum(inst)].dbg_stmt;
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
    const ty_fn = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_fn;
    const mod = f.object.dg.module;
    const writer = f.object.writer();
    const owner_decl = mod.funcOwnerDeclPtr(ty_fn.func);
    try writer.print("/* dbg func:{s} */\n", .{
        mod.intern_pool.stringToSlice(owner_decl.name),
    });
    return .none;
}

fn airDbgVar(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const pl_op = f.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const name = f.air.nullTerminatedString(pl_op.payload);
    const operand_is_undef = if (try f.air.value(pl_op.operand, mod)) |v| v.isUndefDeep(mod) else false;
    if (!operand_is_undef) _ = try f.resolveInst(pl_op.operand);

    try reap(f, inst, &.{pl_op.operand});
    const writer = f.object.writer();
    try writer.print("/* var:{s} */\n", .{name});
    return .none;
}

fn airBlock(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = f.air.extraData(Air.Block, ty_pl.payload);
    const body: []const Air.Inst.Index = @ptrCast(f.air.extra[extra.end..][0..extra.data.body_len]);
    const liveness_block = f.liveness.getBlock(inst);

    const block_id: usize = f.next_block_index;
    f.next_block_index += 1;
    const writer = f.object.writer();

    const inst_ty = f.typeOfIndex(inst);
    const result = if (inst_ty.hasRuntimeBitsIgnoreComptime(mod) and !f.liveness.isUnused(inst))
        try f.allocLocal(inst, inst_ty)
    else
        .none;

    try f.blocks.putNoClobber(f.object.dg.gpa, inst, .{
        .block_id = block_id,
        .result = result,
    });

    try genBodyResolveState(f, inst, &.{}, body, true);

    assert(f.blocks.remove(inst));

    // The body might result in some values we had beforehand being killed
    for (liveness_block.deaths) |death| {
        try die(f, inst, death.toRef());
    }

    try f.object.indent_writer.insertNewline();

    // noreturn blocks have no `br` instructions reaching them, so we don't want a label
    if (!f.typeOfIndex(inst).isNoReturn(mod)) {
        // label must be followed by an expression, include an empty one.
        try writer.print("zig_block_{d}:;\n", .{block_id});
    }

    return result;
}

fn airTry(f: *Function, inst: Air.Inst.Index) !CValue {
    const pl_op = f.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const extra = f.air.extraData(Air.Try, pl_op.payload);
    const body: []const Air.Inst.Index = @ptrCast(f.air.extra[extra.end..][0..extra.data.body_len]);
    const err_union_ty = f.typeOf(pl_op.operand);
    return lowerTry(f, inst, pl_op.operand, body, err_union_ty, false);
}

fn airTryPtr(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = f.air.extraData(Air.TryPtr, ty_pl.payload);
    const body: []const Air.Inst.Index = @ptrCast(f.air.extra[extra.end..][0..extra.data.body_len]);
    const err_union_ty = f.typeOf(extra.data.ptr).childType(mod);
    return lowerTry(f, inst, extra.data.ptr, body, err_union_ty, true);
}

fn lowerTry(
    f: *Function,
    inst: Air.Inst.Index,
    operand: Air.Inst.Ref,
    body: []const Air.Inst.Index,
    err_union_ty: Type,
    is_ptr: bool,
) !CValue {
    const mod = f.object.dg.module;
    const err_union = try f.resolveInst(operand);
    const inst_ty = f.typeOfIndex(inst);
    const liveness_condbr = f.liveness.getCondBr(inst);
    const writer = f.object.writer();
    const payload_ty = err_union_ty.errorUnionPayload(mod);
    const payload_has_bits = payload_ty.hasRuntimeBitsIgnoreComptime(mod);

    if (!err_union_ty.errorUnionSet(mod).errorSetIsEmpty(mod)) {
        try writer.writeAll("if (");
        if (!payload_has_bits) {
            if (is_ptr)
                try f.writeCValueDeref(writer, err_union)
            else
                try f.writeCValue(writer, err_union, .Other);
        } else {
            // Reap the operand so that it can be reused inside genBody.
            // Remember we must avoid calling reap() twice for the same operand
            // in this function.
            try reap(f, inst, &.{operand});
            if (is_ptr)
                try f.writeCValueDerefMember(writer, err_union, .{ .identifier = "error" })
            else
                try f.writeCValueMember(writer, err_union, .{ .identifier = "error" });
        }
        try writer.writeAll(") ");

        try genBodyResolveState(f, inst, liveness_condbr.else_deaths, body, false);
        try f.object.indent_writer.insertNewline();
    }

    // Now we have the "then branch" (in terms of the liveness data); process any deaths.
    for (liveness_condbr.then_deaths) |death| {
        try die(f, inst, death.toRef());
    }

    if (!payload_has_bits) {
        if (!is_ptr) {
            return .none;
        } else {
            return err_union;
        }
    }

    try reap(f, inst, &.{operand});

    if (f.liveness.isUnused(inst)) {
        return .none;
    }

    const local = try f.allocLocal(inst, inst_ty);
    const a = try Assignment.start(f, writer, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try a.assign(f, writer);
    if (is_ptr) {
        try writer.writeByte('&');
        try f.writeCValueDerefMember(writer, err_union, .{ .identifier = "payload" });
    } else try f.writeCValueMember(writer, err_union, .{ .identifier = "payload" });
    try a.end(f, writer);
    return local;
}

fn airBr(f: *Function, inst: Air.Inst.Index) !CValue {
    const branch = f.air.instructions.items(.data)[@intFromEnum(inst)].br;
    const block = f.blocks.get(branch.block_inst).?;
    const result = block.result;
    const writer = f.object.writer();

    // If result is .none then the value of the block is unused.
    if (result != .none) {
        const operand_ty = f.typeOf(branch.operand);
        const operand = try f.resolveInst(branch.operand);
        try reap(f, inst, &.{branch.operand});

        const a = try Assignment.start(f, writer, operand_ty);
        try f.writeCValue(writer, result, .Other);
        try a.assign(f, writer);
        try f.writeCValue(writer, operand, .Other);
        try a.end(f, writer);
    }

    try writer.print("goto zig_block_{d};\n", .{block.block_id});
    return .none;
}

fn airBitcast(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const dest_ty = f.typeOfIndex(inst);

    const operand = try f.resolveInst(ty_op.operand);
    const operand_ty = f.typeOf(ty_op.operand);

    const bitcasted = try bitcast(f, dest_ty, operand, operand_ty);
    try reap(f, inst, &.{ty_op.operand});
    return bitcasted.move(f, inst, dest_ty);
}

const LocalResult = struct {
    c_value: CValue,
    need_free: bool,

    fn move(lr: LocalResult, f: *Function, inst: Air.Inst.Index, dest_ty: Type) !CValue {
        const mod = f.object.dg.module;

        if (lr.need_free) {
            // Move the freshly allocated local to be owned by this instruction,
            // by returning it here instead of freeing it.
            return lr.c_value;
        }

        const local = try f.allocLocal(inst, dest_ty);
        try lr.free(f);
        const writer = f.object.writer();
        try f.writeCValue(writer, local, .Other);
        if (dest_ty.isAbiInt(mod)) {
            try writer.writeAll(" = ");
        } else {
            try writer.writeAll(" = (");
            try f.renderType(writer, dest_ty);
            try writer.writeByte(')');
        }
        try f.writeCValue(writer, lr.c_value, .Initializer);
        try writer.writeAll(";\n");
        return local;
    }

    fn free(lr: LocalResult, f: *Function) !void {
        if (lr.need_free) {
            try freeLocal(f, null, lr.c_value.new_local, null);
        }
    }
};

fn bitcast(f: *Function, dest_ty: Type, operand: CValue, operand_ty: Type) !LocalResult {
    const mod = f.object.dg.module;
    const target = mod.getTarget();
    const writer = f.object.writer();

    if (operand_ty.isAbiInt(mod) and dest_ty.isAbiInt(mod)) {
        const src_info = dest_ty.intInfo(mod);
        const dest_info = operand_ty.intInfo(mod);
        if (src_info.signedness == dest_info.signedness and
            src_info.bits == dest_info.bits)
        {
            return .{
                .c_value = operand,
                .need_free = false,
            };
        }
    }

    if (dest_ty.isPtrAtRuntime(mod) and operand_ty.isPtrAtRuntime(mod)) {
        const local = try f.allocLocal(null, dest_ty);
        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(" = (");
        try f.renderType(writer, dest_ty);
        try writer.writeByte(')');
        try f.writeCValue(writer, operand, .Other);
        try writer.writeAll(";\n");
        return .{
            .c_value = local,
            .need_free = true,
        };
    }

    const operand_lval = if (operand == .constant) blk: {
        const operand_local = try f.allocLocal(null, operand_ty);
        try f.writeCValue(writer, operand_local, .Other);
        if (operand_ty.isAbiInt(mod)) {
            try writer.writeAll(" = ");
        } else {
            try writer.writeAll(" = (");
            try f.renderType(writer, operand_ty);
            try writer.writeByte(')');
        }
        try f.writeCValue(writer, operand, .Initializer);
        try writer.writeAll(";\n");
        break :blk operand_local;
    } else operand;

    const local = try f.allocLocal(null, dest_ty);
    try writer.writeAll("memcpy(&");
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(", &");
    try f.writeCValue(writer, operand_lval, .Other);
    try writer.writeAll(", sizeof(");
    try f.renderType(
        writer,
        if (dest_ty.abiSize(mod) <= operand_ty.abiSize(mod)) dest_ty else operand_ty,
    );
    try writer.writeAll("));\n");

    // Ensure padding bits have the expected value.
    if (dest_ty.isAbiInt(mod)) {
        const dest_cty = try f.typeToCType(dest_ty, .complete);
        const dest_info = dest_ty.intInfo(mod);
        var bits: u16 = dest_info.bits;
        var wrap_cty: ?CType = null;
        var need_bitcasts = false;

        try f.writeCValue(writer, local, .Other);
        if (dest_cty.castTag(.array)) |pl| {
            try writer.print("[{d}]", .{switch (target.cpu.arch.endian()) {
                .little => pl.data.len - 1,
                .big => 0,
            }});
            const elem_cty = f.indexToCType(pl.data.elem_type);
            wrap_cty = elem_cty.toSignedness(dest_info.signedness);
            need_bitcasts = wrap_cty.?.tag() == .zig_i128;
            bits -= 1;
            bits %= @as(u16, @intCast(f.byteSize(elem_cty) * 8));
            bits += 1;
        }
        try writer.writeAll(" = ");
        if (need_bitcasts) {
            try writer.writeAll("zig_bitCast_");
            try f.object.dg.renderCTypeForBuiltinFnName(writer, wrap_cty.?.toUnsigned());
            try writer.writeByte('(');
        }
        try writer.writeAll("zig_wrap_");
        const info_ty = try mod.intType(dest_info.signedness, bits);
        if (wrap_cty) |cty|
            try f.object.dg.renderCTypeForBuiltinFnName(writer, cty)
        else
            try f.object.dg.renderTypeForBuiltinFnName(writer, info_ty);
        try writer.writeByte('(');
        if (need_bitcasts) {
            try writer.writeAll("zig_bitCast_");
            try f.object.dg.renderCTypeForBuiltinFnName(writer, wrap_cty.?);
            try writer.writeByte('(');
        }
        try f.writeCValue(writer, local, .Other);
        if (dest_cty.castTag(.array)) |pl| {
            try writer.print("[{d}]", .{switch (target.cpu.arch.endian()) {
                .little => pl.data.len - 1,
                .big => 0,
            }});
        }
        if (need_bitcasts) try writer.writeByte(')');
        try f.object.dg.renderBuiltinInfo(writer, info_ty, .bits);
        if (need_bitcasts) try writer.writeByte(')');
        try writer.writeAll(");\n");
    }

    if (operand == .constant) {
        try freeLocal(f, null, operand_lval.new_local, null);
    }

    return .{
        .c_value = local,
        .need_free = true,
    };
}

fn airTrap(f: *Function, writer: anytype) !CValue {
    // Not even allowed to call trap in a naked function.
    if (f.object.dg.is_naked_fn) return .none;

    try writer.writeAll("zig_trap();\n");
    return .none;
}

fn airBreakpoint(writer: anytype) !CValue {
    try writer.writeAll("zig_breakpoint();\n");
    return .none;
}

fn airRetAddr(f: *Function, inst: Air.Inst.Index) !CValue {
    const writer = f.object.writer();
    const local = try f.allocLocal(inst, Type.usize);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = (");
    try f.renderType(writer, Type.usize);
    try writer.writeAll(")zig_return_address();\n");
    return local;
}

fn airFrameAddress(f: *Function, inst: Air.Inst.Index) !CValue {
    const writer = f.object.writer();
    const local = try f.allocLocal(inst, Type.usize);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = (");
    try f.renderType(writer, Type.usize);
    try writer.writeAll(")zig_frame_address();\n");
    return local;
}

fn airFence(f: *Function, inst: Air.Inst.Index) !CValue {
    const atomic_order = f.air.instructions.items(.data)[@intFromEnum(inst)].fence;
    const writer = f.object.writer();

    try writer.writeAll("zig_fence(");
    try writeMemoryOrder(writer, atomic_order);
    try writer.writeAll(");\n");

    return .none;
}

fn airUnreach(f: *Function) !CValue {
    // Not even allowed to call unreachable in a naked function.
    if (f.object.dg.is_naked_fn) return .none;

    try f.object.writer().writeAll("zig_unreachable();\n");
    return .none;
}

fn airLoop(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const loop = f.air.extraData(Air.Block, ty_pl.payload);
    const body: []const Air.Inst.Index = @ptrCast(f.air.extra[loop.end..][0..loop.data.body_len]);
    const writer = f.object.writer();

    try writer.writeAll("for (;;) ");
    try genBody(f, body); // no need to restore state, we're noreturn
    try writer.writeByte('\n');

    return .none;
}

fn airCondBr(f: *Function, inst: Air.Inst.Index) !CValue {
    const pl_op = f.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const cond = try f.resolveInst(pl_op.operand);
    try reap(f, inst, &.{pl_op.operand});
    const extra = f.air.extraData(Air.CondBr, pl_op.payload);
    const then_body: []const Air.Inst.Index = @ptrCast(f.air.extra[extra.end..][0..extra.data.then_body_len]);
    const else_body: []const Air.Inst.Index = @ptrCast(f.air.extra[extra.end + then_body.len ..][0..extra.data.else_body_len]);
    const liveness_condbr = f.liveness.getCondBr(inst);
    const writer = f.object.writer();

    try writer.writeAll("if (");
    try f.writeCValue(writer, cond, .Other);
    try writer.writeAll(") ");

    try genBodyResolveState(f, inst, liveness_condbr.then_deaths, then_body, false);
    try writer.writeByte('\n');

    // We don't need to use `genBodyResolveState` for the else block, because this instruction is
    // noreturn so must terminate a body, therefore we don't need to leave `value_map` or
    // `free_locals_map` well defined (our parent is responsible for doing that).

    for (liveness_condbr.else_deaths) |death| {
        try die(f, inst, death.toRef());
    }

    // We never actually need an else block, because our branches are noreturn so must (for
    // instance) `br` to a block (label).

    try genBodyInner(f, else_body);

    return .none;
}

fn airSwitchBr(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const pl_op = f.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const condition = try f.resolveInst(pl_op.operand);
    try reap(f, inst, &.{pl_op.operand});
    const condition_ty = f.typeOf(pl_op.operand);
    const switch_br = f.air.extraData(Air.SwitchBr, pl_op.payload);
    const writer = f.object.writer();

    try writer.writeAll("switch (");
    if (condition_ty.zigTypeTag(mod) == .Bool) {
        try writer.writeByte('(');
        try f.renderType(writer, Type.u1);
        try writer.writeByte(')');
    } else if (condition_ty.isPtrAtRuntime(mod)) {
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

    // On the final iteration we do not need to fix any state. This is because, like in the `else`
    // branch of a `cond_br`, our parent has to do it for this entire body anyway.
    const last_case_i = switch_br.data.cases_len - @intFromBool(switch_br.data.else_body_len == 0);

    var extra_index: usize = switch_br.end;
    for (0..switch_br.data.cases_len) |case_i| {
        const case = f.air.extraData(Air.SwitchBr.Case, extra_index);
        const items = @as([]const Air.Inst.Ref, @ptrCast(f.air.extra[case.end..][0..case.data.items_len]));
        const case_body: []const Air.Inst.Index = @ptrCast(f.air.extra[case.end + items.len ..][0..case.data.body_len]);
        extra_index = case.end + case.data.items_len + case_body.len;

        for (items) |item| {
            try f.object.indent_writer.insertNewline();
            try writer.writeAll("case ");
            if (condition_ty.isPtrAtRuntime(mod)) {
                try writer.writeByte('(');
                try f.renderType(writer, Type.usize);
                try writer.writeByte(')');
            }
            try f.object.dg.renderValue(writer, condition_ty, (try f.air.value(item, mod)).?, .Other);
            try writer.writeByte(':');
        }
        try writer.writeByte(' ');

        if (case_i != last_case_i) {
            try genBodyResolveState(f, inst, liveness.deaths[case_i], case_body, false);
        } else {
            for (liveness.deaths[case_i]) |death| {
                try die(f, inst, death.toRef());
            }
            try genBody(f, case_body);
        }

        // The case body must be noreturn so we don't need to insert a break.
    }

    const else_body: []const Air.Inst.Index = @ptrCast(f.air.extra[extra_index..][0..switch_br.data.else_body_len]);
    try f.object.indent_writer.insertNewline();
    if (else_body.len > 0) {
        // Note that this must be the last case (i.e. the `last_case_i` case was not hit above)
        for (liveness.deaths[liveness.deaths.len - 1]) |death| {
            try die(f, inst, death.toRef());
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

fn asmInputNeedsLocal(f: *Function, constraint: []const u8, value: CValue) bool {
    const target = f.object.dg.module.getTarget();
    return switch (constraint[0]) {
        '{' => true,
        'i', 'r' => false,
        'I' => !target.cpu.arch.isArmOrThumb(),
        else => switch (value) {
            .constant => |val| switch (f.object.dg.module.intern_pool.indexToKey(val)) {
                .ptr => |ptr| switch (ptr.addr) {
                    .decl => false,
                    else => true,
                },
                else => true,
            },
            else => false,
        },
    };
}

fn airAsm(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = f.air.extraData(Air.Asm, ty_pl.payload);
    const is_volatile = @as(u1, @truncate(extra.data.flags >> 31)) != 0;
    const clobbers_len = @as(u31, @truncate(extra.data.flags));
    const gpa = f.object.dg.gpa;
    var extra_i: usize = extra.end;
    const outputs = @as([]const Air.Inst.Ref, @ptrCast(f.air.extra[extra_i..][0..extra.data.outputs_len]));
    extra_i += outputs.len;
    const inputs = @as([]const Air.Inst.Ref, @ptrCast(f.air.extra[extra_i..][0..extra.data.inputs_len]));
    extra_i += inputs.len;

    const result = result: {
        const writer = f.object.writer();
        const inst_ty = f.typeOfIndex(inst);
        const local = if (inst_ty.hasRuntimeBitsIgnoreComptime(mod)) local: {
            const local = try f.allocLocal(inst, inst_ty);
            if (f.wantSafety()) {
                try f.writeCValue(writer, local, .Other);
                try writer.writeAll(" = ");
                try f.writeCValue(writer, .{ .undef = inst_ty }, .Other);
                try writer.writeAll(";\n");
            }
            break :local local;
        } else .none;

        const locals_begin = @as(LocalIndex, @intCast(f.locals.items.len));
        const constraints_extra_begin = extra_i;
        for (outputs) |output| {
            const extra_bytes = mem.sliceAsBytes(f.air.extra[extra_i..]);
            const constraint = mem.sliceTo(extra_bytes, 0);
            const name = mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
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
                const output_ty = if (output == .none) inst_ty else f.typeOf(output).childType(mod);
                try writer.writeAll("register ");
                const alignment: Alignment = .none;
                const local_value = try f.allocLocalValue(output_ty, alignment);
                try f.allocs.put(gpa, local_value.new_local, false);
                try f.object.dg.renderTypeAndName(writer, output_ty, local_value, .{}, alignment, .complete);
                try writer.writeAll(" __asm(\"");
                try writer.writeAll(constraint["={".len .. constraint.len - "}".len]);
                try writer.writeAll("\")");
                if (f.wantSafety()) {
                    try writer.writeAll(" = ");
                    try f.writeCValue(writer, .{ .undef = output_ty }, .Other);
                }
                try writer.writeAll(";\n");
            }
        }
        for (inputs) |input| {
            const extra_bytes = mem.sliceAsBytes(f.air.extra[extra_i..]);
            const constraint = mem.sliceTo(extra_bytes, 0);
            const name = mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
            // This equation accounts for the fact that even if we have exactly 4 bytes
            // for the string, we still use the next u32 for the null terminator.
            extra_i += (constraint.len + name.len + (2 + 3)) / 4;

            if (constraint.len < 1 or mem.indexOfScalar(u8, "=+&%", constraint[0]) != null or
                (constraint[0] == '{' and constraint[constraint.len - 1] != '}'))
            {
                return f.fail("CBE: constraint not supported: '{s}'", .{constraint});
            }

            const is_reg = constraint[0] == '{';
            const input_val = try f.resolveInst(input);
            if (asmInputNeedsLocal(f, constraint, input_val)) {
                const input_ty = f.typeOf(input);
                if (is_reg) try writer.writeAll("register ");
                const alignment: Alignment = .none;
                const local_value = try f.allocLocalValue(input_ty, alignment);
                try f.allocs.put(gpa, local_value.new_local, false);
                try f.object.dg.renderTypeAndName(writer, input_ty, local_value, Const, alignment, .complete);
                if (is_reg) {
                    try writer.writeAll(" __asm(\"");
                    try writer.writeAll(constraint["{".len .. constraint.len - "}".len]);
                    try writer.writeAll("\")");
                }
                try writer.writeAll(" = ");
                try f.writeCValue(writer, input_val, .Other);
                try writer.writeAll(";\n");
            }
        }
        for (0..clobbers_len) |_| {
            const clobber = mem.sliceTo(mem.sliceAsBytes(f.air.extra[extra_i..]), 0);
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

                @memcpy(fixed_asm_source[dst_i..][0..literal.len], literal);
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

                    @memcpy(fixed_asm_source[dst_i..][0..modifier.len], modifier);
                    dst_i += modifier.len;
                    @memcpy(fixed_asm_source[dst_i..][0..name.len], name);
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
            const extra_bytes = mem.sliceAsBytes(f.air.extra[extra_i..]);
            const constraint = mem.sliceTo(extra_bytes, 0);
            const name = mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
            // This equation accounts for the fact that even if we have exactly 4 bytes
            // for the string, we still use the next u32 for the null terminator.
            extra_i += (constraint.len + name.len + (2 + 3)) / 4;

            if (index > 0) try writer.writeByte(',');
            try writer.writeByte(' ');
            if (!mem.eql(u8, name, "_")) try writer.print("[{s}]", .{name});
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
            const extra_bytes = mem.sliceAsBytes(f.air.extra[extra_i..]);
            const constraint = mem.sliceTo(extra_bytes, 0);
            const name = mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
            // This equation accounts for the fact that even if we have exactly 4 bytes
            // for the string, we still use the next u32 for the null terminator.
            extra_i += (constraint.len + name.len + (2 + 3)) / 4;

            if (index > 0) try writer.writeByte(',');
            try writer.writeByte(' ');
            if (!mem.eql(u8, name, "_")) try writer.print("[{s}]", .{name});

            const is_reg = constraint[0] == '{';
            const input_val = try f.resolveInst(input);
            try writer.print("{s}(", .{fmtStringLiteral(if (is_reg) "r" else constraint, null)});
            try f.writeCValue(writer, if (asmInputNeedsLocal(f, constraint, input_val)) local: {
                const input_local = .{ .local = locals_index };
                locals_index += 1;
                break :local input_local;
            } else input_val, .Other);
            try writer.writeByte(')');
        }
        try writer.writeByte(':');
        for (0..clobbers_len) |clobber_i| {
            const clobber = mem.sliceTo(mem.sliceAsBytes(f.air.extra[extra_i..]), 0);
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
            const extra_bytes = mem.sliceAsBytes(f.air.extra[extra_i..]);
            const constraint = mem.sliceTo(extra_bytes, 0);
            const name = mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
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

        break :result if (f.liveness.isUnused(inst)) .none else local;
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
    const mod = f.object.dg.module;
    const un_op = f.air.instructions.items(.data)[@intFromEnum(inst)].un_op;

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

    const operand_ty = f.typeOf(un_op);
    const optional_ty = if (is_ptr) operand_ty.childType(mod) else operand_ty;
    const payload_ty = optional_ty.optionalChild(mod);
    const err_int_ty = try mod.errorIntType();

    const rhs = if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod))
        TypedValue{ .ty = Type.bool, .val = Value.true }
    else if (optional_ty.isPtrLikeOptional(mod))
        // operand is a regular pointer, test `operand !=/== NULL`
        TypedValue{ .ty = optional_ty, .val = try mod.getCoerced(Value.null, optional_ty) }
    else if (payload_ty.zigTypeTag(mod) == .ErrorSet)
        TypedValue{ .ty = err_int_ty, .val = try mod.intValue(err_int_ty, 0) }
    else if (payload_ty.isSlice(mod) and optional_ty.optionalReprIsPayload(mod)) rhs: {
        try writer.writeAll(".ptr");
        const slice_ptr_ty = payload_ty.slicePtrFieldType(mod);
        const opt_slice_ptr_ty = try mod.optionalType(slice_ptr_ty.toIntern());
        break :rhs TypedValue{ .ty = opt_slice_ptr_ty, .val = try mod.nullValue(opt_slice_ptr_ty) };
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
    const mod = f.object.dg.module;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const opt_ty = f.typeOf(ty_op.operand);

    const payload_ty = opt_ty.optionalChild(mod);

    if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
        return .none;
    }

    const inst_ty = f.typeOfIndex(inst);
    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);

    if (opt_ty.optionalReprIsPayload(mod)) {
        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(" = ");
        try f.writeCValue(writer, operand, .Other);
        try writer.writeAll(";\n");
        return local;
    }

    const a = try Assignment.start(f, writer, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try a.assign(f, writer);
    try f.writeCValueMember(writer, operand, .{ .identifier = "payload" });
    try a.end(f, writer);
    return local;
}

fn airOptionalPayloadPtr(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const writer = f.object.writer();
    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const ptr_ty = f.typeOf(ty_op.operand);
    const opt_ty = ptr_ty.childType(mod);
    const inst_ty = f.typeOfIndex(inst);

    if (!inst_ty.childType(mod).hasRuntimeBitsIgnoreComptime(mod)) {
        return .{ .undef = inst_ty };
    }

    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);

    if (opt_ty.optionalReprIsPayload(mod)) {
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
    const mod = f.object.dg.module;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const writer = f.object.writer();
    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const operand_ty = f.typeOf(ty_op.operand);

    const opt_ty = operand_ty.childType(mod);

    const inst_ty = f.typeOfIndex(inst);

    if (opt_ty.optionalReprIsPayload(mod)) {
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
    container_ptr_ty: Type,
    field_ptr_ty: Type,
    field_index: u32,
    mod: *Module,
) union(enum) {
    begin: void,
    field: CValue,
    byte_offset: u32,
    end: void,
} {
    const ip = &mod.intern_pool;
    const container_ty = container_ptr_ty.childType(mod);
    return switch (container_ty.zigTypeTag(mod)) {
        .Struct => blk: {
            if (mod.typeToPackedStruct(container_ty)) |struct_type| {
                if (field_ptr_ty.ptrInfo(mod).packed_offset.host_size == 0)
                    break :blk .{ .byte_offset = @divExact(mod.structPackedFieldBitOffset(struct_type, field_index) + container_ptr_ty.ptrInfo(mod).packed_offset.bit_offset, 8) }
                else
                    break :blk .begin;
            }

            for (field_index..container_ty.structFieldCount(mod)) |next_field_index_usize| {
                const next_field_index: u32 = @intCast(next_field_index_usize);
                if (container_ty.structFieldIsComptime(next_field_index, mod)) continue;
                const field_ty = container_ty.structFieldType(next_field_index, mod);
                if (!field_ty.hasRuntimeBitsIgnoreComptime(mod)) continue;

                break :blk .{ .field = if (container_ty.isSimpleTuple(mod))
                    .{ .field = next_field_index }
                else
                    .{ .identifier = ip.stringToSlice(container_ty.legacyStructFieldName(next_field_index, mod)) } };
            }
            break :blk if (container_ty.hasRuntimeBitsIgnoreComptime(mod)) .end else .begin;
        },
        .Union => {
            const union_obj = mod.typeToUnion(container_ty).?;
            return switch (union_obj.getLayout(ip)) {
                .Auto, .Extern => {
                    const field_ty = Type.fromInterned(union_obj.field_types.get(ip)[field_index]);
                    if (!field_ty.hasRuntimeBitsIgnoreComptime(mod))
                        return if (container_ty.unionTagTypeSafety(mod) != null and
                            !container_ty.unionHasAllZeroBitFieldTypes(mod))
                            .{ .field = .{ .identifier = "payload" } }
                        else
                            .begin;
                    const field_name = union_obj.field_names.get(ip)[field_index];
                    return .{ .field = if (container_ty.unionTagTypeSafety(mod)) |_|
                        .{ .payload_identifier = ip.stringToSlice(field_name) }
                    else
                        .{ .identifier = ip.stringToSlice(field_name) } };
                },
                .Packed => .begin,
            };
        },
        .Pointer => switch (container_ty.ptrSize(mod)) {
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
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = f.air.extraData(Air.StructField, ty_pl.payload).data;

    const container_ptr_val = try f.resolveInst(extra.struct_operand);
    try reap(f, inst, &.{extra.struct_operand});
    const container_ptr_ty = f.typeOf(extra.struct_operand);
    return fieldPtr(f, inst, container_ptr_ty, container_ptr_val, extra.field_index);
}

fn airStructFieldPtrIndex(f: *Function, inst: Air.Inst.Index, index: u8) !CValue {
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const container_ptr_val = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const container_ptr_ty = f.typeOf(ty_op.operand);
    return fieldPtr(f, inst, container_ptr_ty, container_ptr_val, index);
}

fn airFieldParentPtr(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = f.air.extraData(Air.FieldParentPtr, ty_pl.payload).data;

    const container_ptr_ty = f.typeOfIndex(inst);
    const container_ty = container_ptr_ty.childType(mod);

    const field_ptr_ty = f.typeOf(extra.field_ptr);
    const field_ptr_val = try f.resolveInst(extra.field_ptr);
    try reap(f, inst, &.{extra.field_ptr});

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, container_ptr_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = (");
    try f.renderType(writer, container_ptr_ty);
    try writer.writeByte(')');

    switch (fieldLocation(container_ptr_ty, field_ptr_ty, extra.field_index, mod)) {
        .begin => try f.writeCValue(writer, field_ptr_val, .Initializer),
        .field => |field| {
            const u8_ptr_ty = try mod.adjustPtrTypeChild(field_ptr_ty, Type.u8);

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
            const u8_ptr_ty = try mod.adjustPtrTypeChild(field_ptr_ty, Type.u8);

            const byte_offset_val = try mod.intValue(Type.usize, byte_offset);

            try writer.writeAll("((");
            try f.renderType(writer, u8_ptr_ty);
            try writer.writeByte(')');
            try f.writeCValue(writer, field_ptr_val, .Other);
            try writer.print(" - {})", .{try f.fmtIntLiteral(Type.usize, byte_offset_val)});
        },
        .end => {
            try f.writeCValue(writer, field_ptr_val, .Other);
            try writer.print(" - {}", .{try f.fmtIntLiteral(Type.usize, try mod.intValue(Type.usize, 1))});
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
    const mod = f.object.dg.module;
    const container_ty = container_ptr_ty.childType(mod);
    const field_ptr_ty = f.typeOfIndex(inst);

    // Ensure complete type definition is visible before accessing fields.
    _ = try f.typeToIndex(container_ty, .complete);

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, field_ptr_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = (");
    try f.renderType(writer, field_ptr_ty);
    try writer.writeByte(')');

    switch (fieldLocation(container_ptr_ty, field_ptr_ty, field_index, mod)) {
        .begin => try f.writeCValue(writer, container_ptr_val, .Initializer),
        .field => |field| {
            try writer.writeByte('&');
            try f.writeCValueDerefMember(writer, container_ptr_val, field);
        },
        .byte_offset => |byte_offset| {
            const u8_ptr_ty = try mod.adjustPtrTypeChild(field_ptr_ty, Type.u8);

            const byte_offset_val = try mod.intValue(Type.usize, byte_offset);

            try writer.writeAll("((");
            try f.renderType(writer, u8_ptr_ty);
            try writer.writeByte(')');
            try f.writeCValue(writer, container_ptr_val, .Other);
            try writer.print(" + {})", .{try f.fmtIntLiteral(Type.usize, byte_offset_val)});
        },
        .end => {
            try writer.writeByte('(');
            try f.writeCValue(writer, container_ptr_val, .Other);
            try writer.print(" + {})", .{try f.fmtIntLiteral(Type.usize, try mod.intValue(Type.usize, 1))});
        },
    }

    try writer.writeAll(";\n");
    return local;
}

fn airStructFieldVal(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const ip = &mod.intern_pool;
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = f.air.extraData(Air.StructField, ty_pl.payload).data;

    const inst_ty = f.typeOfIndex(inst);
    if (!inst_ty.hasRuntimeBitsIgnoreComptime(mod)) {
        try reap(f, inst, &.{extra.struct_operand});
        return .none;
    }

    const struct_byval = try f.resolveInst(extra.struct_operand);
    try reap(f, inst, &.{extra.struct_operand});
    const struct_ty = f.typeOf(extra.struct_operand);
    const writer = f.object.writer();

    // Ensure complete type definition is visible before accessing fields.
    _ = try f.typeToIndex(struct_ty, .complete);

    const field_name: CValue = switch (mod.intern_pool.indexToKey(struct_ty.ip_index)) {
        .struct_type => switch (struct_ty.containerLayout(mod)) {
            .Auto, .Extern => if (struct_ty.isSimpleTuple(mod))
                .{ .field = extra.field_index }
            else
                .{ .identifier = ip.stringToSlice(struct_ty.legacyStructFieldName(extra.field_index, mod)) },
            .Packed => {
                const struct_type = mod.typeToStruct(struct_ty).?;
                const int_info = struct_ty.intInfo(mod);

                const bit_offset_ty = try mod.intType(.unsigned, Type.smallestUnsignedBits(int_info.bits - 1));

                const bit_offset = mod.structPackedFieldBitOffset(struct_type, extra.field_index);
                const bit_offset_val = try mod.intValue(bit_offset_ty, bit_offset);

                const field_int_signedness = if (inst_ty.isAbiInt(mod))
                    inst_ty.intInfo(mod).signedness
                else
                    .unsigned;
                const field_int_ty = try mod.intType(field_int_signedness, @as(u16, @intCast(inst_ty.bitSize(mod))));

                const temp_local = try f.allocLocal(inst, field_int_ty);
                try f.writeCValue(writer, temp_local, .Other);
                try writer.writeAll(" = zig_wrap_");
                try f.object.dg.renderTypeForBuiltinFnName(writer, field_int_ty);
                try writer.writeAll("((");
                try f.renderType(writer, field_int_ty);
                try writer.writeByte(')');
                const cant_cast = int_info.bits > 64;
                if (cant_cast) {
                    if (field_int_ty.bitSize(mod) > 64) return f.fail("TODO: C backend: implement casting between types > 64 bits", .{});
                    try writer.writeAll("zig_lo_");
                    try f.object.dg.renderTypeForBuiltinFnName(writer, struct_ty);
                    try writer.writeByte('(');
                }
                if (bit_offset > 0) {
                    try writer.writeAll("zig_shr_");
                    try f.object.dg.renderTypeForBuiltinFnName(writer, struct_ty);
                    try writer.writeByte('(');
                }
                try f.writeCValue(writer, struct_byval, .Other);
                if (bit_offset > 0) {
                    try writer.writeAll(", ");
                    try f.object.dg.renderValue(writer, bit_offset_ty, bit_offset_val, .FunctionArgument);
                    try writer.writeByte(')');
                }
                if (cant_cast) try writer.writeByte(')');
                try f.object.dg.renderBuiltinInfo(writer, field_int_ty, .bits);
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
                try freeLocal(f, inst, temp_local.new_local, null);
                return local;
            },
        },

        .anon_struct_type => |anon_struct_type| if (anon_struct_type.names.len == 0)
            .{ .field = extra.field_index }
        else
            .{ .identifier = ip.stringToSlice(struct_ty.legacyStructFieldName(extra.field_index, mod)) },

        .union_type => |union_type| field_name: {
            const union_obj = ip.loadUnionType(union_type);
            if (union_obj.flagsPtr(ip).layout == .Packed) {
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
                try f.writeCValue(writer, local, .Other);
                try writer.writeAll(", &");
                try f.writeCValue(writer, operand_lval, .Other);
                try writer.writeAll(", sizeof(");
                try f.renderType(writer, inst_ty);
                try writer.writeAll("));\n");

                if (struct_byval == .constant) {
                    try freeLocal(f, inst, operand_lval.new_local, null);
                }

                return local;
            } else {
                const name = union_obj.field_names.get(ip)[extra.field_index];
                break :field_name if (union_type.hasTag(ip)) .{
                    .payload_identifier = ip.stringToSlice(name),
                } else .{
                    .identifier = ip.stringToSlice(name),
                };
            }
        },
        else => unreachable,
    };

    const local = try f.allocLocal(inst, inst_ty);
    const a = try Assignment.start(f, writer, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try a.assign(f, writer);
    try f.writeCValueMember(writer, struct_byval, field_name);
    try a.end(f, writer);
    return local;
}

/// *(E!T) -> E
/// Note that the result is never a pointer.
fn airUnwrapErrUnionErr(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const inst_ty = f.typeOfIndex(inst);
    const operand = try f.resolveInst(ty_op.operand);
    const operand_ty = f.typeOf(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});

    const operand_is_ptr = operand_ty.zigTypeTag(mod) == .Pointer;
    const error_union_ty = if (operand_is_ptr) operand_ty.childType(mod) else operand_ty;
    const error_ty = error_union_ty.errorUnionSet(mod);
    const payload_ty = error_union_ty.errorUnionPayload(mod);
    const local = try f.allocLocal(inst, inst_ty);

    if (!payload_ty.hasRuntimeBits(mod) and operand == .local and operand.local == local.new_local) {
        // The store will be 'x = x'; elide it.
        return local;
    }

    const writer = f.object.writer();
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = ");

    if (!payload_ty.hasRuntimeBits(mod)) {
        try f.writeCValue(writer, operand, .Other);
    } else {
        if (!error_ty.errorSetIsEmpty(mod))
            if (operand_is_ptr)
                try f.writeCValueDerefMember(writer, operand, .{ .identifier = "error" })
            else
                try f.writeCValueMember(writer, operand, .{ .identifier = "error" })
        else {
            const err_int_ty = try mod.errorIntType();
            try f.object.dg.renderValue(writer, err_int_ty, try mod.intValue(err_int_ty, 0), .Initializer);
        }
    }
    try writer.writeAll(";\n");
    return local;
}

fn airUnwrapErrUnionPay(f: *Function, inst: Air.Inst.Index, is_ptr: bool) !CValue {
    const mod = f.object.dg.module;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const inst_ty = f.typeOfIndex(inst);
    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const operand_ty = f.typeOf(ty_op.operand);
    const error_union_ty = if (is_ptr) operand_ty.childType(mod) else operand_ty;

    const writer = f.object.writer();
    if (!error_union_ty.errorUnionPayload(mod).hasRuntimeBits(mod)) {
        if (!is_ptr) return .none;

        const local = try f.allocLocal(inst, inst_ty);
        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(" = (");
        try f.renderType(writer, inst_ty);
        try writer.writeByte(')');
        try f.writeCValue(writer, operand, .Initializer);
        try writer.writeAll(";\n");
        return local;
    }

    const local = try f.allocLocal(inst, inst_ty);
    const a = try Assignment.start(f, writer, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try a.assign(f, writer);
    if (is_ptr) {
        try writer.writeByte('&');
        try f.writeCValueDerefMember(writer, operand, .{ .identifier = "payload" });
    } else try f.writeCValueMember(writer, operand, .{ .identifier = "payload" });
    try a.end(f, writer);
    return local;
}

fn airWrapOptional(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const inst_ty = f.typeOfIndex(inst);
    const repr_is_payload = inst_ty.optionalReprIsPayload(mod);
    const payload_ty = f.typeOf(ty_op.operand);
    const payload = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    {
        const a = try Assignment.start(f, writer, payload_ty);
        if (repr_is_payload)
            try f.writeCValue(writer, local, .Other)
        else
            try f.writeCValueMember(writer, local, .{ .identifier = "payload" });
        try a.assign(f, writer);
        try f.writeCValue(writer, payload, .Other);
        try a.end(f, writer);
    }
    if (!repr_is_payload) {
        const a = try Assignment.start(f, writer, Type.bool);
        try f.writeCValueMember(writer, local, .{ .identifier = "is_null" });
        try a.assign(f, writer);
        try f.object.dg.renderValue(writer, Type.bool, Value.false, .Other);
        try a.end(f, writer);
    }
    return local;
}

fn airWrapErrUnionErr(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const inst_ty = f.typeOfIndex(inst);
    const payload_ty = inst_ty.errorUnionPayload(mod);
    const repr_is_err = !payload_ty.hasRuntimeBitsIgnoreComptime(mod);
    const err_ty = inst_ty.errorUnionSet(mod);
    const err = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);

    if (repr_is_err and err == .local and err.local == local.new_local) {
        // The store will be 'x = x'; elide it.
        return local;
    }

    if (!repr_is_err) {
        const a = try Assignment.start(f, writer, payload_ty);
        try f.writeCValueMember(writer, local, .{ .identifier = "payload" });
        try a.assign(f, writer);
        try f.object.dg.renderValue(writer, payload_ty, Value.undef, .Other);
        try a.end(f, writer);
    }
    {
        const a = try Assignment.start(f, writer, err_ty);
        if (repr_is_err)
            try f.writeCValue(writer, local, .Other)
        else
            try f.writeCValueMember(writer, local, .{ .identifier = "error" });
        try a.assign(f, writer);
        try f.writeCValue(writer, err, .Other);
        try a.end(f, writer);
    }
    return local;
}

fn airErrUnionPayloadPtrSet(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const writer = f.object.writer();
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const operand = try f.resolveInst(ty_op.operand);
    const error_union_ty = f.typeOf(ty_op.operand).childType(mod);

    const payload_ty = error_union_ty.errorUnionPayload(mod);
    const err_int_ty = try mod.errorIntType();

    // First, set the non-error value.
    if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
        try f.writeCValueDeref(writer, operand);
        try writer.writeAll(" = ");
        try f.object.dg.renderValue(writer, err_int_ty, try mod.intValue(err_int_ty, 0), .Other);
        try writer.writeAll(";\n ");

        return operand;
    }
    try reap(f, inst, &.{ty_op.operand});
    try f.writeCValueDeref(writer, operand);
    try writer.writeAll(".error = ");
    try f.object.dg.renderValue(writer, err_int_ty, try mod.intValue(err_int_ty, 0), .Other);
    try writer.writeAll(";\n");

    // Then return the payload pointer (only if it is used)
    if (f.liveness.isUnused(inst)) return .none;

    const local = try f.allocLocal(inst, f.typeOfIndex(inst));
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = &(");
    try f.writeCValueDeref(writer, operand);
    try writer.writeAll(").payload;\n");
    return local;
}

fn airErrReturnTrace(f: *Function, inst: Air.Inst.Index) !CValue {
    _ = inst;
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
    const mod = f.object.dg.module;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const inst_ty = f.typeOfIndex(inst);
    const payload_ty = inst_ty.errorUnionPayload(mod);
    const payload = try f.resolveInst(ty_op.operand);
    const repr_is_err = !payload_ty.hasRuntimeBitsIgnoreComptime(mod);
    const err_ty = inst_ty.errorUnionSet(mod);
    try reap(f, inst, &.{ty_op.operand});

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    if (!repr_is_err) {
        const a = try Assignment.start(f, writer, payload_ty);
        try f.writeCValueMember(writer, local, .{ .identifier = "payload" });
        try a.assign(f, writer);
        try f.writeCValue(writer, payload, .Other);
        try a.end(f, writer);
    }
    {
        const a = try Assignment.start(f, writer, err_ty);
        if (repr_is_err)
            try f.writeCValue(writer, local, .Other)
        else
            try f.writeCValueMember(writer, local, .{ .identifier = "error" });
        try a.assign(f, writer);
        const err_int_ty = try mod.errorIntType();
        try f.object.dg.renderValue(writer, err_int_ty, try mod.intValue(err_int_ty, 0), .Other);
        try a.end(f, writer);
    }
    return local;
}

fn airIsErr(f: *Function, inst: Air.Inst.Index, is_ptr: bool, operator: []const u8) !CValue {
    const mod = f.object.dg.module;
    const un_op = f.air.instructions.items(.data)[@intFromEnum(inst)].un_op;

    const writer = f.object.writer();
    const operand = try f.resolveInst(un_op);
    try reap(f, inst, &.{un_op});
    const operand_ty = f.typeOf(un_op);
    const local = try f.allocLocal(inst, Type.bool);
    const err_union_ty = if (is_ptr) operand_ty.childType(mod) else operand_ty;
    const payload_ty = err_union_ty.errorUnionPayload(mod);
    const error_ty = err_union_ty.errorUnionSet(mod);

    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = ");

    const err_int_ty = try mod.errorIntType();
    if (!error_ty.errorSetIsEmpty(mod))
        if (payload_ty.hasRuntimeBits(mod))
            if (is_ptr)
                try f.writeCValueDerefMember(writer, operand, .{ .identifier = "error" })
            else
                try f.writeCValueMember(writer, operand, .{ .identifier = "error" })
        else
            try f.writeCValue(writer, operand, .Other)
    else
        try f.object.dg.renderValue(writer, err_int_ty, try mod.intValue(err_int_ty, 0), .Other);
    try writer.writeByte(' ');
    try writer.writeAll(operator);
    try writer.writeByte(' ');
    try f.object.dg.renderValue(writer, err_int_ty, try mod.intValue(err_int_ty, 0), .Other);
    try writer.writeAll(";\n");
    return local;
}

fn airArrayToSlice(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const inst_ty = f.typeOfIndex(inst);
    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const array_ty = f.typeOf(ty_op.operand).childType(mod);

    try f.writeCValueMember(writer, local, .{ .identifier = "ptr" });
    try writer.writeAll(" = ");
    // Unfortunately, C does not support any equivalent to
    // &(*(void *)p)[0], although LLVM does via GetElementPtr
    if (operand == .undef) {
        try f.writeCValue(writer, .{ .undef = inst_ty.slicePtrFieldType(mod) }, .Initializer);
    } else if (array_ty.hasRuntimeBitsIgnoreComptime(mod)) {
        try writer.writeAll("&(");
        try f.writeCValueDeref(writer, operand);
        try writer.print(")[{}]", .{try f.fmtIntLiteral(Type.usize, try mod.intValue(Type.usize, 0))});
    } else try f.writeCValue(writer, operand, .Initializer);
    try writer.writeAll("; ");

    const len_val = try mod.intValue(Type.usize, array_ty.arrayLen(mod));
    try f.writeCValueMember(writer, local, .{ .identifier = "len" });
    try writer.print(" = {};\n", .{try f.fmtIntLiteral(Type.usize, len_val)});

    return local;
}

fn airFloatCast(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const inst_ty = f.typeOfIndex(inst);
    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const operand_ty = f.typeOf(ty_op.operand);
    const target = f.object.dg.module.getTarget();
    const operation = if (inst_ty.isRuntimeFloat() and operand_ty.isRuntimeFloat())
        if (inst_ty.floatBits(target) < operand_ty.floatBits(target)) "trunc" else "extend"
    else if (inst_ty.isInt(mod) and operand_ty.isRuntimeFloat())
        if (inst_ty.isSignedInt(mod)) "fix" else "fixuns"
    else if (inst_ty.isRuntimeFloat() and operand_ty.isInt(mod))
        if (operand_ty.isSignedInt(mod)) "float" else "floatun"
    else
        unreachable;

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);

    try writer.writeAll(" = ");
    if (inst_ty.isInt(mod) and operand_ty.isRuntimeFloat()) {
        try writer.writeAll("zig_wrap_");
        try f.object.dg.renderTypeForBuiltinFnName(writer, inst_ty);
        try writer.writeByte('(');
    }
    try writer.writeAll("zig_");
    try writer.writeAll(operation);
    try writer.writeAll(compilerRtAbbrev(operand_ty, mod));
    try writer.writeAll(compilerRtAbbrev(inst_ty, mod));
    try writer.writeByte('(');
    try f.writeCValue(writer, operand, .FunctionArgument);
    try writer.writeByte(')');
    if (inst_ty.isInt(mod) and operand_ty.isRuntimeFloat()) {
        try f.object.dg.renderBuiltinInfo(writer, inst_ty, .bits);
        try writer.writeByte(')');
    }
    try writer.writeAll(";\n");
    return local;
}

fn airIntFromPtr(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const un_op = f.air.instructions.items(.data)[@intFromEnum(inst)].un_op;

    const operand = try f.resolveInst(un_op);
    const operand_ty = f.typeOf(un_op);
    try reap(f, inst, &.{un_op});
    const inst_ty = f.typeOfIndex(inst);
    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);

    try writer.writeAll(" = (");
    try f.renderType(writer, inst_ty);
    try writer.writeByte(')');
    if (operand_ty.isSlice(mod)) {
        try f.writeCValueMember(writer, operand, .{ .identifier = "ptr" });
    } else {
        try f.writeCValue(writer, operand, .Other);
    }
    try writer.writeAll(";\n");
    return local;
}

fn airUnBuiltinCall(
    f: *Function,
    inst: Air.Inst.Index,
    operation: []const u8,
    info: BuiltinInfo,
) !CValue {
    const mod = f.object.dg.module;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const inst_ty = f.typeOfIndex(inst);
    const inst_scalar_ty = inst_ty.scalarType(mod);
    const operand_ty = f.typeOf(ty_op.operand);
    const scalar_ty = operand_ty.scalarType(mod);

    const inst_scalar_cty = try f.typeToCType(inst_scalar_ty, .complete);
    const ref_ret = inst_scalar_cty.tag() == .array;

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const v = try Vectorize.start(f, inst, writer, operand_ty);
    if (!ref_ret) {
        try f.writeCValue(writer, local, .Other);
        try v.elem(f, writer);
        try writer.writeAll(" = ");
    }
    try writer.print("zig_{s}_", .{operation});
    try f.object.dg.renderTypeForBuiltinFnName(writer, scalar_ty);
    try writer.writeByte('(');
    if (ref_ret) {
        try f.writeCValue(writer, local, .FunctionArgument);
        try v.elem(f, writer);
        try writer.writeAll(", ");
    }
    try f.writeCValue(writer, operand, .FunctionArgument);
    try v.elem(f, writer);
    try f.object.dg.renderBuiltinInfo(writer, scalar_ty, info);
    try writer.writeAll(");\n");
    try v.end(f, inst, writer);

    return local;
}

fn airBinBuiltinCall(
    f: *Function,
    inst: Air.Inst.Index,
    operation: []const u8,
    info: BuiltinInfo,
) !CValue {
    const mod = f.object.dg.module;
    const bin_op = f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const operand_ty = f.typeOf(bin_op.lhs);
    const operand_cty = try f.typeToCType(operand_ty, .complete);
    const is_big = operand_cty.tag() == .array;

    const lhs = try f.resolveInst(bin_op.lhs);
    const rhs = try f.resolveInst(bin_op.rhs);
    if (!is_big) try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const inst_ty = f.typeOfIndex(inst);
    const inst_scalar_ty = inst_ty.scalarType(mod);
    const scalar_ty = operand_ty.scalarType(mod);

    const inst_scalar_cty = try f.typeToCType(inst_scalar_ty, .complete);
    const ref_ret = inst_scalar_cty.tag() == .array;

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    if (is_big) try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
    const v = try Vectorize.start(f, inst, writer, operand_ty);
    if (!ref_ret) {
        try f.writeCValue(writer, local, .Other);
        try v.elem(f, writer);
        try writer.writeAll(" = ");
    }
    try writer.print("zig_{s}_", .{operation});
    try f.object.dg.renderTypeForBuiltinFnName(writer, scalar_ty);
    try writer.writeByte('(');
    if (ref_ret) {
        try f.writeCValue(writer, local, .FunctionArgument);
        try v.elem(f, writer);
        try writer.writeAll(", ");
    }
    try f.writeCValue(writer, lhs, .FunctionArgument);
    try v.elem(f, writer);
    try writer.writeAll(", ");
    try f.writeCValue(writer, rhs, .FunctionArgument);
    try v.elem(f, writer);
    try f.object.dg.renderBuiltinInfo(writer, scalar_ty, info);
    try writer.writeAll(");\n");
    try v.end(f, inst, writer);

    return local;
}

fn airCmpBuiltinCall(
    f: *Function,
    inst: Air.Inst.Index,
    data: anytype,
    operator: std.math.CompareOperator,
    operation: enum { cmp, operator },
    info: BuiltinInfo,
) !CValue {
    const mod = f.object.dg.module;
    const lhs = try f.resolveInst(data.lhs);
    const rhs = try f.resolveInst(data.rhs);
    try reap(f, inst, &.{ data.lhs, data.rhs });

    const inst_ty = f.typeOfIndex(inst);
    const inst_scalar_ty = inst_ty.scalarType(mod);
    const operand_ty = f.typeOf(data.lhs);
    const scalar_ty = operand_ty.scalarType(mod);

    const inst_scalar_cty = try f.typeToCType(inst_scalar_ty, .complete);
    const ref_ret = inst_scalar_cty.tag() == .array;

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const v = try Vectorize.start(f, inst, writer, operand_ty);
    if (!ref_ret) {
        try f.writeCValue(writer, local, .Other);
        try v.elem(f, writer);
        try writer.writeAll(" = ");
    }
    try writer.print("zig_{s}_", .{switch (operation) {
        else => @tagName(operation),
        .operator => compareOperatorAbbrev(operator),
    }});
    try f.object.dg.renderTypeForBuiltinFnName(writer, scalar_ty);
    try writer.writeByte('(');
    if (ref_ret) {
        try f.writeCValue(writer, local, .FunctionArgument);
        try v.elem(f, writer);
        try writer.writeAll(", ");
    }
    try f.writeCValue(writer, lhs, .FunctionArgument);
    try v.elem(f, writer);
    try writer.writeAll(", ");
    try f.writeCValue(writer, rhs, .FunctionArgument);
    try v.elem(f, writer);
    try f.object.dg.renderBuiltinInfo(writer, scalar_ty, info);
    try writer.writeByte(')');
    if (!ref_ret) try writer.print(" {s} {}", .{
        compareOperatorC(operator),
        try f.fmtIntLiteral(Type.i32, try mod.intValue(Type.i32, 0)),
    });
    try writer.writeAll(";\n");
    try v.end(f, inst, writer);

    return local;
}

fn airCmpxchg(f: *Function, inst: Air.Inst.Index, flavor: [*:0]const u8) !CValue {
    const mod = f.object.dg.module;
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = f.air.extraData(Air.Cmpxchg, ty_pl.payload).data;
    const inst_ty = f.typeOfIndex(inst);
    const ptr = try f.resolveInst(extra.ptr);
    const expected_value = try f.resolveInst(extra.expected_value);
    const new_value = try f.resolveInst(extra.new_value);
    const ptr_ty = f.typeOf(extra.ptr);
    const ty = ptr_ty.childType(mod);

    const writer = f.object.writer();
    const new_value_mat = try Materialize.start(f, inst, writer, ty, new_value);
    try reap(f, inst, &.{ extra.ptr, extra.expected_value, extra.new_value });

    const repr_ty = if (ty.isRuntimeFloat())
        mod.intType(.unsigned, @as(u16, @intCast(ty.abiSize(mod) * 8))) catch unreachable
    else
        ty;

    const local = try f.allocLocal(inst, inst_ty);
    if (inst_ty.isPtrLikeOptional(mod)) {
        {
            const a = try Assignment.start(f, writer, ty);
            try f.writeCValue(writer, local, .Other);
            try a.assign(f, writer);
            try f.writeCValue(writer, expected_value, .Other);
            try a.end(f, writer);
        }

        try writer.writeAll("if (");
        try writer.print("zig_cmpxchg_{s}((zig_atomic(", .{flavor});
        try f.renderType(writer, ty);
        try writer.writeByte(')');
        if (ptr_ty.isVolatilePtr(mod)) try writer.writeAll(" volatile");
        try writer.writeAll(" *)");
        try f.writeCValue(writer, ptr, .Other);
        try writer.writeAll(", ");
        try f.writeCValue(writer, local, .FunctionArgument);
        try writer.writeAll(", ");
        try new_value_mat.mat(f, writer);
        try writer.writeAll(", ");
        try writeMemoryOrder(writer, extra.successOrder());
        try writer.writeAll(", ");
        try writeMemoryOrder(writer, extra.failureOrder());
        try writer.writeAll(", ");
        try f.object.dg.renderTypeForBuiltinFnName(writer, ty);
        try writer.writeAll(", ");
        try f.object.dg.renderType(writer, repr_ty);
        try writer.writeByte(')');
        try writer.writeAll(") {\n");
        f.object.indent_writer.pushIndent();
        {
            const a = try Assignment.start(f, writer, ty);
            try f.writeCValue(writer, local, .Other);
            try a.assign(f, writer);
            try writer.writeAll("NULL");
            try a.end(f, writer);
        }
        f.object.indent_writer.popIndent();
        try writer.writeAll("}\n");
    } else {
        {
            const a = try Assignment.start(f, writer, ty);
            try f.writeCValueMember(writer, local, .{ .identifier = "payload" });
            try a.assign(f, writer);
            try f.writeCValue(writer, expected_value, .Other);
            try a.end(f, writer);
        }
        {
            const a = try Assignment.start(f, writer, Type.bool);
            try f.writeCValueMember(writer, local, .{ .identifier = "is_null" });
            try a.assign(f, writer);
            try writer.print("zig_cmpxchg_{s}((zig_atomic(", .{flavor});
            try f.renderType(writer, ty);
            try writer.writeByte(')');
            if (ptr_ty.isVolatilePtr(mod)) try writer.writeAll(" volatile");
            try writer.writeAll(" *)");
            try f.writeCValue(writer, ptr, .Other);
            try writer.writeAll(", ");
            try f.writeCValueMember(writer, local, .{ .identifier = "payload" });
            try writer.writeAll(", ");
            try new_value_mat.mat(f, writer);
            try writer.writeAll(", ");
            try writeMemoryOrder(writer, extra.successOrder());
            try writer.writeAll(", ");
            try writeMemoryOrder(writer, extra.failureOrder());
            try writer.writeAll(", ");
            try f.object.dg.renderTypeForBuiltinFnName(writer, ty);
            try writer.writeAll(", ");
            try f.object.dg.renderType(writer, repr_ty);
            try writer.writeByte(')');
            try a.end(f, writer);
        }
    }
    try new_value_mat.end(f, inst);

    if (f.liveness.isUnused(inst)) {
        try freeLocal(f, inst, local.new_local, null);
        return .none;
    }

    return local;
}

fn airAtomicRmw(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const pl_op = f.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const extra = f.air.extraData(Air.AtomicRmw, pl_op.payload).data;
    const inst_ty = f.typeOfIndex(inst);
    const ptr_ty = f.typeOf(pl_op.operand);
    const ty = ptr_ty.childType(mod);
    const ptr = try f.resolveInst(pl_op.operand);
    const operand = try f.resolveInst(extra.operand);

    const writer = f.object.writer();
    const operand_mat = try Materialize.start(f, inst, writer, ty, operand);
    try reap(f, inst, &.{ pl_op.operand, extra.operand });

    const repr_bits = @as(u16, @intCast(ty.abiSize(mod) * 8));
    const is_float = ty.isRuntimeFloat();
    const is_128 = repr_bits == 128;
    const repr_ty = if (is_float) mod.intType(.unsigned, repr_bits) catch unreachable else ty;

    const local = try f.allocLocal(inst, inst_ty);
    try writer.print("zig_atomicrmw_{s}", .{toAtomicRmwSuffix(extra.op())});
    if (is_float) try writer.writeAll("_float") else if (is_128) try writer.writeAll("_int128");
    try writer.writeByte('(');
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(", (");
    const use_atomic = switch (extra.op()) {
        else => true,
        // These are missing from stdatomic.h, so no atomic types unless a fallback is used.
        .Nand, .Min, .Max => is_float or is_128,
    };
    if (use_atomic) try writer.writeAll("zig_atomic(");
    try f.renderType(writer, ty);
    if (use_atomic) try writer.writeByte(')');
    if (ptr_ty.isVolatilePtr(mod)) try writer.writeAll(" volatile");
    try writer.writeAll(" *)");
    try f.writeCValue(writer, ptr, .Other);
    try writer.writeAll(", ");
    try operand_mat.mat(f, writer);
    try writer.writeAll(", ");
    try writeMemoryOrder(writer, extra.ordering());
    try writer.writeAll(", ");
    try f.object.dg.renderTypeForBuiltinFnName(writer, ty);
    try writer.writeAll(", ");
    try f.object.dg.renderType(writer, repr_ty);
    try writer.writeAll(");\n");
    try operand_mat.end(f, inst);

    if (f.liveness.isUnused(inst)) {
        try freeLocal(f, inst, local.new_local, null);
        return .none;
    }

    return local;
}

fn airAtomicLoad(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const atomic_load = f.air.instructions.items(.data)[@intFromEnum(inst)].atomic_load;
    const ptr = try f.resolveInst(atomic_load.ptr);
    try reap(f, inst, &.{atomic_load.ptr});
    const ptr_ty = f.typeOf(atomic_load.ptr);
    const ty = ptr_ty.childType(mod);

    const repr_ty = if (ty.isRuntimeFloat())
        mod.intType(.unsigned, @as(u16, @intCast(ty.abiSize(mod) * 8))) catch unreachable
    else
        ty;

    const inst_ty = f.typeOfIndex(inst);
    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);

    try writer.writeAll("zig_atomic_load(");
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(", (zig_atomic(");
    try f.renderType(writer, ty);
    try writer.writeByte(')');
    if (ptr_ty.isVolatilePtr(mod)) try writer.writeAll(" volatile");
    try writer.writeAll(" *)");
    try f.writeCValue(writer, ptr, .Other);
    try writer.writeAll(", ");
    try writeMemoryOrder(writer, atomic_load.order);
    try writer.writeAll(", ");
    try f.object.dg.renderTypeForBuiltinFnName(writer, ty);
    try writer.writeAll(", ");
    try f.object.dg.renderType(writer, repr_ty);
    try writer.writeAll(");\n");

    return local;
}

fn airAtomicStore(f: *Function, inst: Air.Inst.Index, order: [*:0]const u8) !CValue {
    const mod = f.object.dg.module;
    const bin_op = f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const ptr_ty = f.typeOf(bin_op.lhs);
    const ty = ptr_ty.childType(mod);
    const ptr = try f.resolveInst(bin_op.lhs);
    const element = try f.resolveInst(bin_op.rhs);

    const writer = f.object.writer();
    const element_mat = try Materialize.start(f, inst, writer, ty, element);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const repr_ty = if (ty.isRuntimeFloat())
        mod.intType(.unsigned, @as(u16, @intCast(ty.abiSize(mod) * 8))) catch unreachable
    else
        ty;

    try writer.writeAll("zig_atomic_store((zig_atomic(");
    try f.renderType(writer, ty);
    try writer.writeByte(')');
    if (ptr_ty.isVolatilePtr(mod)) try writer.writeAll(" volatile");
    try writer.writeAll(" *)");
    try f.writeCValue(writer, ptr, .Other);
    try writer.writeAll(", ");
    try element_mat.mat(f, writer);
    try writer.print(", {s}, ", .{order});
    try f.object.dg.renderTypeForBuiltinFnName(writer, ty);
    try writer.writeAll(", ");
    try f.object.dg.renderType(writer, repr_ty);
    try writer.writeAll(");\n");
    try element_mat.end(f, inst);

    return .none;
}

fn writeSliceOrPtr(f: *Function, writer: anytype, ptr: CValue, ptr_ty: Type) !void {
    const mod = f.object.dg.module;
    if (ptr_ty.isSlice(mod)) {
        try f.writeCValueMember(writer, ptr, .{ .identifier = "ptr" });
    } else {
        try f.writeCValue(writer, ptr, .FunctionArgument);
    }
}

fn airMemset(f: *Function, inst: Air.Inst.Index, safety: bool) !CValue {
    const mod = f.object.dg.module;
    const bin_op = f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const dest_ty = f.typeOf(bin_op.lhs);
    const dest_slice = try f.resolveInst(bin_op.lhs);
    const value = try f.resolveInst(bin_op.rhs);
    const elem_ty = f.typeOf(bin_op.rhs);
    const elem_abi_size = elem_ty.abiSize(mod);
    const val_is_undef = if (try f.air.value(bin_op.rhs, mod)) |val| val.isUndefDeep(mod) else false;
    const writer = f.object.writer();

    if (val_is_undef) {
        if (!safety) {
            try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
            return .none;
        }

        try writer.writeAll("memset(");
        switch (dest_ty.ptrSize(mod)) {
            .Slice => {
                try f.writeCValueMember(writer, dest_slice, .{ .identifier = "ptr" });
                try writer.writeAll(", 0xaa, ");
                try f.writeCValueMember(writer, dest_slice, .{ .identifier = "len" });
                if (elem_abi_size > 1) {
                    try writer.print(" * {d});\n", .{elem_abi_size});
                } else {
                    try writer.writeAll(");\n");
                }
            },
            .One => {
                const array_ty = dest_ty.childType(mod);
                const len = array_ty.arrayLen(mod) * elem_abi_size;

                try f.writeCValue(writer, dest_slice, .FunctionArgument);
                try writer.print(", 0xaa, {d});\n", .{len});
            },
            .Many, .C => unreachable,
        }
        try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
        return .none;
    }

    if (elem_abi_size > 1 or dest_ty.isVolatilePtr(mod)) {
        // For the assignment in this loop, the array pointer needs to get
        // casted to a regular pointer, otherwise an error like this occurs:
        // error: array type 'uint32_t[20]' (aka 'unsigned int[20]') is not assignable
        const elem_ptr_ty = try mod.ptrType(.{
            .child = elem_ty.ip_index,
            .flags = .{
                .size = .C,
            },
        });

        const index = try f.allocLocal(inst, Type.usize);

        try writer.writeAll("for (");
        try f.writeCValue(writer, index, .Other);
        try writer.writeAll(" = ");
        try f.object.dg.renderValue(writer, Type.usize, try mod.intValue(Type.usize, 0), .Initializer);
        try writer.writeAll("; ");
        try f.writeCValue(writer, index, .Other);
        try writer.writeAll(" != ");
        switch (dest_ty.ptrSize(mod)) {
            .Slice => {
                try f.writeCValueMember(writer, dest_slice, .{ .identifier = "len" });
            },
            .One => {
                const array_ty = dest_ty.childType(mod);
                try writer.print("{d}", .{array_ty.arrayLen(mod)});
            },
            .Many, .C => unreachable,
        }
        try writer.writeAll("; ++");
        try f.writeCValue(writer, index, .Other);
        try writer.writeAll(") ");

        const a = try Assignment.start(f, writer, elem_ty);
        try writer.writeAll("((");
        try f.renderType(writer, elem_ptr_ty);
        try writer.writeByte(')');
        try writeSliceOrPtr(f, writer, dest_slice, dest_ty);
        try writer.writeAll(")[");
        try f.writeCValue(writer, index, .Other);
        try writer.writeByte(']');
        try a.assign(f, writer);
        try f.writeCValue(writer, value, .Other);
        try a.end(f, writer);

        try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
        try freeLocal(f, inst, index.new_local, null);

        return .none;
    }

    const bitcasted = try bitcast(f, Type.u8, value, elem_ty);

    try writer.writeAll("memset(");
    switch (dest_ty.ptrSize(mod)) {
        .Slice => {
            try f.writeCValueMember(writer, dest_slice, .{ .identifier = "ptr" });
            try writer.writeAll(", ");
            try f.writeCValue(writer, bitcasted.c_value, .FunctionArgument);
            try writer.writeAll(", ");
            try f.writeCValueMember(writer, dest_slice, .{ .identifier = "len" });
            try writer.writeAll(");\n");
        },
        .One => {
            const array_ty = dest_ty.childType(mod);
            const len = array_ty.arrayLen(mod) * elem_abi_size;

            try f.writeCValue(writer, dest_slice, .FunctionArgument);
            try writer.writeAll(", ");
            try f.writeCValue(writer, bitcasted.c_value, .FunctionArgument);
            try writer.print(", {d});\n", .{len});
        },
        .Many, .C => unreachable,
    }
    try bitcasted.free(f);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
    return .none;
}

fn airMemcpy(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const bin_op = f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const dest_ptr = try f.resolveInst(bin_op.lhs);
    const src_ptr = try f.resolveInst(bin_op.rhs);
    const dest_ty = f.typeOf(bin_op.lhs);
    const src_ty = f.typeOf(bin_op.rhs);
    const writer = f.object.writer();

    try writer.writeAll("memcpy(");
    try writeSliceOrPtr(f, writer, dest_ptr, dest_ty);
    try writer.writeAll(", ");
    try writeSliceOrPtr(f, writer, src_ptr, src_ty);
    try writer.writeAll(", ");
    switch (dest_ty.ptrSize(mod)) {
        .Slice => {
            const elem_ty = dest_ty.childType(mod);
            const elem_abi_size = elem_ty.abiSize(mod);
            try f.writeCValueMember(writer, dest_ptr, .{ .identifier = "len" });
            if (elem_abi_size > 1) {
                try writer.print(" * {d});\n", .{elem_abi_size});
            } else {
                try writer.writeAll(");\n");
            }
        },
        .One => {
            const array_ty = dest_ty.childType(mod);
            const elem_ty = array_ty.childType(mod);
            const elem_abi_size = elem_ty.abiSize(mod);
            const len = array_ty.arrayLen(mod) * elem_abi_size;
            try writer.print("{d});\n", .{len});
        },
        .Many, .C => unreachable,
    }

    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
    return .none;
}

fn airSetUnionTag(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const bin_op = f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const union_ptr = try f.resolveInst(bin_op.lhs);
    const new_tag = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const union_ty = f.typeOf(bin_op.lhs).childType(mod);
    const layout = union_ty.unionGetLayout(mod);
    if (layout.tag_size == 0) return .none;
    const tag_ty = union_ty.unionTagTypeSafety(mod).?;

    const writer = f.object.writer();
    const a = try Assignment.start(f, writer, tag_ty);
    try f.writeCValueDerefMember(writer, union_ptr, .{ .identifier = "tag" });
    try a.assign(f, writer);
    try f.writeCValue(writer, new_tag, .Other);
    try a.end(f, writer);
    return .none;
}

fn airGetUnionTag(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});

    const union_ty = f.typeOf(ty_op.operand);
    const layout = union_ty.unionGetLayout(mod);
    if (layout.tag_size == 0) return .none;

    const inst_ty = f.typeOfIndex(inst);
    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const a = try Assignment.start(f, writer, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try a.assign(f, writer);
    try f.writeCValueMember(writer, operand, .{ .identifier = "tag" });
    try a.end(f, writer);
    return local;
}

fn airTagName(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const un_op = f.air.instructions.items(.data)[@intFromEnum(inst)].un_op;

    const inst_ty = f.typeOfIndex(inst);
    const enum_ty = f.typeOf(un_op);
    const operand = try f.resolveInst(un_op);
    try reap(f, inst, &.{un_op});

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.print(" = {s}(", .{
        try f.getLazyFnName(.{ .tag_name = enum_ty.getOwnerDecl(mod) }, .{ .tag_name = enum_ty }),
    });
    try f.writeCValue(writer, operand, .Other);
    try writer.writeAll(");\n");

    return local;
}

fn airErrorName(f: *Function, inst: Air.Inst.Index) !CValue {
    const un_op = f.air.instructions.items(.data)[@intFromEnum(inst)].un_op;

    const writer = f.object.writer();
    const inst_ty = f.typeOfIndex(inst);
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
    const mod = f.object.dg.module;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});

    const inst_ty = f.typeOfIndex(inst);
    const inst_scalar_ty = inst_ty.scalarType(mod);

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const v = try Vectorize.start(f, inst, writer, inst_ty);
    const a = try Assignment.init(f, inst_scalar_ty);
    try f.writeCValue(writer, local, .Other);
    try v.elem(f, writer);
    try a.assign(f, writer);
    try f.writeCValue(writer, operand, .Other);
    try a.end(f, writer);
    try v.end(f, inst, writer);

    return local;
}

fn airSelect(f: *Function, inst: Air.Inst.Index) !CValue {
    const pl_op = f.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const extra = f.air.extraData(Air.Bin, pl_op.payload).data;

    const pred = try f.resolveInst(pl_op.operand);
    const lhs = try f.resolveInst(extra.lhs);
    const rhs = try f.resolveInst(extra.rhs);
    try reap(f, inst, &.{ pl_op.operand, extra.lhs, extra.rhs });

    const inst_ty = f.typeOfIndex(inst);

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const v = try Vectorize.start(f, inst, writer, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try v.elem(f, writer);
    try writer.writeAll(" = ");
    try f.writeCValue(writer, pred, .Other);
    try v.elem(f, writer);
    try writer.writeAll(" ? ");
    try f.writeCValue(writer, lhs, .Other);
    try v.elem(f, writer);
    try writer.writeAll(" : ");
    try f.writeCValue(writer, rhs, .Other);
    try v.elem(f, writer);
    try writer.writeAll(";\n");
    try v.end(f, inst, writer);

    return local;
}

fn airShuffle(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = f.air.extraData(Air.Shuffle, ty_pl.payload).data;

    const mask = Value.fromInterned(extra.mask);
    const lhs = try f.resolveInst(extra.a);
    const rhs = try f.resolveInst(extra.b);

    const inst_ty = f.typeOfIndex(inst);

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try reap(f, inst, &.{ extra.a, extra.b }); // local cannot alias operands
    for (0..extra.mask_len) |index| {
        try f.writeCValue(writer, local, .Other);
        try writer.writeByte('[');
        try f.object.dg.renderValue(writer, Type.usize, try mod.intValue(Type.usize, index), .Other);
        try writer.writeAll("] = ");

        const mask_elem = (try mask.elemValue(mod, index)).toSignedInt(mod);
        const src_val = try mod.intValue(Type.usize, @as(u64, @intCast(mask_elem ^ mask_elem >> 63)));

        try f.writeCValue(writer, if (mask_elem >= 0) lhs else rhs, .Other);
        try writer.writeByte('[');
        try f.object.dg.renderValue(writer, Type.usize, src_val, .Other);
        try writer.writeAll("];\n");
    }

    return local;
}

fn airReduce(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const reduce = f.air.instructions.items(.data)[@intFromEnum(inst)].reduce;

    const scalar_ty = f.typeOfIndex(inst);
    const operand = try f.resolveInst(reduce.operand);
    try reap(f, inst, &.{reduce.operand});
    const operand_ty = f.typeOf(reduce.operand);
    const writer = f.object.writer();

    const use_operator = scalar_ty.bitSize(mod) <= 64;
    const op: union(enum) {
        const Func = struct { operation: []const u8, info: BuiltinInfo = .none };
        float_op: Func,
        builtin: Func,
        infix: []const u8,
        ternary: []const u8,
    } = switch (reduce.operation) {
        .And => if (use_operator) .{ .infix = " &= " } else .{ .builtin = .{ .operation = "and" } },
        .Or => if (use_operator) .{ .infix = " |= " } else .{ .builtin = .{ .operation = "or" } },
        .Xor => if (use_operator) .{ .infix = " ^= " } else .{ .builtin = .{ .operation = "xor" } },
        .Min => switch (scalar_ty.zigTypeTag(mod)) {
            .Int => if (use_operator) .{ .ternary = " < " } else .{
                .builtin = .{ .operation = "min" },
            },
            .Float => .{ .float_op = .{ .operation = "fmin" } },
            else => unreachable,
        },
        .Max => switch (scalar_ty.zigTypeTag(mod)) {
            .Int => if (use_operator) .{ .ternary = " > " } else .{
                .builtin = .{ .operation = "max" },
            },
            .Float => .{ .float_op = .{ .operation = "fmax" } },
            else => unreachable,
        },
        .Add => switch (scalar_ty.zigTypeTag(mod)) {
            .Int => if (use_operator) .{ .infix = " += " } else .{
                .builtin = .{ .operation = "addw", .info = .bits },
            },
            .Float => .{ .builtin = .{ .operation = "add" } },
            else => unreachable,
        },
        .Mul => switch (scalar_ty.zigTypeTag(mod)) {
            .Int => if (use_operator) .{ .infix = " *= " } else .{
                .builtin = .{ .operation = "mulw", .info = .bits },
            },
            .Float => .{ .builtin = .{ .operation = "mul" } },
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

    const accum = try f.allocLocal(inst, scalar_ty);
    try f.writeCValue(writer, accum, .Other);
    try writer.writeAll(" = ");

    try f.object.dg.renderValue(writer, scalar_ty, switch (reduce.operation) {
        .Or, .Xor => switch (scalar_ty.zigTypeTag(mod)) {
            .Bool => Value.false,
            .Int => try mod.intValue(scalar_ty, 0),
            else => unreachable,
        },
        .And => switch (scalar_ty.zigTypeTag(mod)) {
            .Bool => Value.true,
            .Int => switch (scalar_ty.intInfo(mod).signedness) {
                .unsigned => try scalar_ty.maxIntScalar(mod, scalar_ty),
                .signed => try mod.intValue(scalar_ty, -1),
            },
            else => unreachable,
        },
        .Add => switch (scalar_ty.zigTypeTag(mod)) {
            .Int => try mod.intValue(scalar_ty, 0),
            .Float => try mod.floatValue(scalar_ty, 0.0),
            else => unreachable,
        },
        .Mul => switch (scalar_ty.zigTypeTag(mod)) {
            .Int => try mod.intValue(scalar_ty, 1),
            .Float => try mod.floatValue(scalar_ty, 1.0),
            else => unreachable,
        },
        .Min => switch (scalar_ty.zigTypeTag(mod)) {
            .Bool => Value.true,
            .Int => try scalar_ty.maxIntScalar(mod, scalar_ty),
            .Float => try mod.floatValue(scalar_ty, std.math.nan(f128)),
            else => unreachable,
        },
        .Max => switch (scalar_ty.zigTypeTag(mod)) {
            .Bool => Value.false,
            .Int => try scalar_ty.minIntScalar(mod, scalar_ty),
            .Float => try mod.floatValue(scalar_ty, std.math.nan(f128)),
            else => unreachable,
        },
    }, .Initializer);
    try writer.writeAll(";\n");

    const v = try Vectorize.start(f, inst, writer, operand_ty);
    try f.writeCValue(writer, accum, .Other);
    switch (op) {
        .float_op => |func| {
            try writer.writeAll(" = zig_float_fn_");
            try f.object.dg.renderTypeForBuiltinFnName(writer, scalar_ty);
            try writer.print("_{s}(", .{func.operation});
            try f.writeCValue(writer, accum, .FunctionArgument);
            try writer.writeAll(", ");
            try f.writeCValue(writer, operand, .Other);
            try v.elem(f, writer);
            try f.object.dg.renderBuiltinInfo(writer, scalar_ty, func.info);
            try writer.writeByte(')');
        },
        .builtin => |func| {
            try writer.print(" = zig_{s}_", .{func.operation});
            try f.object.dg.renderTypeForBuiltinFnName(writer, scalar_ty);
            try writer.writeByte('(');
            try f.writeCValue(writer, accum, .FunctionArgument);
            try writer.writeAll(", ");
            try f.writeCValue(writer, operand, .Other);
            try v.elem(f, writer);
            try f.object.dg.renderBuiltinInfo(writer, scalar_ty, func.info);
            try writer.writeByte(')');
        },
        .infix => |ass| {
            try writer.writeAll(ass);
            try f.writeCValue(writer, operand, .Other);
            try v.elem(f, writer);
        },
        .ternary => |cmp| {
            try writer.writeAll(" = ");
            try f.writeCValue(writer, accum, .Other);
            try writer.writeAll(cmp);
            try f.writeCValue(writer, operand, .Other);
            try v.elem(f, writer);
            try writer.writeAll(" ? ");
            try f.writeCValue(writer, accum, .Other);
            try writer.writeAll(" : ");
            try f.writeCValue(writer, operand, .Other);
            try v.elem(f, writer);
        },
    }
    try writer.writeAll(";\n");
    try v.end(f, inst, writer);

    return accum;
}

fn airAggregateInit(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const ip = &mod.intern_pool;
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const inst_ty = f.typeOfIndex(inst);
    const len = @as(usize, @intCast(inst_ty.arrayLen(mod)));
    const elements = @as([]const Air.Inst.Ref, @ptrCast(f.air.extra[ty_pl.payload..][0..len]));
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

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    switch (inst_ty.zigTypeTag(mod)) {
        .Array, .Vector => {
            const elem_ty = inst_ty.childType(mod);
            const a = try Assignment.init(f, elem_ty);
            for (resolved_elements, 0..) |element, i| {
                try a.restart(f, writer);
                try f.writeCValue(writer, local, .Other);
                try writer.print("[{d}]", .{i});
                try a.assign(f, writer);
                try f.writeCValue(writer, element, .Other);
                try a.end(f, writer);
            }
            if (inst_ty.sentinel(mod)) |sentinel| {
                try a.restart(f, writer);
                try f.writeCValue(writer, local, .Other);
                try writer.print("[{d}]", .{resolved_elements.len});
                try a.assign(f, writer);
                try f.object.dg.renderValue(writer, elem_ty, sentinel, .Other);
                try a.end(f, writer);
            }
        },
        .Struct => switch (inst_ty.containerLayout(mod)) {
            .Auto, .Extern => for (resolved_elements, 0..) |element, field_index| {
                if (inst_ty.structFieldIsComptime(field_index, mod)) continue;
                const field_ty = inst_ty.structFieldType(field_index, mod);
                if (!field_ty.hasRuntimeBitsIgnoreComptime(mod)) continue;

                const a = try Assignment.start(f, writer, field_ty);
                try f.writeCValueMember(writer, local, if (inst_ty.isSimpleTuple(mod))
                    .{ .field = field_index }
                else
                    .{ .identifier = ip.stringToSlice(inst_ty.legacyStructFieldName(@intCast(field_index), mod)) });
                try a.assign(f, writer);
                try f.writeCValue(writer, element, .Other);
                try a.end(f, writer);
            },
            .Packed => {
                try f.writeCValue(writer, local, .Other);
                try writer.writeAll(" = ");
                const int_info = inst_ty.intInfo(mod);

                const bit_offset_ty = try mod.intType(.unsigned, Type.smallestUnsignedBits(int_info.bits - 1));

                var bit_offset: u64 = 0;

                var empty = true;
                for (0..elements.len) |field_index| {
                    if (inst_ty.structFieldIsComptime(field_index, mod)) continue;
                    const field_ty = inst_ty.structFieldType(field_index, mod);
                    if (!field_ty.hasRuntimeBitsIgnoreComptime(mod)) continue;

                    if (!empty) {
                        try writer.writeAll("zig_or_");
                        try f.object.dg.renderTypeForBuiltinFnName(writer, inst_ty);
                        try writer.writeByte('(');
                    }
                    empty = false;
                }
                empty = true;
                for (resolved_elements, 0..) |element, field_index| {
                    if (inst_ty.structFieldIsComptime(field_index, mod)) continue;
                    const field_ty = inst_ty.structFieldType(field_index, mod);
                    if (!field_ty.hasRuntimeBitsIgnoreComptime(mod)) continue;

                    if (!empty) try writer.writeAll(", ");
                    // TODO: Skip this entire shift if val is 0?
                    try writer.writeAll("zig_shlw_");
                    try f.object.dg.renderTypeForBuiltinFnName(writer, inst_ty);
                    try writer.writeByte('(');

                    if (inst_ty.isAbiInt(mod) and (field_ty.isAbiInt(mod) or field_ty.isPtrAtRuntime(mod))) {
                        try f.renderIntCast(writer, inst_ty, element, .{}, field_ty, .FunctionArgument);
                    } else {
                        try writer.writeByte('(');
                        try f.renderType(writer, inst_ty);
                        try writer.writeByte(')');
                        if (field_ty.isPtrAtRuntime(mod)) {
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
                    const bit_offset_val = try mod.intValue(bit_offset_ty, bit_offset);
                    try f.object.dg.renderValue(writer, bit_offset_ty, bit_offset_val, .FunctionArgument);
                    try f.object.dg.renderBuiltinInfo(writer, inst_ty, .bits);
                    try writer.writeByte(')');
                    if (!empty) try writer.writeByte(')');

                    bit_offset += field_ty.bitSize(mod);
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
    const mod = f.object.dg.module;
    const ip = &mod.intern_pool;
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = f.air.extraData(Air.UnionInit, ty_pl.payload).data;

    const union_ty = f.typeOfIndex(inst);
    const union_obj = mod.typeToUnion(union_ty).?;
    const field_name = union_obj.field_names.get(ip)[extra.field_index];
    const payload_ty = f.typeOf(extra.init);
    const payload = try f.resolveInst(extra.init);
    try reap(f, inst, &.{extra.init});

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, union_ty);
    if (union_obj.getLayout(ip) == .Packed) {
        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(" = ");
        try f.writeCValue(writer, payload, .Initializer);
        try writer.writeAll(";\n");
        return local;
    }

    const field: CValue = if (union_ty.unionTagTypeSafety(mod)) |tag_ty| field: {
        const layout = union_ty.unionGetLayout(mod);
        if (layout.tag_size != 0) {
            const field_index = tag_ty.enumFieldIndex(field_name, mod).?;

            const tag_val = try mod.enumValueFieldIndex(tag_ty, field_index);

            const int_val = try tag_val.intFromEnum(tag_ty, mod);

            const a = try Assignment.start(f, writer, tag_ty);
            try f.writeCValueMember(writer, local, .{ .identifier = "tag" });
            try a.assign(f, writer);
            try writer.print("{}", .{try f.fmtIntLiteral(tag_ty, int_val)});
            try a.end(f, writer);
        }
        break :field .{ .payload_identifier = ip.stringToSlice(field_name) };
    } else .{ .identifier = ip.stringToSlice(field_name) };

    const a = try Assignment.start(f, writer, payload_ty);
    try f.writeCValueMember(writer, local, field);
    try a.assign(f, writer);
    try f.writeCValue(writer, payload, .Other);
    try a.end(f, writer);
    return local;
}

fn airPrefetch(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const prefetch = f.air.instructions.items(.data)[@intFromEnum(inst)].prefetch;

    const ptr_ty = f.typeOf(prefetch.ptr);
    const ptr = try f.resolveInst(prefetch.ptr);
    try reap(f, inst, &.{prefetch.ptr});

    const writer = f.object.writer();
    switch (prefetch.cache) {
        .data => {
            try writer.writeAll("zig_prefetch(");
            if (ptr_ty.isSlice(mod))
                try f.writeCValueMember(writer, ptr, .{ .identifier = "ptr" })
            else
                try f.writeCValue(writer, ptr, .FunctionArgument);
            try writer.print(", {d}, {d});\n", .{ @intFromEnum(prefetch.rw), prefetch.locality });
        },
        // The available prefetch intrinsics do not accept a cache argument; only
        // address, rw, and locality.
        .instruction => {},
    }

    return .none;
}

fn airWasmMemorySize(f: *Function, inst: Air.Inst.Index) !CValue {
    const pl_op = f.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;

    const writer = f.object.writer();
    const inst_ty = f.typeOfIndex(inst);
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);

    try writer.writeAll(" = ");
    try writer.print("zig_wasm_memory_size({d});\n", .{pl_op.payload});

    return local;
}

fn airWasmMemoryGrow(f: *Function, inst: Air.Inst.Index) !CValue {
    const pl_op = f.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;

    const writer = f.object.writer();
    const inst_ty = f.typeOfIndex(inst);
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
    const mod = f.object.dg.module;
    const un_op = f.air.instructions.items(.data)[@intFromEnum(inst)].un_op;

    const operand = try f.resolveInst(un_op);
    try reap(f, inst, &.{un_op});

    const operand_ty = f.typeOf(un_op);
    const scalar_ty = operand_ty.scalarType(mod);

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, operand_ty);
    const v = try Vectorize.start(f, inst, writer, operand_ty);
    try f.writeCValue(writer, local, .Other);
    try v.elem(f, writer);
    try writer.writeAll(" = zig_neg_");
    try f.object.dg.renderTypeForBuiltinFnName(writer, scalar_ty);
    try writer.writeByte('(');
    try f.writeCValue(writer, operand, .FunctionArgument);
    try v.elem(f, writer);
    try writer.writeAll(");\n");
    try v.end(f, inst, writer);

    return local;
}

fn airAbs(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const operand = try f.resolveInst(ty_op.operand);
    const ty = f.typeOf(ty_op.operand);
    const scalar_ty = ty.scalarType(mod);

    switch (scalar_ty.zigTypeTag(mod)) {
        .Int => if (ty.zigTypeTag(mod) == .Vector) {
            return f.fail("TODO implement airAbs for '{}'", .{ty.fmt(mod)});
        } else {
            return airUnBuiltinCall(f, inst, "abs", .none);
        },
        .Float => return unFloatOp(f, inst, operand, ty, "fabs"),
        else => unreachable,
    }
}

fn unFloatOp(f: *Function, inst: Air.Inst.Index, operand: CValue, ty: Type, operation: []const u8) !CValue {
    const mod = f.object.dg.module;
    const scalar_ty = ty.scalarType(mod);

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, ty);
    const v = try Vectorize.start(f, inst, writer, ty);
    try f.writeCValue(writer, local, .Other);
    try v.elem(f, writer);
    try writer.writeAll(" = zig_float_fn_");
    try f.object.dg.renderTypeForBuiltinFnName(writer, scalar_ty);
    try writer.print("_{s}(", .{operation});
    try f.writeCValue(writer, operand, .FunctionArgument);
    try v.elem(f, writer);
    try writer.writeAll(");\n");
    try v.end(f, inst, writer);

    return local;
}

fn airUnFloatOp(f: *Function, inst: Air.Inst.Index, operation: []const u8) !CValue {
    const un_op = f.air.instructions.items(.data)[@intFromEnum(inst)].un_op;

    const operand = try f.resolveInst(un_op);
    try reap(f, inst, &.{un_op});

    const inst_ty = f.typeOfIndex(inst);
    return unFloatOp(f, inst, operand, inst_ty, operation);
}

fn airBinFloatOp(f: *Function, inst: Air.Inst.Index, operation: []const u8) !CValue {
    const mod = f.object.dg.module;
    const bin_op = f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const lhs = try f.resolveInst(bin_op.lhs);
    const rhs = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const inst_ty = f.typeOfIndex(inst);
    const inst_scalar_ty = inst_ty.scalarType(mod);

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const v = try Vectorize.start(f, inst, writer, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try v.elem(f, writer);
    try writer.writeAll(" = zig_float_fn_");
    try f.object.dg.renderTypeForBuiltinFnName(writer, inst_scalar_ty);
    try writer.print("_{s}(", .{operation});
    try f.writeCValue(writer, lhs, .FunctionArgument);
    try v.elem(f, writer);
    try writer.writeAll(", ");
    try f.writeCValue(writer, rhs, .FunctionArgument);
    try v.elem(f, writer);
    try writer.writeAll(");\n");
    try v.end(f, inst, writer);

    return local;
}

fn airMulAdd(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const pl_op = f.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const bin_op = f.air.extraData(Air.Bin, pl_op.payload).data;

    const mulend1 = try f.resolveInst(bin_op.lhs);
    const mulend2 = try f.resolveInst(bin_op.rhs);
    const addend = try f.resolveInst(pl_op.operand);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs, pl_op.operand });

    const inst_ty = f.typeOfIndex(inst);
    const inst_scalar_ty = inst_ty.scalarType(mod);

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const v = try Vectorize.start(f, inst, writer, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try v.elem(f, writer);
    try writer.writeAll(" = zig_float_fn_");
    try f.object.dg.renderTypeForBuiltinFnName(writer, inst_scalar_ty);
    try writer.writeAll("_fma(");
    try f.writeCValue(writer, mulend1, .FunctionArgument);
    try v.elem(f, writer);
    try writer.writeAll(", ");
    try f.writeCValue(writer, mulend2, .FunctionArgument);
    try v.elem(f, writer);
    try writer.writeAll(", ");
    try f.writeCValue(writer, addend, .FunctionArgument);
    try v.elem(f, writer);
    try writer.writeAll(");\n");
    try v.end(f, inst, writer);

    return local;
}

fn airCVaStart(f: *Function, inst: Air.Inst.Index) !CValue {
    const mod = f.object.dg.module;
    const inst_ty = f.typeOfIndex(inst);
    const decl_index = f.object.dg.pass.decl;
    const decl = mod.declPtr(decl_index);
    const fn_cty = try f.typeToCType(decl.ty, .complete);
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
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const inst_ty = f.typeOfIndex(inst);
    const va_list = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = va_arg(*(va_list *)");
    try f.writeCValue(writer, va_list, .Other);
    try writer.writeAll(", ");
    try f.renderType(writer, ty_op.ty.toType());
    try writer.writeAll(");\n");
    return local;
}

fn airCVaEnd(f: *Function, inst: Air.Inst.Index) !CValue {
    const un_op = f.air.instructions.items(.data)[@intFromEnum(inst)].un_op;

    const va_list = try f.resolveInst(un_op);
    try reap(f, inst, &.{un_op});

    const writer = f.object.writer();
    try writer.writeAll("va_end(*(va_list *)");
    try f.writeCValue(writer, va_list, .Other);
    try writer.writeAll(");\n");
    return .none;
}

fn airCVaCopy(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const inst_ty = f.typeOfIndex(inst);
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
        .Unordered, .Monotonic => "zig_memory_order_relaxed",
        .Acquire => "zig_memory_order_acquire",
        .Release => "zig_memory_order_release",
        .AcqRel => "zig_memory_order_acq_rel",
        .SeqCst => "zig_memory_order_seq_cst",
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

const ArrayListWriter = ErrorOnlyGenericWriter(std.ArrayList(u8).Writer.Error);

fn arrayListWriter(list: *std.ArrayList(u8)) ArrayListWriter {
    return .{ .context = .{
        .context = list,
        .writeFn = struct {
            fn write(context: *const anyopaque, bytes: []const u8) anyerror!usize {
                const l: *std.ArrayList(u8) = @alignCast(@constCast(@ptrCast(context)));
                return l.writer().write(bytes);
            }
        }.write,
    } };
}

fn IndentWriter(comptime UnderlyingWriter: type) type {
    return struct {
        const Self = @This();
        pub const Error = UnderlyingWriter.Error;
        pub const Writer = ErrorOnlyGenericWriter(Error);

        pub const indent_delta = 1;

        underlying_writer: UnderlyingWriter,
        indent_count: usize = 0,
        current_line_empty: bool = true,

        pub fn writer(self: *Self) Writer {
            return .{ .context = .{
                .context = self,
                .writeFn = writeAny,
            } };
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

        fn writeAny(context: *const anyopaque, bytes: []const u8) anyerror!usize {
            const self: *Self = @alignCast(@constCast(@ptrCast(context)));
            return self.write(bytes);
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

/// A wrapper around `std.io.AnyWriter` that maintains a generic error set while
/// erasing the rest of the implementation. This is intended to avoid duplicate
/// generic instantiations for writer types which share the same error set, while
/// maintaining ease of error handling.
fn ErrorOnlyGenericWriter(comptime Error: type) type {
    return std.io.GenericWriter(std.io.AnyWriter, Error, struct {
        fn write(context: std.io.AnyWriter, bytes: []const u8) Error!usize {
            return @errorCast(context.write(bytes));
        }
    }.write);
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

fn compilerRtAbbrev(ty: Type, mod: *Module) []const u8 {
    const target = mod.getTarget();
    return if (ty.isInt(mod)) switch (ty.intInfo(mod).bits) {
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

fn compareOperatorAbbrev(operator: std.math.CompareOperator) []const u8 {
    return switch (operator) {
        .lt => "lt",
        .lte => "le",
        .eq => "eq",
        .gte => "ge",
        .gt => "gt",
        .neq => "ne",
    };
}

fn compareOperatorC(operator: std.math.CompareOperator) []const u8 {
    return switch (operator) {
        .lt => "<",
        .lte => "<=",
        .eq => "==",
        .gte => ">=",
        .gt => ">",
        .neq => "!=",
    };
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
    return @as(IntType, @bitCast(@as(UnsignedType, (1 << (int_info.bits | 1)) / 3)));
}

const FormatIntLiteralContext = struct {
    dg: *DeclGen,
    int_info: InternPool.Key.IntType,
    kind: CType.Kind,
    cty: CType,
    val: Value,
};
fn formatIntLiteral(
    data: FormatIntLiteralContext,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    const mod = data.dg.module;
    const target = mod.getTarget();

    const ExpectedContents = struct {
        const base = 10;
        const bits = 128;
        const limbs_count = BigInt.calcTwosCompLimbCount(bits);

        undef_limbs: [limbs_count]BigIntLimb,
        wrap_limbs: [limbs_count]BigIntLimb,
        to_string_buf: [bits]u8,
        to_string_limbs: [BigInt.calcToStringLimbsBufferLen(limbs_count, base)]BigIntLimb,
    };
    var stack align(@alignOf(ExpectedContents)) =
        std.heap.stackFallback(@sizeOf(ExpectedContents), data.dg.gpa);
    const allocator = stack.get();

    var undef_limbs: []BigIntLimb = &.{};
    defer allocator.free(undef_limbs);

    var int_buf: Value.BigIntSpace = undefined;
    const int = if (data.val.isUndefDeep(mod)) blk: {
        undef_limbs = try allocator.alloc(BigIntLimb, BigInt.calcTwosCompLimbCount(data.int_info.bits));
        @memset(undef_limbs, undefPattern(BigIntLimb));

        var undef_int = BigInt.Mutable{
            .limbs = undef_limbs,
            .len = undef_limbs.len,
            .positive = true,
        };
        undef_int.truncate(undef_int.toConst(), data.int_info.signedness, data.int_info.bits);
        break :blk undef_int.toConst();
    } else data.val.toBigInt(&int_buf, mod);
    assert(int.fitsInTwosComp(data.int_info.signedness, data.int_info.bits));

    const c_bits: usize = @intCast(data.cty.byteSize(data.dg.ctypes.set, target) * 8);
    var one_limbs: [BigInt.calcLimbLen(1)]BigIntLimb = undefined;
    const one = BigInt.Mutable.init(&one_limbs, 1).toConst();

    var wrap = BigInt.Mutable{
        .limbs = try allocator.alloc(BigIntLimb, BigInt.calcTwosCompLimbCount(c_bits)),
        .len = undefined,
        .positive = undefined,
    };
    defer allocator.free(wrap.limbs);

    const c_limb_info: struct {
        cty: CType,
        count: usize,
        endian: std.builtin.Endian,
        homogeneous: bool,
    } = switch (data.cty.tag()) {
        else => .{
            .cty = CType.initTag(.void),
            .count = 1,
            .endian = .little,
            .homogeneous = true,
        },
        .zig_u128, .zig_i128 => .{
            .cty = CType.initTag(.uint64_t),
            .count = 2,
            .endian = .big,
            .homogeneous = false,
        },
        .array => info: {
            const array_data = data.cty.castTag(.array).?.data;
            break :info .{
                .cty = data.dg.indexToCType(array_data.elem_type),
                .count = @as(usize, @intCast(array_data.len)),
                .endian = target.cpu.arch.endian(),
                .homogeneous = true,
            };
        },
    };
    if (c_limb_info.count == 1) {
        if (wrap.addWrap(int, one, data.int_info.signedness, c_bits) or
            data.int_info.signedness == .signed and wrap.subWrap(int, one, data.int_info.signedness, c_bits))
            return writer.print("{s}_{s}", .{
                data.cty.getStandardDefineAbbrev() orelse return writer.print("zig_{s}Int_{c}{d}", .{
                    if (int.positive) "max" else "min", signAbbrev(data.int_info.signedness), c_bits,
                }),
                if (int.positive) "MAX" else "MIN",
            });

        if (!int.positive) try writer.writeByte('-');
        try data.cty.renderLiteralPrefix(writer, data.kind);

        const style: struct { base: u8, case: std.fmt.Case = undefined } = switch (fmt.len) {
            0 => .{ .base = 10 },
            1 => switch (fmt[0]) {
                'b' => style: {
                    try writer.writeAll("0b");
                    break :style .{ .base = 2 };
                },
                'o' => style: {
                    try writer.writeByte('0');
                    break :style .{ .base = 8 };
                },
                'd' => .{ .base = 10 },
                'x', 'X' => |base| style: {
                    try writer.writeAll("0x");
                    break :style .{ .base = 16, .case = switch (base) {
                        'x' => .lower,
                        'X' => .upper,
                        else => unreachable,
                    } };
                },
                else => @compileError("Invalid fmt: " ++ fmt),
            },
            else => @compileError("Invalid fmt: " ++ fmt),
        };

        const string = try int.abs().toStringAlloc(allocator, style.base, style.case);
        defer allocator.free(string);
        try writer.writeAll(string);
    } else {
        try data.cty.renderLiteralPrefix(writer, data.kind);
        wrap.convertToTwosComplement(int, data.int_info.signedness, c_bits);
        @memset(wrap.limbs[wrap.len..], 0);
        wrap.len = wrap.limbs.len;
        const limbs_per_c_limb = @divExact(wrap.len, c_limb_info.count);

        var c_limb_int_info = std.builtin.Type.Int{
            .signedness = undefined,
            .bits = @as(u16, @intCast(@divExact(c_bits, c_limb_info.count))),
        };
        var c_limb_cty: CType = undefined;

        var limb_offset: usize = 0;
        const most_significant_limb_i = wrap.len - limbs_per_c_limb;
        while (limb_offset < wrap.len) : (limb_offset += limbs_per_c_limb) {
            const limb_i = switch (c_limb_info.endian) {
                .little => limb_offset,
                .big => most_significant_limb_i - limb_offset,
            };
            var c_limb_mut = BigInt.Mutable{
                .limbs = wrap.limbs[limb_i..][0..limbs_per_c_limb],
                .len = undefined,
                .positive = true,
            };
            c_limb_mut.normalize(limbs_per_c_limb);

            if (limb_i == most_significant_limb_i and
                !c_limb_info.homogeneous and data.int_info.signedness == .signed)
            {
                // most significant limb is actually signed
                c_limb_int_info.signedness = .signed;
                c_limb_cty = c_limb_info.cty.toSigned();

                c_limb_mut.positive = wrap.positive;
                c_limb_mut.truncate(
                    c_limb_mut.toConst(),
                    .signed,
                    data.int_info.bits - limb_i * @bitSizeOf(BigIntLimb),
                );
            } else {
                c_limb_int_info.signedness = .unsigned;
                c_limb_cty = c_limb_info.cty;
            }

            if (limb_offset > 0) try writer.writeAll(", ");
            try formatIntLiteral(.{
                .dg = data.dg,
                .int_info = c_limb_int_info,
                .kind = data.kind,
                .cty = c_limb_cty,
                .val = try mod.intValue_big(Type.comptime_int, c_limb_mut.toConst()),
            }, fmt, options, writer);
        }
    }
    try data.cty.renderLiteralSuffix(writer);
}

const Materialize = struct {
    local: CValue,

    pub fn start(
        f: *Function,
        inst: Air.Inst.Index,
        writer: anytype,
        ty: Type,
        value: CValue,
    ) !Materialize {
        switch (value) {
            .local_ref, .constant, .decl_ref, .undef => {
                const local = try f.allocLocal(inst, ty);

                const a = try Assignment.start(f, writer, ty);
                try f.writeCValue(writer, local, .Other);
                try a.assign(f, writer);
                try f.writeCValue(writer, value, .Other);
                try a.end(f, writer);

                return .{ .local = local };
            },
            .new_local => |local| return .{ .local = .{ .local = local } },
            else => return .{ .local = value },
        }
    }

    pub fn mat(self: Materialize, f: *Function, writer: anytype) !void {
        try f.writeCValue(writer, self.local, .Other);
    }

    pub fn end(self: Materialize, f: *Function, inst: Air.Inst.Index) !void {
        switch (self.local) {
            .new_local => |local| try freeLocal(f, inst, local, null),
            else => {},
        }
    }
};

const Assignment = struct {
    cty: CType.Index,

    pub fn init(f: *Function, ty: Type) !Assignment {
        return .{ .cty = try f.typeToIndex(ty, .complete) };
    }

    pub fn start(f: *Function, writer: anytype, ty: Type) !Assignment {
        const self = try init(f, ty);
        try self.restart(f, writer);
        return self;
    }

    pub fn restart(self: Assignment, f: *Function, writer: anytype) !void {
        switch (self.strategy(f)) {
            .assign => {},
            .memcpy => try writer.writeAll("memcpy("),
        }
    }

    pub fn assign(self: Assignment, f: *Function, writer: anytype) !void {
        switch (self.strategy(f)) {
            .assign => try writer.writeAll(" = "),
            .memcpy => try writer.writeAll(", "),
        }
    }

    pub fn end(self: Assignment, f: *Function, writer: anytype) !void {
        switch (self.strategy(f)) {
            .assign => {},
            .memcpy => {
                try writer.writeAll(", sizeof(");
                try f.renderCType(writer, self.cty);
                try writer.writeAll("))");
            },
        }
        try writer.writeAll(";\n");
    }

    fn strategy(self: Assignment, f: *Function) enum { assign, memcpy } {
        return switch (f.indexToCType(self.cty).tag()) {
            else => .assign,
            .array, .vector => .memcpy,
        };
    }
};

const Vectorize = struct {
    index: CValue = .none,

    pub fn start(f: *Function, inst: Air.Inst.Index, writer: anytype, ty: Type) !Vectorize {
        const mod = f.object.dg.module;
        return if (ty.zigTypeTag(mod) == .Vector) index: {
            const len_val = try mod.intValue(Type.usize, ty.vectorLen(mod));

            const local = try f.allocLocal(inst, Type.usize);

            try writer.writeAll("for (");
            try f.writeCValue(writer, local, .Other);
            try writer.print(" = {d}; ", .{try f.fmtIntLiteral(Type.usize, try mod.intValue(Type.usize, 0))});
            try f.writeCValue(writer, local, .Other);
            try writer.print(" < {d}; ", .{
                try f.fmtIntLiteral(Type.usize, len_val),
            });
            try f.writeCValue(writer, local, .Other);
            try writer.print(" += {d}) {{\n", .{try f.fmtIntLiteral(Type.usize, try mod.intValue(Type.usize, 1))});
            f.object.indent_writer.pushIndent();

            break :index .{ .index = local };
        } else .{};
    }

    pub fn elem(self: Vectorize, f: *Function, writer: anytype) !void {
        if (self.index != .none) {
            try writer.writeByte('[');
            try f.writeCValue(writer, self.index, .Other);
            try writer.writeByte(']');
        }
    }

    pub fn end(self: Vectorize, f: *Function, inst: Air.Inst.Index, writer: anytype) !void {
        if (self.index != .none) {
            f.object.indent_writer.popIndent();
            try writer.writeAll("}\n");
            try freeLocal(f, inst, self.index.new_local, null);
        }
    }
};

fn lowerFnRetTy(ret_ty: Type, mod: *Module) !Type {
    if (ret_ty.ip_index == .noreturn_type) return Type.noreturn;

    if (lowersToArray(ret_ty, mod)) {
        const gpa = mod.gpa;
        const ip = &mod.intern_pool;
        const names = [1]InternPool.NullTerminatedString{
            try ip.getOrPutString(gpa, "array"),
        };
        const types = [1]InternPool.Index{ret_ty.ip_index};
        const values = [1]InternPool.Index{.none};
        const interned = try ip.getAnonStructType(gpa, .{
            .names = &names,
            .types = &types,
            .values = &values,
        });
        return Type.fromInterned(interned);
    }

    return if (ret_ty.hasRuntimeBitsIgnoreComptime(mod)) ret_ty else Type.void;
}

fn lowersToArray(ty: Type, mod: *Module) bool {
    return switch (ty.zigTypeTag(mod)) {
        .Array, .Vector => return true,
        else => return ty.isAbiInt(mod) and toCIntBits(@as(u32, @intCast(ty.bitSize(mod)))) == null,
    };
}

fn reap(f: *Function, inst: Air.Inst.Index, operands: []const Air.Inst.Ref) !void {
    assert(operands.len <= Liveness.bpi - 1);
    var tomb_bits = f.liveness.getTombBits(inst);
    for (operands) |operand| {
        const dies = @as(u1, @truncate(tomb_bits)) != 0;
        tomb_bits >>= 1;
        if (!dies) continue;
        try die(f, inst, operand);
    }
}

fn die(f: *Function, inst: Air.Inst.Index, ref: Air.Inst.Ref) !void {
    const ref_inst = ref.toIndex() orelse return;
    const c_value = (f.value_map.fetchRemove(ref) orelse return).value;
    const local_index = switch (c_value) {
        .local, .new_local => |l| l,
        else => return,
    };
    try freeLocal(f, inst, local_index, ref_inst);
}

fn freeLocal(f: *Function, inst: ?Air.Inst.Index, local_index: LocalIndex, ref_inst: ?Air.Inst.Index) !void {
    const gpa = f.object.dg.gpa;
    const local = &f.locals.items[local_index];
    if (inst) |i| {
        if (ref_inst) |operand| {
            log.debug("%{d}: freeing t{d} (operand %{d})", .{ @intFromEnum(i), local_index, operand });
        } else {
            log.debug("%{d}: freeing t{d}", .{ @intFromEnum(i), local_index });
        }
    } else {
        if (ref_inst) |operand| {
            log.debug("freeing t{d} (operand %{d})", .{ local_index, operand });
        } else {
            log.debug("freeing t{d}", .{local_index});
        }
    }
    const gop = try f.free_locals_map.getOrPut(gpa, local.getType());
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
