const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const mem = std.mem;
const log = std.log.scoped(.c);

const link = @import("../link.zig");
const Zcu = @import("../Zcu.zig");
const Module = @import("../Package/Module.zig");
const Compilation = @import("../Compilation.zig");
const Value = @import("../Value.zig");
const Type = @import("../Type.zig");
const C = link.File.C;
const Decl = Zcu.Decl;
const trace = @import("../tracy.zig").trace;
const Air = @import("../Air.zig");
const Liveness = @import("../Liveness.zig");
const InternPool = @import("../InternPool.zig");
const Alignment = InternPool.Alignment;

const BigIntLimb = std.math.big.Limb;
const BigInt = std.math.big.int;

pub const CType = @import("c/Type.zig");

pub const CValue = union(enum) {
    none: void,
    new_local: LocalIndex,
    local: LocalIndex,
    /// Address of a local.
    local_ref: LocalIndex,
    /// A constant instruction, to be rendered inline.
    constant: Value,
    /// Index into the parameters
    arg: usize,
    /// The array field of a parameter
    arg_array: usize,
    /// Index into a tuple's fields
    field: usize,
    /// By-value
    nav: InternPool.Nav.Index,
    nav_ref: InternPool.Nav.Index,
    /// An undefined value (cannot be dereferenced)
    undef: Type,
    /// Rendered as an identifier (using fmtIdent)
    identifier: []const u8,
    /// Rendered as "payload." followed by as identifier (using fmtIdent)
    payload_identifier: []const u8,
    /// Rendered with fmtCTypePoolString
    ctype_pool_string: CType.Pool.String,
};

const BlockData = struct {
    block_id: usize,
    result: CValue,
};

pub const CValueMap = std.AutoHashMap(Air.Inst.Ref, CValue);

pub const LazyFnKey = union(enum) {
    tag_name: InternPool.Index,
    never_tail: InternPool.Nav.Index,
    never_inline: InternPool.Nav.Index,
};
pub const LazyFnValue = struct {
    fn_name: CType.Pool.String,
};
pub const LazyFnMap = std.AutoArrayHashMapUnmanaged(LazyFnKey, LazyFnValue);

const Local = struct {
    ctype: CType,
    flags: packed struct(u32) {
        alignas: CType.AlignAs,
        _: u20 = undefined,
    },

    fn getType(local: Local) LocalType {
        return .{ .ctype = local.ctype, .alignas = local.flags.alignas };
    }
};

const LocalIndex = u16;
const LocalType = struct { ctype: CType, alignas: CType.AlignAs };
const LocalsList = std.AutoArrayHashMapUnmanaged(LocalIndex, void);
const LocalsMap = std.AutoArrayHashMapUnmanaged(LocalType, LocalsList);

const ValueRenderLocation = enum {
    FunctionArgument,
    Initializer,
    StaticInitializer,
    Other,

    fn isInitializer(loc: ValueRenderLocation) bool {
        return switch (loc) {
            .Initializer, .StaticInitializer => true,
            else => false,
        };
    }

    fn toCTypeKind(loc: ValueRenderLocation) CType.Kind {
        return switch (loc) {
            .FunctionArgument => .parameter,
            .Initializer, .Other => .complete,
            .StaticInitializer => .global,
        };
    }
};

const BuiltinInfo = enum { none, bits };

const reserved_idents = std.StaticStringMap(void).initComptime(.{
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
    .{ "typeof", {} },
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
    comptime fmt_str: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    const solo = fmt_str.len != 0 and fmt_str[0] == ' '; // space means solo; not part of a bigger ident.
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

const CTypePoolStringFormatData = struct {
    ctype_pool_string: CType.Pool.String,
    ctype_pool: *const CType.Pool,
};
fn formatCTypePoolString(
    data: CTypePoolStringFormatData,
    comptime fmt_str: []const u8,
    fmt_opts: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    if (data.ctype_pool_string.toSlice(data.ctype_pool)) |slice|
        try formatIdent(slice, fmt_str, fmt_opts, writer)
    else
        try writer.print("{}", .{data.ctype_pool_string.fmt(data.ctype_pool)});
}
pub fn fmtCTypePoolString(
    ctype_pool_string: CType.Pool.String,
    ctype_pool: *const CType.Pool,
) std.fmt.Formatter(formatCTypePoolString) {
    return .{ .data = .{ .ctype_pool_string = ctype_pool_string, .ctype_pool = ctype_pool } };
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
    blocks: std.AutoHashMapUnmanaged(Air.Inst.Index, BlockData) = .empty,
    next_arg_index: usize = 0,
    next_block_index: usize = 0,
    object: Object,
    lazy_fns: LazyFnMap,
    func_index: InternPool.Index,
    /// All the locals, to be emitted at the top of the function.
    locals: std.ArrayListUnmanaged(Local) = .empty,
    /// Which locals are available for reuse, based on Type.
    free_locals_map: LocalsMap = .{},
    /// Locals which will not be freed by Liveness. This is used after a
    /// Function body is lowered in order to make `free_locals_map` have
    /// 100% of the locals within so that it can be used to render the block
    /// of variable declarations at the top of a function, sorted descending
    /// by type alignment.
    /// The value is whether the alloc needs to be emitted in the header.
    allocs: std.AutoArrayHashMapUnmanaged(LocalIndex, bool) = .empty,
    /// Maps from `loop_switch_br` instructions to the allocated local used
    /// for the switch cond. Dispatches should set this local to the new cond.
    loop_switch_conds: std.AutoHashMapUnmanaged(Air.Inst.Index, LocalIndex) = .empty,

    fn resolveInst(f: *Function, ref: Air.Inst.Ref) !CValue {
        const gop = try f.value_map.getOrPut(ref);
        if (gop.found_existing) return gop.value_ptr.*;

        const pt = f.object.dg.pt;
        const val = (try f.air.value(ref, pt)).?;
        const ty = f.typeOf(ref);

        const result: CValue = if (lowersToArray(ty, pt)) result: {
            const writer = f.object.codeHeaderWriter();
            const decl_c_value = try f.allocLocalValue(.{
                .ctype = try f.ctypeFromType(ty, .complete),
                .alignas = CType.AlignAs.fromAbiAlignment(ty.abiAlignment(pt.zcu)),
            });
            const gpa = f.object.dg.gpa;
            try f.allocs.put(gpa, decl_c_value.new_local, false);
            try writer.writeAll("static ");
            try f.object.dg.renderTypeAndName(writer, ty, decl_c_value, Const, .none, .complete);
            try writer.writeAll(" = ");
            try f.object.dg.renderValue(writer, val, .StaticInitializer);
            try writer.writeAll(";\n ");
            break :result .{ .local = decl_c_value.new_local };
        } else .{ .constant = val };

        gop.value_ptr.* = result;
        return result;
    }

    fn wantSafety(f: *Function) bool {
        return switch (f.object.dg.pt.zcu.optimizeMode()) {
            .Debug, .ReleaseSafe => true,
            .ReleaseFast, .ReleaseSmall => false,
        };
    }

    /// Skips the reuse logic. This function should be used for any persistent allocation, i.e.
    /// those which go into `allocs`. This function does not add the resulting local into `allocs`;
    /// that responsibility lies with the caller.
    fn allocLocalValue(f: *Function, local_type: LocalType) !CValue {
        try f.locals.ensureUnusedCapacity(f.object.dg.gpa, 1);
        defer f.locals.appendAssumeCapacity(.{
            .ctype = local_type.ctype,
            .flags = .{ .alignas = local_type.alignas },
        });
        return .{ .new_local = @intCast(f.locals.items.len) };
    }

    fn allocLocal(f: *Function, inst: ?Air.Inst.Index, ty: Type) !CValue {
        return f.allocAlignedLocal(inst, .{
            .ctype = try f.ctypeFromType(ty, .complete),
            .alignas = CType.AlignAs.fromAbiAlignment(ty.abiAlignment(f.object.dg.pt.zcu)),
        });
    }

    /// Only allocates the local; does not print anything. Will attempt to re-use locals, so should
    /// not be used for persistent locals (i.e. those in `allocs`).
    fn allocAlignedLocal(f: *Function, inst: ?Air.Inst.Index, local_type: LocalType) !CValue {
        const result: CValue = result: {
            if (f.free_locals_map.getPtr(local_type)) |locals_list| {
                if (locals_list.popOrNull()) |local_entry| {
                    break :result .{ .new_local = local_entry.key };
                }
            }
            break :result try f.allocLocalValue(local_type);
        };
        if (inst) |i| {
            log.debug("%{d}: allocating t{d}", .{ i, result.new_local });
        } else {
            log.debug("allocating t{d}", .{result.new_local});
        }
        return result;
    }

    fn writeCValue(f: *Function, w: anytype, c_value: CValue, location: ValueRenderLocation) !void {
        switch (c_value) {
            .none => unreachable,
            .new_local, .local => |i| try w.print("t{d}", .{i}),
            .local_ref => |i| try w.print("&t{d}", .{i}),
            .constant => |val| try f.object.dg.renderValue(w, val, location),
            .arg => |i| try w.print("a{d}", .{i}),
            .arg_array => |i| try f.writeCValueMember(w, .{ .arg = i }, .{ .identifier = "array" }),
            .undef => |ty| try f.object.dg.renderUndefValue(w, ty, location),
            else => try f.object.dg.writeCValue(w, c_value),
        }
    }

    fn writeCValueDeref(f: *Function, w: anytype, c_value: CValue) !void {
        switch (c_value) {
            .none => unreachable,
            .new_local, .local, .constant => {
                try w.writeAll("(*");
                try f.writeCValue(w, c_value, .Other);
                try w.writeByte(')');
            },
            .local_ref => |i| try w.print("t{d}", .{i}),
            .arg => |i| try w.print("(*a{d})", .{i}),
            .arg_array => |i| {
                try w.writeAll("(*");
                try f.writeCValueMember(w, .{ .arg = i }, .{ .identifier = "array" });
                try w.writeByte(')');
            },
            else => try f.object.dg.writeCValueDeref(w, c_value),
        }
    }

    fn writeCValueMember(
        f: *Function,
        writer: anytype,
        c_value: CValue,
        member: CValue,
    ) error{ OutOfMemory, AnalysisFail }!void {
        switch (c_value) {
            .new_local, .local, .local_ref, .constant, .arg, .arg_array => {
                try f.writeCValue(writer, c_value, .Other);
                try writer.writeByte('.');
                try f.writeCValue(writer, member, .Other);
            },
            else => return f.object.dg.writeCValueMember(writer, c_value, member),
        }
    }

    fn writeCValueDerefMember(f: *Function, writer: anytype, c_value: CValue, member: CValue) !void {
        switch (c_value) {
            .new_local, .local, .arg, .arg_array => {
                try f.writeCValue(writer, c_value, .Other);
                try writer.writeAll("->");
            },
            .constant => {
                try writer.writeByte('(');
                try f.writeCValue(writer, c_value, .Other);
                try writer.writeAll(")->");
            },
            .local_ref => {
                try f.writeCValueDeref(writer, c_value);
                try writer.writeByte('.');
            },
            else => return f.object.dg.writeCValueDerefMember(writer, c_value, member),
        }
        try f.writeCValue(writer, member, .Other);
    }

    fn fail(f: *Function, comptime format: []const u8, args: anytype) error{ AnalysisFail, OutOfMemory } {
        return f.object.dg.fail(format, args);
    }

    fn ctypeFromType(f: *Function, ty: Type, kind: CType.Kind) !CType {
        return f.object.dg.ctypeFromType(ty, kind);
    }

    fn byteSize(f: *Function, ctype: CType) u64 {
        return f.object.dg.byteSize(ctype);
    }

    fn renderType(f: *Function, w: anytype, ctype: Type) !void {
        return f.object.dg.renderType(w, ctype);
    }

    fn renderCType(f: *Function, w: anytype, ctype: CType) !void {
        return f.object.dg.renderCType(w, ctype);
    }

    fn renderIntCast(f: *Function, w: anytype, dest_ty: Type, src: CValue, v: Vectorize, src_ty: Type, location: ValueRenderLocation) !void {
        return f.object.dg.renderIntCast(w, dest_ty, .{ .c_value = .{ .f = f, .value = src, .v = v } }, src_ty, location);
    }

    fn fmtIntLiteral(f: *Function, val: Value) !std.fmt.Formatter(formatIntLiteral) {
        return f.object.dg.fmtIntLiteral(val, .Other);
    }

    fn getLazyFnName(f: *Function, key: LazyFnKey) ![]const u8 {
        const gpa = f.object.dg.gpa;
        const pt = f.object.dg.pt;
        const zcu = pt.zcu;
        const ip = &zcu.intern_pool;
        const ctype_pool = &f.object.dg.ctype_pool;

        const gop = try f.lazy_fns.getOrPut(gpa, key);
        if (!gop.found_existing) {
            errdefer _ = f.lazy_fns.pop();

            gop.value_ptr.* = .{
                .fn_name = switch (key) {
                    .tag_name,
                    => |enum_ty| try ctype_pool.fmt(gpa, "zig_{s}_{}__{d}", .{
                        @tagName(key),
                        fmtIdent(ip.loadEnumType(enum_ty).name.toSlice(ip)),
                        @intFromEnum(enum_ty),
                    }),
                    .never_tail,
                    .never_inline,
                    => |owner_nav| try ctype_pool.fmt(gpa, "zig_{s}_{}__{d}", .{
                        @tagName(key),
                        fmtIdent(ip.getNav(owner_nav).name.toSlice(ip)),
                        @intFromEnum(owner_nav),
                    }),
                },
            };
        }
        return gop.value_ptr.fn_name.toSlice(ctype_pool).?;
    }

    pub fn deinit(f: *Function) void {
        const gpa = f.object.dg.gpa;
        f.allocs.deinit(gpa);
        f.locals.deinit(gpa);
        deinitFreeLocalsMap(gpa, &f.free_locals_map);
        f.blocks.deinit(gpa);
        f.value_map.deinit();
        f.lazy_fns.deinit(gpa);
        f.loop_switch_conds.deinit(gpa);
    }

    fn typeOf(f: *Function, inst: Air.Inst.Ref) Type {
        return f.air.typeOf(inst, &f.object.dg.pt.zcu.intern_pool);
    }

    fn typeOfIndex(f: *Function, inst: Air.Inst.Index) Type {
        return f.air.typeOfIndex(inst, &f.object.dg.pt.zcu.intern_pool);
    }

    fn copyCValue(f: *Function, ctype: CType, dst: CValue, src: CValue) !void {
        switch (dst) {
            .new_local, .local => |dst_local_index| switch (src) {
                .new_local, .local => |src_local_index| if (dst_local_index == src_local_index) return,
                else => {},
            },
            else => {},
        }
        const writer = f.object.writer();
        const a = try Assignment.start(f, writer, ctype);
        try f.writeCValue(writer, dst, .Other);
        try a.assign(f, writer);
        try f.writeCValue(writer, src, .Initializer);
        try a.end(f, writer);
    }

    fn moveCValue(f: *Function, inst: Air.Inst.Index, ty: Type, src: CValue) !CValue {
        switch (src) {
            // Move the freshly allocated local to be owned by this instruction,
            // by returning it here instead of freeing it.
            .new_local => return src,
            else => {
                try freeCValue(f, inst, src);
                const dst = try f.allocLocal(inst, ty);
                try f.copyCValue(try f.ctypeFromType(ty, .complete), dst, src);
                return dst;
            },
        }
    }

    fn freeCValue(f: *Function, inst: ?Air.Inst.Index, val: CValue) !void {
        switch (val) {
            .new_local => |local_index| try freeLocal(f, inst, local_index, null),
            else => {},
        }
    }
};

/// This data is available when outputting .c code for a `Zcu`.
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
    pt: Zcu.PerThread,
    mod: *Module,
    pass: Pass,
    is_naked_fn: bool,
    /// This is a borrowed reference from `link.C`.
    fwd_decl: std.ArrayList(u8),
    error_msg: ?*Zcu.ErrorMsg,
    ctype_pool: CType.Pool,
    scratch: std.ArrayListUnmanaged(u32),
    /// Keeps track of anonymous decls that need to be rendered before this
    /// (named) Decl in the output C code.
    uav_deps: std.AutoArrayHashMapUnmanaged(InternPool.Index, C.AvBlock),
    aligned_uavs: std.AutoArrayHashMapUnmanaged(InternPool.Index, Alignment),

    pub const Pass = union(enum) {
        nav: InternPool.Nav.Index,
        uav: InternPool.Index,
        flush,
    };

    fn fwdDeclWriter(dg: *DeclGen) ArrayListWriter {
        return arrayListWriter(&dg.fwd_decl);
    }

    fn fail(dg: *DeclGen, comptime format: []const u8, args: anytype) error{ AnalysisFail, OutOfMemory } {
        @branchHint(.cold);
        const zcu = dg.pt.zcu;
        const src_loc = zcu.navSrcLoc(dg.pass.nav);
        dg.error_msg = try Zcu.ErrorMsg.create(dg.gpa, src_loc, format, args);
        return error.AnalysisFail;
    }

    fn renderUav(
        dg: *DeclGen,
        writer: anytype,
        uav: InternPool.Key.Ptr.BaseAddr.Uav,
        location: ValueRenderLocation,
    ) error{ OutOfMemory, AnalysisFail }!void {
        const pt = dg.pt;
        const zcu = pt.zcu;
        const ip = &zcu.intern_pool;
        const ctype_pool = &dg.ctype_pool;
        const uav_val = Value.fromInterned(uav.val);
        const uav_ty = uav_val.typeOf(zcu);

        // Render an undefined pointer if we have a pointer to a zero-bit or comptime type.
        const ptr_ty = Type.fromInterned(uav.orig_ty);
        if (ptr_ty.isPtrAtRuntime(zcu) and !uav_ty.isFnOrHasRuntimeBits(zcu)) {
            return dg.writeCValue(writer, .{ .undef = ptr_ty });
        }

        // Chase function values in order to be able to reference the original function.
        switch (ip.indexToKey(uav.val)) {
            .variable => unreachable,
            .func => |func| return dg.renderNav(writer, func.owner_nav, location),
            .@"extern" => |@"extern"| return dg.renderNav(writer, @"extern".owner_nav, location),
            else => {},
        }

        // We shouldn't cast C function pointers as this is UB (when you call
        // them).  The analysis until now should ensure that the C function
        // pointers are compatible.  If they are not, then there is a bug
        // somewhere and we should let the C compiler tell us about it.
        const ptr_ctype = try dg.ctypeFromType(ptr_ty, .complete);
        const elem_ctype = ptr_ctype.info(ctype_pool).pointer.elem_ctype;
        const uav_ctype = try dg.ctypeFromType(uav_ty, .complete);
        const need_cast = !elem_ctype.eql(uav_ctype) and
            (elem_ctype.info(ctype_pool) != .function or uav_ctype.info(ctype_pool) != .function);
        if (need_cast) {
            try writer.writeAll("((");
            try dg.renderCType(writer, ptr_ctype);
            try writer.writeByte(')');
        }
        try writer.writeByte('&');
        try renderUavName(writer, uav_val);
        if (need_cast) try writer.writeByte(')');

        // Indicate that the anon decl should be rendered to the output so that
        // our reference above is not undefined.
        const ptr_type = ip.indexToKey(uav.orig_ty).ptr_type;
        const gop = try dg.uav_deps.getOrPut(dg.gpa, uav.val);
        if (!gop.found_existing) gop.value_ptr.* = .{};

        // Only insert an alignment entry if the alignment is greater than ABI
        // alignment. If there is already an entry, keep the greater alignment.
        const explicit_alignment = ptr_type.flags.alignment;
        if (explicit_alignment != .none) {
            const abi_alignment = Type.fromInterned(ptr_type.child).abiAlignment(zcu);
            if (explicit_alignment.order(abi_alignment).compare(.gt)) {
                const aligned_gop = try dg.aligned_uavs.getOrPut(dg.gpa, uav.val);
                aligned_gop.value_ptr.* = if (aligned_gop.found_existing)
                    aligned_gop.value_ptr.maxStrict(explicit_alignment)
                else
                    explicit_alignment;
            }
        }
    }

    fn renderNav(
        dg: *DeclGen,
        writer: anytype,
        nav_index: InternPool.Nav.Index,
        location: ValueRenderLocation,
    ) error{ OutOfMemory, AnalysisFail }!void {
        _ = location;
        const pt = dg.pt;
        const zcu = pt.zcu;
        const ip = &zcu.intern_pool;
        const ctype_pool = &dg.ctype_pool;

        // Chase function values in order to be able to reference the original function.
        const owner_nav = switch (ip.indexToKey(zcu.navValue(nav_index).toIntern())) {
            .variable => |variable| variable.owner_nav,
            .func => |func| func.owner_nav,
            .@"extern" => |@"extern"| @"extern".owner_nav,
            else => nav_index,
        };

        // Render an undefined pointer if we have a pointer to a zero-bit or comptime type.
        const nav_ty = Type.fromInterned(ip.getNav(owner_nav).typeOf(ip));
        const ptr_ty = try pt.navPtrType(owner_nav);
        if (!nav_ty.isFnOrHasRuntimeBits(zcu)) {
            return dg.writeCValue(writer, .{ .undef = ptr_ty });
        }

        // We shouldn't cast C function pointers as this is UB (when you call
        // them).  The analysis until now should ensure that the C function
        // pointers are compatible.  If they are not, then there is a bug
        // somewhere and we should let the C compiler tell us about it.
        const ctype = try dg.ctypeFromType(ptr_ty, .complete);
        const elem_ctype = ctype.info(ctype_pool).pointer.elem_ctype;
        const nav_ctype = try dg.ctypeFromType(nav_ty, .complete);
        const need_cast = !elem_ctype.eql(nav_ctype) and
            (elem_ctype.info(ctype_pool) != .function or nav_ctype.info(ctype_pool) != .function);
        if (need_cast) {
            try writer.writeAll("((");
            try dg.renderCType(writer, ctype);
            try writer.writeByte(')');
        }
        try writer.writeByte('&');
        try dg.renderNavName(writer, owner_nav);
        if (need_cast) try writer.writeByte(')');
    }

    fn renderPointer(
        dg: *DeclGen,
        writer: anytype,
        derivation: Value.PointerDeriveStep,
        location: ValueRenderLocation,
    ) error{ OutOfMemory, AnalysisFail }!void {
        const pt = dg.pt;
        const zcu = pt.zcu;
        switch (derivation) {
            .comptime_alloc_ptr, .comptime_field_ptr => unreachable,
            .int => |int| {
                const ptr_ctype = try dg.ctypeFromType(int.ptr_ty, .complete);
                const addr_val = try pt.intValue(Type.usize, int.addr);
                try writer.writeByte('(');
                try dg.renderCType(writer, ptr_ctype);
                try writer.print("){x}", .{try dg.fmtIntLiteral(addr_val, .Other)});
            },

            .nav_ptr => |nav| try dg.renderNav(writer, nav, location),
            .uav_ptr => |uav| try dg.renderUav(writer, uav, location),

            inline .eu_payload_ptr, .opt_payload_ptr => |info| {
                try writer.writeAll("&(");
                try dg.renderPointer(writer, info.parent.*, location);
                try writer.writeAll(")->payload");
            },

            .field_ptr => |field| {
                const parent_ptr_ty = try field.parent.ptrType(pt);

                // Ensure complete type definition is available before accessing fields.
                _ = try dg.ctypeFromType(parent_ptr_ty.childType(zcu), .complete);

                switch (fieldLocation(parent_ptr_ty, field.result_ptr_ty, field.field_idx, pt)) {
                    .begin => {
                        const ptr_ctype = try dg.ctypeFromType(field.result_ptr_ty, .complete);
                        try writer.writeByte('(');
                        try dg.renderCType(writer, ptr_ctype);
                        try writer.writeByte(')');
                        try dg.renderPointer(writer, field.parent.*, location);
                    },
                    .field => |name| {
                        try writer.writeAll("&(");
                        try dg.renderPointer(writer, field.parent.*, location);
                        try writer.writeAll(")->");
                        try dg.writeCValue(writer, name);
                    },
                    .byte_offset => |byte_offset| {
                        const ptr_ctype = try dg.ctypeFromType(field.result_ptr_ty, .complete);
                        try writer.writeByte('(');
                        try dg.renderCType(writer, ptr_ctype);
                        try writer.writeByte(')');
                        const offset_val = try pt.intValue(Type.usize, byte_offset);
                        try writer.writeAll("((char *)");
                        try dg.renderPointer(writer, field.parent.*, location);
                        try writer.print(" + {})", .{try dg.fmtIntLiteral(offset_val, .Other)});
                    },
                }
            },

            .elem_ptr => |elem| if (!(try elem.parent.ptrType(pt)).childType(zcu).hasRuntimeBits(zcu)) {
                // Element type is zero-bit, so lowers to `void`. The index is irrelevant; just cast the pointer.
                const ptr_ctype = try dg.ctypeFromType(elem.result_ptr_ty, .complete);
                try writer.writeByte('(');
                try dg.renderCType(writer, ptr_ctype);
                try writer.writeByte(')');
                try dg.renderPointer(writer, elem.parent.*, location);
            } else {
                const index_val = try pt.intValue(Type.usize, elem.elem_idx);
                // We want to do pointer arithmetic on a pointer to the element type.
                // We might have a pointer-to-array. In this case, we must cast first.
                const result_ctype = try dg.ctypeFromType(elem.result_ptr_ty, .complete);
                const parent_ctype = try dg.ctypeFromType(try elem.parent.ptrType(pt), .complete);
                if (result_ctype.eql(parent_ctype)) {
                    // The pointer already has an appropriate type - just do the arithmetic.
                    try writer.writeByte('(');
                    try dg.renderPointer(writer, elem.parent.*, location);
                    try writer.print(" + {})", .{try dg.fmtIntLiteral(index_val, .Other)});
                } else {
                    // We probably have an array pointer `T (*)[n]`. Cast to an element pointer,
                    // and *then* apply the index.
                    try writer.writeAll("((");
                    try dg.renderCType(writer, result_ctype);
                    try writer.writeByte(')');
                    try dg.renderPointer(writer, elem.parent.*, location);
                    try writer.print(" + {})", .{try dg.fmtIntLiteral(index_val, .Other)});
                }
            },

            .offset_and_cast => |oac| {
                const ptr_ctype = try dg.ctypeFromType(oac.new_ptr_ty, .complete);
                try writer.writeByte('(');
                try dg.renderCType(writer, ptr_ctype);
                try writer.writeByte(')');
                if (oac.byte_offset == 0) {
                    try dg.renderPointer(writer, oac.parent.*, location);
                } else {
                    const offset_val = try pt.intValue(Type.usize, oac.byte_offset);
                    try writer.writeAll("((char *)");
                    try dg.renderPointer(writer, oac.parent.*, location);
                    try writer.print(" + {})", .{try dg.fmtIntLiteral(offset_val, .Other)});
                }
            },
        }
    }

    fn renderErrorName(dg: *DeclGen, writer: anytype, err_name: InternPool.NullTerminatedString) !void {
        const ip = &dg.pt.zcu.intern_pool;
        try writer.print("zig_error_{}", .{fmtIdent(err_name.toSlice(ip))});
    }

    fn renderValue(
        dg: *DeclGen,
        writer: anytype,
        val: Value,
        location: ValueRenderLocation,
    ) error{ OutOfMemory, AnalysisFail }!void {
        const pt = dg.pt;
        const zcu = pt.zcu;
        const ip = &zcu.intern_pool;
        const target = &dg.mod.resolved_target.result;
        const ctype_pool = &dg.ctype_pool;

        const initializer_type: ValueRenderLocation = switch (location) {
            .StaticInitializer => .StaticInitializer,
            else => .Initializer,
        };

        const ty = val.typeOf(zcu);
        if (val.isUndefDeep(zcu)) return dg.renderUndefValue(writer, ty, location);
        const ctype = try dg.ctypeFromType(ty, location.toCTypeKind());
        switch (ip.indexToKey(val.toIntern())) {
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
            .@"extern",
            .func,
            .enum_literal,
            .empty_enum_value,
            => unreachable, // non-runtime values
            .int => |int| switch (int.storage) {
                .u64, .i64, .big_int => try writer.print("{}", .{try dg.fmtIntLiteral(val, location)}),
                .lazy_align, .lazy_size => {
                    try writer.writeAll("((");
                    try dg.renderCType(writer, ctype);
                    try writer.print("){x})", .{try dg.fmtIntLiteral(
                        try pt.intValue(Type.usize, val.toUnsignedInt(zcu)),
                        .Other,
                    )});
                },
            },
            .err => |err| try dg.renderErrorName(writer, err.name),
            .error_union => |error_union| switch (ctype.info(ctype_pool)) {
                .basic => switch (error_union.val) {
                    .err_name => |err_name| try dg.renderErrorName(writer, err_name),
                    .payload => try writer.writeAll("0"),
                },
                .pointer, .aligned, .array, .vector, .fwd_decl, .function => unreachable,
                .aggregate => |aggregate| {
                    if (!location.isInitializer()) {
                        try writer.writeByte('(');
                        try dg.renderCType(writer, ctype);
                        try writer.writeByte(')');
                    }
                    try writer.writeByte('{');
                    for (0..aggregate.fields.len) |field_index| {
                        if (field_index > 0) try writer.writeByte(',');
                        switch (aggregate.fields.at(field_index, ctype_pool).name.index) {
                            .@"error" => switch (error_union.val) {
                                .err_name => |err_name| try dg.renderErrorName(writer, err_name),
                                .payload => try writer.writeByte('0'),
                            },
                            .payload => switch (error_union.val) {
                                .err_name => try dg.renderUndefValue(
                                    writer,
                                    ty.errorUnionPayload(zcu),
                                    initializer_type,
                                ),
                                .payload => |payload| try dg.renderValue(
                                    writer,
                                    Value.fromInterned(payload),
                                    initializer_type,
                                ),
                            },
                            else => unreachable,
                        }
                    }
                    try writer.writeByte('}');
                },
            },
            .enum_tag => |enum_tag| try dg.renderValue(writer, Value.fromInterned(enum_tag.int), location),
            .float => {
                const bits = ty.floatBits(target.*);
                const f128_val = val.toFloat(f128, zcu);

                // All unsigned ints matching float types are pre-allocated.
                const repr_ty = pt.intType(.unsigned, bits) catch unreachable;

                assert(bits <= 128);
                var repr_val_limbs: [BigInt.calcTwosCompLimbCount(128)]BigIntLimb = undefined;
                var repr_val_big = BigInt.Mutable{
                    .limbs = &repr_val_limbs,
                    .len = undefined,
                    .positive = undefined,
                };

                switch (bits) {
                    16 => repr_val_big.set(@as(u16, @bitCast(val.toFloat(f16, zcu)))),
                    32 => repr_val_big.set(@as(u32, @bitCast(val.toFloat(f32, zcu)))),
                    64 => repr_val_big.set(@as(u64, @bitCast(val.toFloat(f64, zcu)))),
                    80 => repr_val_big.set(@as(u80, @bitCast(val.toFloat(f80, zcu)))),
                    128 => repr_val_big.set(@as(u128, @bitCast(f128_val))),
                    else => unreachable,
                }

                var empty = true;
                if (std.math.isFinite(f128_val)) {
                    try writer.writeAll("zig_make_");
                    try dg.renderTypeForBuiltinFnName(writer, ty);
                    try writer.writeByte('(');
                    switch (bits) {
                        16 => try writer.print("{x}", .{val.toFloat(f16, zcu)}),
                        32 => try writer.print("{x}", .{val.toFloat(f32, zcu)}),
                        64 => try writer.print("{x}", .{val.toFloat(f64, zcu)}),
                        80 => try writer.print("{x}", .{val.toFloat(f80, zcu)}),
                        128 => try writer.print("{x}", .{f128_val}),
                        else => unreachable,
                    }
                    try writer.writeAll(", ");
                    empty = false;
                } else {
                    // isSignalNan is equivalent to isNan currently, and MSVC doesn't have nans, so prefer nan
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
                        16 => try writer.print("\"0x{x}\"", .{@as(u16, @bitCast(val.toFloat(f16, zcu)))}),
                        32 => try writer.print("\"0x{x}\"", .{@as(u32, @bitCast(val.toFloat(f32, zcu)))}),
                        64 => try writer.print("\"0x{x}\"", .{@as(u64, @bitCast(val.toFloat(f64, zcu)))}),
                        80 => try writer.print("\"0x{x}\"", .{@as(u80, @bitCast(val.toFloat(f80, zcu)))}),
                        128 => try writer.print("\"0x{x}\"", .{@as(u128, @bitCast(f128_val))}),
                        else => unreachable,
                    };
                    try writer.writeAll(", ");
                    empty = false;
                }
                try writer.print("{x}", .{try dg.fmtIntLiteral(
                    try pt.intValue_big(repr_ty, repr_val_big.toConst()),
                    location,
                )});
                if (!empty) try writer.writeByte(')');
            },
            .slice => |slice| {
                const aggregate = ctype.info(ctype_pool).aggregate;
                if (!location.isInitializer()) {
                    try writer.writeByte('(');
                    try dg.renderCType(writer, ctype);
                    try writer.writeByte(')');
                }
                try writer.writeByte('{');
                for (0..aggregate.fields.len) |field_index| {
                    if (field_index > 0) try writer.writeByte(',');
                    try dg.renderValue(writer, Value.fromInterned(
                        switch (aggregate.fields.at(field_index, ctype_pool).name.index) {
                            .ptr => slice.ptr,
                            .len => slice.len,
                            else => unreachable,
                        },
                    ), initializer_type);
                }
                try writer.writeByte('}');
            },
            .ptr => {
                var arena = std.heap.ArenaAllocator.init(zcu.gpa);
                defer arena.deinit();
                const derivation = try val.pointerDerivation(arena.allocator(), pt);
                try dg.renderPointer(writer, derivation, location);
            },
            .opt => |opt| switch (ctype.info(ctype_pool)) {
                .basic => if (ctype.isBool()) try writer.writeAll(switch (opt.val) {
                    .none => "true",
                    else => "false",
                }) else switch (opt.val) {
                    .none => try writer.writeAll("0"),
                    else => |payload| switch (ip.indexToKey(payload)) {
                        .undef => |err_ty| try dg.renderUndefValue(
                            writer,
                            Type.fromInterned(err_ty),
                            location,
                        ),
                        .err => |err| try dg.renderErrorName(writer, err.name),
                        else => unreachable,
                    },
                },
                .pointer => switch (opt.val) {
                    .none => try writer.writeAll("NULL"),
                    else => |payload| try dg.renderValue(writer, Value.fromInterned(payload), location),
                },
                .aligned, .array, .vector, .fwd_decl, .function => unreachable,
                .aggregate => |aggregate| {
                    switch (opt.val) {
                        .none => {},
                        else => |payload| switch (aggregate.fields.at(0, ctype_pool).name.index) {
                            .is_null, .payload => {},
                            .ptr, .len => return dg.renderValue(
                                writer,
                                Value.fromInterned(payload),
                                location,
                            ),
                            else => unreachable,
                        },
                    }
                    if (!location.isInitializer()) {
                        try writer.writeByte('(');
                        try dg.renderCType(writer, ctype);
                        try writer.writeByte(')');
                    }
                    try writer.writeByte('{');
                    for (0..aggregate.fields.len) |field_index| {
                        if (field_index > 0) try writer.writeByte(',');
                        switch (aggregate.fields.at(field_index, ctype_pool).name.index) {
                            .is_null => try writer.writeAll(switch (opt.val) {
                                .none => "true",
                                else => "false",
                            }),
                            .payload => switch (opt.val) {
                                .none => try dg.renderUndefValue(
                                    writer,
                                    ty.optionalChild(zcu),
                                    initializer_type,
                                ),
                                else => |payload| try dg.renderValue(
                                    writer,
                                    Value.fromInterned(payload),
                                    initializer_type,
                                ),
                            },
                            .ptr => try writer.writeAll("NULL"),
                            .len => try dg.renderUndefValue(writer, Type.usize, initializer_type),
                            else => unreachable,
                        }
                    }
                    try writer.writeByte('}');
                },
            },
            .aggregate => switch (ip.indexToKey(ty.toIntern())) {
                .array_type, .vector_type => {
                    if (location == .FunctionArgument) {
                        try writer.writeByte('(');
                        try dg.renderCType(writer, ctype);
                        try writer.writeByte(')');
                    }
                    const ai = ty.arrayInfo(zcu);
                    if (ai.elem_type.eql(Type.u8, zcu)) {
                        var literal = stringLiteral(writer, ty.arrayLenIncludingSentinel(zcu));
                        try literal.start();
                        var index: usize = 0;
                        while (index < ai.len) : (index += 1) {
                            const elem_val = try val.elemValue(pt, index);
                            const elem_val_u8: u8 = if (elem_val.isUndef(zcu))
                                undefPattern(u8)
                            else
                                @intCast(elem_val.toUnsignedInt(zcu));
                            try literal.writeChar(elem_val_u8);
                        }
                        if (ai.sentinel) |s| {
                            const s_u8: u8 = @intCast(s.toUnsignedInt(zcu));
                            if (s_u8 != 0) try literal.writeChar(s_u8);
                        }
                        try literal.end();
                    } else {
                        try writer.writeByte('{');
                        var index: usize = 0;
                        while (index < ai.len) : (index += 1) {
                            if (index != 0) try writer.writeByte(',');
                            const elem_val = try val.elemValue(pt, index);
                            try dg.renderValue(writer, elem_val, initializer_type);
                        }
                        if (ai.sentinel) |s| {
                            if (index != 0) try writer.writeByte(',');
                            try dg.renderValue(writer, s, initializer_type);
                        }
                        try writer.writeByte('}');
                    }
                },
                .anon_struct_type => |tuple| {
                    if (!location.isInitializer()) {
                        try writer.writeByte('(');
                        try dg.renderCType(writer, ctype);
                        try writer.writeByte(')');
                    }

                    try writer.writeByte('{');
                    var empty = true;
                    for (0..tuple.types.len) |field_index| {
                        const comptime_val = tuple.values.get(ip)[field_index];
                        if (comptime_val != .none) continue;
                        const field_ty = Type.fromInterned(tuple.types.get(ip)[field_index]);
                        if (!field_ty.hasRuntimeBitsIgnoreComptime(zcu)) continue;

                        if (!empty) try writer.writeByte(',');

                        const field_val = Value.fromInterned(
                            switch (ip.indexToKey(val.toIntern()).aggregate.storage) {
                                .bytes => |bytes| try pt.intern(.{ .int = .{
                                    .ty = field_ty.toIntern(),
                                    .storage = .{ .u64 = bytes.at(field_index, ip) },
                                } }),
                                .elems => |elems| elems[field_index],
                                .repeated_elem => |elem| elem,
                            },
                        );
                        try dg.renderValue(writer, field_val, initializer_type);

                        empty = false;
                    }
                    try writer.writeByte('}');
                },
                .struct_type => {
                    const loaded_struct = ip.loadStructType(ty.toIntern());
                    switch (loaded_struct.layout) {
                        .auto, .@"extern" => {
                            if (!location.isInitializer()) {
                                try writer.writeByte('(');
                                try dg.renderCType(writer, ctype);
                                try writer.writeByte(')');
                            }

                            try writer.writeByte('{');
                            var field_it = loaded_struct.iterateRuntimeOrder(ip);
                            var need_comma = false;
                            while (field_it.next()) |field_index| {
                                const field_ty = Type.fromInterned(loaded_struct.field_types.get(ip)[field_index]);
                                if (!field_ty.hasRuntimeBitsIgnoreComptime(zcu)) continue;

                                if (need_comma) try writer.writeByte(',');
                                need_comma = true;
                                const field_val = switch (ip.indexToKey(val.toIntern()).aggregate.storage) {
                                    .bytes => |bytes| try pt.intern(.{ .int = .{
                                        .ty = field_ty.toIntern(),
                                        .storage = .{ .u64 = bytes.at(field_index, ip) },
                                    } }),
                                    .elems => |elems| elems[field_index],
                                    .repeated_elem => |elem| elem,
                                };
                                try dg.renderValue(writer, Value.fromInterned(field_val), initializer_type);
                            }
                            try writer.writeByte('}');
                        },
                        .@"packed" => {
                            const int_info = ty.intInfo(zcu);

                            const bits = Type.smallestUnsignedBits(int_info.bits - 1);
                            const bit_offset_ty = try pt.intType(.unsigned, bits);

                            var bit_offset: u64 = 0;
                            var eff_num_fields: usize = 0;

                            for (0..loaded_struct.field_types.len) |field_index| {
                                const field_ty = Type.fromInterned(loaded_struct.field_types.get(ip)[field_index]);
                                if (!field_ty.hasRuntimeBitsIgnoreComptime(zcu)) continue;
                                eff_num_fields += 1;
                            }

                            if (eff_num_fields == 0) {
                                try writer.writeByte('(');
                                try dg.renderUndefValue(writer, ty, location);
                                try writer.writeByte(')');
                            } else if (ty.bitSize(zcu) > 64) {
                                // zig_or_u128(zig_or_u128(zig_shl_u128(a, a_off), zig_shl_u128(b, b_off)), zig_shl_u128(c, c_off))
                                var num_or = eff_num_fields - 1;
                                while (num_or > 0) : (num_or -= 1) {
                                    try writer.writeAll("zig_or_");
                                    try dg.renderTypeForBuiltinFnName(writer, ty);
                                    try writer.writeByte('(');
                                }

                                var eff_index: usize = 0;
                                var needs_closing_paren = false;
                                for (0..loaded_struct.field_types.len) |field_index| {
                                    const field_ty = Type.fromInterned(loaded_struct.field_types.get(ip)[field_index]);
                                    if (!field_ty.hasRuntimeBitsIgnoreComptime(zcu)) continue;

                                    const field_val = switch (ip.indexToKey(val.toIntern()).aggregate.storage) {
                                        .bytes => |bytes| try pt.intern(.{ .int = .{
                                            .ty = field_ty.toIntern(),
                                            .storage = .{ .u64 = bytes.at(field_index, ip) },
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
                                        try dg.renderValue(writer, try pt.intValue(bit_offset_ty, bit_offset), .FunctionArgument);
                                        try writer.writeByte(')');
                                    } else {
                                        try dg.renderIntCast(writer, ty, cast_context, field_ty, .FunctionArgument);
                                    }

                                    if (needs_closing_paren) try writer.writeByte(')');
                                    if (eff_index != eff_num_fields - 1) try writer.writeAll(", ");

                                    bit_offset += field_ty.bitSize(zcu);
                                    needs_closing_paren = true;
                                    eff_index += 1;
                                }
                            } else {
                                try writer.writeByte('(');
                                // a << a_off | b << b_off | c << c_off
                                var empty = true;
                                for (0..loaded_struct.field_types.len) |field_index| {
                                    const field_ty = Type.fromInterned(loaded_struct.field_types.get(ip)[field_index]);
                                    if (!field_ty.hasRuntimeBitsIgnoreComptime(zcu)) continue;

                                    if (!empty) try writer.writeAll(" | ");
                                    try writer.writeByte('(');
                                    try dg.renderCType(writer, ctype);
                                    try writer.writeByte(')');

                                    const field_val = switch (ip.indexToKey(val.toIntern()).aggregate.storage) {
                                        .bytes => |bytes| try pt.intern(.{ .int = .{
                                            .ty = field_ty.toIntern(),
                                            .storage = .{ .u64 = bytes.at(field_index, ip) },
                                        } }),
                                        .elems => |elems| elems[field_index],
                                        .repeated_elem => |elem| elem,
                                    };

                                    if (bit_offset != 0) {
                                        try dg.renderValue(writer, Value.fromInterned(field_val), .Other);
                                        try writer.writeAll(" << ");
                                        try dg.renderValue(writer, try pt.intValue(bit_offset_ty, bit_offset), .FunctionArgument);
                                    } else {
                                        try dg.renderValue(writer, Value.fromInterned(field_val), .Other);
                                    }

                                    bit_offset += field_ty.bitSize(zcu);
                                    empty = false;
                                }
                                try writer.writeByte(')');
                            }
                        },
                    }
                },
                else => unreachable,
            },
            .un => |un| {
                const loaded_union = ip.loadUnionType(ty.toIntern());
                if (un.tag == .none) {
                    const backing_ty = try ty.unionBackingType(pt);
                    switch (loaded_union.flagsUnordered(ip).layout) {
                        .@"packed" => {
                            if (!location.isInitializer()) {
                                try writer.writeByte('(');
                                try dg.renderType(writer, backing_ty);
                                try writer.writeByte(')');
                            }
                            try dg.renderValue(writer, Value.fromInterned(un.val), location);
                        },
                        .@"extern" => {
                            if (location == .StaticInitializer) {
                                return dg.fail("TODO: C backend: implement extern union backing type rendering in static initializers", .{});
                            }

                            const ptr_ty = try pt.singleConstPtrType(ty);
                            try writer.writeAll("*((");
                            try dg.renderType(writer, ptr_ty);
                            try writer.writeAll(")(");
                            try dg.renderType(writer, backing_ty);
                            try writer.writeAll("){");
                            try dg.renderValue(writer, Value.fromInterned(un.val), location);
                            try writer.writeAll("})");
                        },
                        else => unreachable,
                    }
                } else {
                    if (!location.isInitializer()) {
                        try writer.writeByte('(');
                        try dg.renderCType(writer, ctype);
                        try writer.writeByte(')');
                    }

                    const field_index = zcu.unionTagFieldIndex(loaded_union, Value.fromInterned(un.tag)).?;
                    const field_ty = Type.fromInterned(loaded_union.field_types.get(ip)[field_index]);
                    const field_name = loaded_union.loadTagType(ip).names.get(ip)[field_index];
                    if (loaded_union.flagsUnordered(ip).layout == .@"packed") {
                        if (field_ty.hasRuntimeBits(zcu)) {
                            if (field_ty.isPtrAtRuntime(zcu)) {
                                try writer.writeByte('(');
                                try dg.renderCType(writer, ctype);
                                try writer.writeByte(')');
                            } else if (field_ty.zigTypeTag(zcu) == .float) {
                                try writer.writeByte('(');
                                try dg.renderCType(writer, ctype);
                                try writer.writeByte(')');
                            }
                            try dg.renderValue(writer, Value.fromInterned(un.val), location);
                        } else try writer.writeAll("0");
                        return;
                    }

                    const has_tag = loaded_union.hasTag(ip);
                    if (has_tag) try writer.writeByte('{');
                    const aggregate = ctype.info(ctype_pool).aggregate;
                    for (0..if (has_tag) aggregate.fields.len else 1) |outer_field_index| {
                        if (outer_field_index > 0) try writer.writeByte(',');
                        switch (if (has_tag)
                            aggregate.fields.at(outer_field_index, ctype_pool).name.index
                        else
                            .payload) {
                            .tag => try dg.renderValue(
                                writer,
                                Value.fromInterned(un.tag),
                                initializer_type,
                            ),
                            .payload => {
                                try writer.writeByte('{');
                                if (field_ty.hasRuntimeBits(zcu)) {
                                    try writer.print(" .{ } = ", .{fmtIdent(field_name.toSlice(ip))});
                                    try dg.renderValue(
                                        writer,
                                        Value.fromInterned(un.val),
                                        initializer_type,
                                    );
                                    try writer.writeByte(' ');
                                } else for (0..loaded_union.field_types.len) |inner_field_index| {
                                    const inner_field_ty = Type.fromInterned(
                                        loaded_union.field_types.get(ip)[inner_field_index],
                                    );
                                    if (!inner_field_ty.hasRuntimeBits(zcu)) continue;
                                    try dg.renderUndefValue(writer, inner_field_ty, initializer_type);
                                    break;
                                }
                                try writer.writeByte('}');
                            },
                            else => unreachable,
                        }
                    }
                    if (has_tag) try writer.writeByte('}');
                }
            },
        }
    }

    fn renderUndefValue(
        dg: *DeclGen,
        writer: anytype,
        ty: Type,
        location: ValueRenderLocation,
    ) error{ OutOfMemory, AnalysisFail }!void {
        const pt = dg.pt;
        const zcu = pt.zcu;
        const ip = &zcu.intern_pool;
        const target = &dg.mod.resolved_target.result;
        const ctype_pool = &dg.ctype_pool;

        const initializer_type: ValueRenderLocation = switch (location) {
            .StaticInitializer => .StaticInitializer,
            else => .Initializer,
        };

        const safety_on = switch (zcu.optimizeMode()) {
            .Debug, .ReleaseSafe => true,
            .ReleaseFast, .ReleaseSmall => false,
        };

        const ctype = try dg.ctypeFromType(ty, location.toCTypeKind());
        switch (ty.toIntern()) {
            .c_longdouble_type,
            .f16_type,
            .f32_type,
            .f64_type,
            .f80_type,
            .f128_type,
            => {
                const bits = ty.floatBits(target.*);
                // All unsigned ints matching float types are pre-allocated.
                const repr_ty = dg.pt.intType(.unsigned, bits) catch unreachable;

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
                try dg.renderUndefValue(writer, repr_ty, .FunctionArgument);
                return writer.writeByte(')');
            },
            .bool_type => try writer.writeAll(if (safety_on) "0xaa" else "false"),
            else => switch (ip.indexToKey(ty.toIntern())) {
                .simple_type,
                .int_type,
                .enum_type,
                .error_set_type,
                .inferred_error_set_type,
                => return writer.print("{x}", .{
                    try dg.fmtIntLiteral(try pt.undefValue(ty), location),
                }),
                .ptr_type => |ptr_type| switch (ptr_type.flags.size) {
                    .One, .Many, .C => {
                        try writer.writeAll("((");
                        try dg.renderCType(writer, ctype);
                        return writer.print("){x})", .{
                            try dg.fmtIntLiteral(try pt.undefValue(Type.usize), .Other),
                        });
                    },
                    .Slice => {
                        if (!location.isInitializer()) {
                            try writer.writeByte('(');
                            try dg.renderCType(writer, ctype);
                            try writer.writeByte(')');
                        }

                        try writer.writeAll("{(");
                        const ptr_ty = ty.slicePtrFieldType(zcu);
                        try dg.renderType(writer, ptr_ty);
                        return writer.print("){x}, {0x}}}", .{
                            try dg.fmtIntLiteral(try dg.pt.undefValue(Type.usize), .Other),
                        });
                    },
                },
                .opt_type => |child_type| switch (ctype.info(ctype_pool)) {
                    .basic, .pointer => try dg.renderUndefValue(
                        writer,
                        Type.fromInterned(if (ctype.isBool()) .bool_type else child_type),
                        location,
                    ),
                    .aligned, .array, .vector, .fwd_decl, .function => unreachable,
                    .aggregate => |aggregate| {
                        switch (aggregate.fields.at(0, ctype_pool).name.index) {
                            .is_null, .payload => {},
                            .ptr, .len => return dg.renderUndefValue(
                                writer,
                                Type.fromInterned(child_type),
                                location,
                            ),
                            else => unreachable,
                        }
                        if (!location.isInitializer()) {
                            try writer.writeByte('(');
                            try dg.renderCType(writer, ctype);
                            try writer.writeByte(')');
                        }
                        try writer.writeByte('{');
                        for (0..aggregate.fields.len) |field_index| {
                            if (field_index > 0) try writer.writeByte(',');
                            try dg.renderUndefValue(writer, Type.fromInterned(
                                switch (aggregate.fields.at(field_index, ctype_pool).name.index) {
                                    .is_null => .bool_type,
                                    .payload => child_type,
                                    else => unreachable,
                                },
                            ), initializer_type);
                        }
                        try writer.writeByte('}');
                    },
                },
                .struct_type => {
                    const loaded_struct = ip.loadStructType(ty.toIntern());
                    switch (loaded_struct.layout) {
                        .auto, .@"extern" => {
                            if (!location.isInitializer()) {
                                try writer.writeByte('(');
                                try dg.renderCType(writer, ctype);
                                try writer.writeByte(')');
                            }

                            try writer.writeByte('{');
                            var field_it = loaded_struct.iterateRuntimeOrder(ip);
                            var need_comma = false;
                            while (field_it.next()) |field_index| {
                                const field_ty = Type.fromInterned(loaded_struct.field_types.get(ip)[field_index]);
                                if (!field_ty.hasRuntimeBitsIgnoreComptime(zcu)) continue;

                                if (need_comma) try writer.writeByte(',');
                                need_comma = true;
                                try dg.renderUndefValue(writer, field_ty, initializer_type);
                            }
                            return writer.writeByte('}');
                        },
                        .@"packed" => return writer.print("{x}", .{
                            try dg.fmtIntLiteral(try pt.undefValue(ty), .Other),
                        }),
                    }
                },
                .anon_struct_type => |anon_struct_info| {
                    if (!location.isInitializer()) {
                        try writer.writeByte('(');
                        try dg.renderCType(writer, ctype);
                        try writer.writeByte(')');
                    }

                    try writer.writeByte('{');
                    var need_comma = false;
                    for (0..anon_struct_info.types.len) |field_index| {
                        if (anon_struct_info.values.get(ip)[field_index] != .none) continue;
                        const field_ty = Type.fromInterned(anon_struct_info.types.get(ip)[field_index]);
                        if (!field_ty.hasRuntimeBitsIgnoreComptime(zcu)) continue;

                        if (need_comma) try writer.writeByte(',');
                        need_comma = true;
                        try dg.renderUndefValue(writer, field_ty, initializer_type);
                    }
                    return writer.writeByte('}');
                },
                .union_type => {
                    const loaded_union = ip.loadUnionType(ty.toIntern());
                    switch (loaded_union.flagsUnordered(ip).layout) {
                        .auto, .@"extern" => {
                            if (!location.isInitializer()) {
                                try writer.writeByte('(');
                                try dg.renderCType(writer, ctype);
                                try writer.writeByte(')');
                            }

                            const has_tag = loaded_union.hasTag(ip);
                            if (has_tag) try writer.writeByte('{');
                            const aggregate = ctype.info(ctype_pool).aggregate;
                            for (0..if (has_tag) aggregate.fields.len else 1) |outer_field_index| {
                                if (outer_field_index > 0) try writer.writeByte(',');
                                switch (if (has_tag)
                                    aggregate.fields.at(outer_field_index, ctype_pool).name.index
                                else
                                    .payload) {
                                    .tag => try dg.renderUndefValue(
                                        writer,
                                        Type.fromInterned(loaded_union.enum_tag_ty),
                                        initializer_type,
                                    ),
                                    .payload => {
                                        try writer.writeByte('{');
                                        for (0..loaded_union.field_types.len) |inner_field_index| {
                                            const inner_field_ty = Type.fromInterned(
                                                loaded_union.field_types.get(ip)[inner_field_index],
                                            );
                                            if (!inner_field_ty.hasRuntimeBits(pt.zcu)) continue;
                                            try dg.renderUndefValue(
                                                writer,
                                                inner_field_ty,
                                                initializer_type,
                                            );
                                            break;
                                        }
                                        try writer.writeByte('}');
                                    },
                                    else => unreachable,
                                }
                            }
                            if (has_tag) try writer.writeByte('}');
                        },
                        .@"packed" => return writer.print("{x}", .{
                            try dg.fmtIntLiteral(try pt.undefValue(ty), .Other),
                        }),
                    }
                },
                .error_union_type => |error_union_type| switch (ctype.info(ctype_pool)) {
                    .basic => try dg.renderUndefValue(
                        writer,
                        Type.fromInterned(error_union_type.error_set_type),
                        location,
                    ),
                    .pointer, .aligned, .array, .vector, .fwd_decl, .function => unreachable,
                    .aggregate => |aggregate| {
                        if (!location.isInitializer()) {
                            try writer.writeByte('(');
                            try dg.renderCType(writer, ctype);
                            try writer.writeByte(')');
                        }
                        try writer.writeByte('{');
                        for (0..aggregate.fields.len) |field_index| {
                            if (field_index > 0) try writer.writeByte(',');
                            try dg.renderUndefValue(
                                writer,
                                Type.fromInterned(
                                    switch (aggregate.fields.at(field_index, ctype_pool).name.index) {
                                        .@"error" => error_union_type.error_set_type,
                                        .payload => error_union_type.payload_type,
                                        else => unreachable,
                                    },
                                ),
                                initializer_type,
                            );
                        }
                        try writer.writeByte('}');
                    },
                },
                .array_type, .vector_type => {
                    const ai = ty.arrayInfo(zcu);
                    if (ai.elem_type.eql(Type.u8, zcu)) {
                        const c_len = ty.arrayLenIncludingSentinel(zcu);
                        var literal = stringLiteral(writer, c_len);
                        try literal.start();
                        var index: u64 = 0;
                        while (index < c_len) : (index += 1)
                            try literal.writeChar(0xaa);
                        return literal.end();
                    } else {
                        if (!location.isInitializer()) {
                            try writer.writeByte('(');
                            try dg.renderCType(writer, ctype);
                            try writer.writeByte(')');
                        }

                        try writer.writeByte('{');
                        const c_len = ty.arrayLenIncludingSentinel(zcu);
                        var index: u64 = 0;
                        while (index < c_len) : (index += 1) {
                            if (index > 0) try writer.writeAll(", ");
                            try dg.renderUndefValue(writer, ty.childType(zcu), initializer_type);
                        }
                        return writer.writeByte('}');
                    }
                },
                .anyframe_type,
                .opaque_type,
                .func_type,
                => unreachable,

                .undef,
                .simple_value,
                .variable,
                .@"extern",
                .func,
                .int,
                .err,
                .error_union,
                .enum_literal,
                .enum_tag,
                .empty_enum_value,
                .float,
                .ptr,
                .slice,
                .opt,
                .aggregate,
                .un,
                .memoized_call,
                => unreachable, // values, not types
            },
        }
    }

    fn renderFunctionSignature(
        dg: *DeclGen,
        w: anytype,
        fn_val: Value,
        fn_align: InternPool.Alignment,
        kind: CType.Kind,
        name: union(enum) {
            nav: InternPool.Nav.Index,
            fmt_ctype_pool_string: std.fmt.Formatter(formatCTypePoolString),
            @"export": struct {
                main_name: InternPool.NullTerminatedString,
                extern_name: InternPool.NullTerminatedString,
            },
        },
    ) !void {
        const zcu = dg.pt.zcu;
        const ip = &zcu.intern_pool;

        const fn_ty = fn_val.typeOf(zcu);
        const fn_ctype = try dg.ctypeFromType(fn_ty, kind);

        const fn_info = zcu.typeToFunc(fn_ty).?;
        if (fn_info.cc == .Naked) {
            switch (kind) {
                .forward => try w.writeAll("zig_naked_decl "),
                .complete => try w.writeAll("zig_naked "),
                else => unreachable,
            }
        }
        if (fn_val.getFunction(zcu)) |func| if (func.analysisUnordered(ip).branch_hint == .cold)
            try w.writeAll("zig_cold ");
        if (fn_info.return_type == .noreturn_type) try w.writeAll("zig_noreturn ");

        var trailing = try renderTypePrefix(dg.pass, &dg.ctype_pool, zcu, w, fn_ctype, .suffix, .{});

        if (toCallingConvention(fn_info.cc)) |call_conv| {
            try w.print("{}zig_callconv({s})", .{ trailing, call_conv });
            trailing = .maybe_space;
        }

        try w.print("{}", .{trailing});
        switch (name) {
            .nav => |nav| try dg.renderNavName(w, nav),
            .fmt_ctype_pool_string => |fmt| try w.print("{ }", .{fmt}),
            .@"export" => |@"export"| try w.print("{ }", .{fmtIdent(@"export".extern_name.toSlice(ip))}),
        }

        try renderTypeSuffix(
            dg.pass,
            &dg.ctype_pool,
            zcu,
            w,
            fn_ctype,
            .suffix,
            CQualifiers.init(.{ .@"const" = switch (kind) {
                .forward => false,
                .complete => true,
                else => unreachable,
            } }),
        );

        switch (kind) {
            .forward => {
                if (fn_align.toByteUnits()) |a| try w.print(" zig_align_fn({})", .{a});
                switch (name) {
                    .nav, .fmt_ctype_pool_string => {},
                    .@"export" => |@"export"| {
                        const extern_name = @"export".extern_name.toSlice(ip);
                        const is_mangled = isMangledIdent(extern_name, true);
                        const is_export = @"export".extern_name != @"export".main_name;
                        if (is_mangled and is_export) {
                            try w.print(" zig_mangled_export({ }, {s}, {s})", .{
                                fmtIdent(extern_name),
                                fmtStringLiteral(extern_name, null),
                                fmtStringLiteral(@"export".main_name.toSlice(ip), null),
                            });
                        } else if (is_mangled) {
                            try w.print(" zig_mangled({ }, {s})", .{
                                fmtIdent(extern_name), fmtStringLiteral(extern_name, null),
                            });
                        } else if (is_export) {
                            try w.print(" zig_export({s}, {s})", .{
                                fmtStringLiteral(@"export".main_name.toSlice(ip), null),
                                fmtStringLiteral(extern_name, null),
                            });
                        }
                    },
                }
            },
            .complete => {},
            else => unreachable,
        }
    }

    fn ctypeFromType(dg: *DeclGen, ty: Type, kind: CType.Kind) !CType {
        defer std.debug.assert(dg.scratch.items.len == 0);
        return dg.ctype_pool.fromType(dg.gpa, &dg.scratch, ty, dg.pt, dg.mod, kind);
    }

    fn byteSize(dg: *DeclGen, ctype: CType) u64 {
        return ctype.byteSize(&dg.ctype_pool, dg.mod);
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
    fn renderType(dg: *DeclGen, w: anytype, t: Type) error{OutOfMemory}!void {
        try dg.renderCType(w, try dg.ctypeFromType(t, .complete));
    }

    fn renderCType(dg: *DeclGen, w: anytype, ctype: CType) error{OutOfMemory}!void {
        _ = try renderTypePrefix(dg.pass, &dg.ctype_pool, dg.pt.zcu, w, ctype, .suffix, .{});
        try renderTypeSuffix(dg.pass, &dg.ctype_pool, dg.pt.zcu, w, ctype, .suffix, .{});
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

        pub fn writeValue(self: *const IntCastContext, dg: *DeclGen, w: anytype, location: ValueRenderLocation) !void {
            switch (self.*) {
                .c_value => |v| {
                    try v.f.writeCValue(w, v.value, location);
                    try v.v.elem(v.f, w);
                },
                .value => |v| try dg.renderValue(w, v.value, location),
            }
        }
    };
    fn intCastIsNoop(dg: *DeclGen, dest_ty: Type, src_ty: Type) bool {
        const pt = dg.pt;
        const zcu = pt.zcu;
        const dest_bits = dest_ty.bitSize(zcu);
        const dest_int_info = dest_ty.intInfo(pt.zcu);

        const src_is_ptr = src_ty.isPtrAtRuntime(pt.zcu);
        const src_eff_ty: Type = if (src_is_ptr) switch (dest_int_info.signedness) {
            .unsigned => Type.usize,
            .signed => Type.isize,
        } else src_ty;

        const src_bits = src_eff_ty.bitSize(zcu);
        const src_int_info = if (src_eff_ty.isAbiInt(pt.zcu)) src_eff_ty.intInfo(pt.zcu) else null;
        if (dest_bits <= 64 and src_bits <= 64) {
            const needs_cast = src_int_info == null or
                (toCIntBits(dest_int_info.bits) != toCIntBits(src_int_info.?.bits) or
                dest_int_info.signedness != src_int_info.?.signedness);
            return !needs_cast and !src_is_ptr;
        } else return false;
    }
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
    fn renderIntCast(
        dg: *DeclGen,
        w: anytype,
        dest_ty: Type,
        context: IntCastContext,
        src_ty: Type,
        location: ValueRenderLocation,
    ) !void {
        const pt = dg.pt;
        const zcu = pt.zcu;
        const dest_bits = dest_ty.bitSize(zcu);
        const dest_int_info = dest_ty.intInfo(zcu);

        const src_is_ptr = src_ty.isPtrAtRuntime(zcu);
        const src_eff_ty: Type = if (src_is_ptr) switch (dest_int_info.signedness) {
            .unsigned => Type.usize,
            .signed => Type.isize,
        } else src_ty;

        const src_bits = src_eff_ty.bitSize(zcu);
        const src_int_info = if (src_eff_ty.isAbiInt(zcu)) src_eff_ty.intInfo(zcu) else null;
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
            try context.writeValue(dg, w, location);
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
            try context.writeValue(dg, w, .FunctionArgument);
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
            try context.writeValue(dg, w, .FunctionArgument);
            try w.writeByte(')');
        } else {
            assert(!src_is_ptr);
            try w.writeAll("zig_make_");
            try dg.renderTypeForBuiltinFnName(w, dest_ty);
            try w.writeAll("(zig_hi_");
            try dg.renderTypeForBuiltinFnName(w, src_eff_ty);
            try w.writeByte('(');
            try context.writeValue(dg, w, .FunctionArgument);
            try w.writeAll("), zig_lo_");
            try dg.renderTypeForBuiltinFnName(w, src_eff_ty);
            try w.writeByte('(');
            try context.writeValue(dg, w, .FunctionArgument);
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
        try dg.renderCTypeAndName(
            w,
            try dg.ctypeFromType(ty, kind),
            name,
            qualifiers,
            CType.AlignAs.fromAlignment(.{
                .@"align" = alignment,
                .abi = ty.abiAlignment(dg.pt.zcu),
            }),
        );
    }

    fn renderCTypeAndName(
        dg: *DeclGen,
        w: anytype,
        ctype: CType,
        name: CValue,
        qualifiers: CQualifiers,
        alignas: CType.AlignAs,
    ) error{ OutOfMemory, AnalysisFail }!void {
        const zcu = dg.pt.zcu;
        switch (alignas.abiOrder()) {
            .lt => try w.print("zig_under_align({}) ", .{alignas.toByteUnits()}),
            .eq => {},
            .gt => try w.print("zig_align({}) ", .{alignas.toByteUnits()}),
        }

        try w.print("{}", .{
            try renderTypePrefix(dg.pass, &dg.ctype_pool, zcu, w, ctype, .suffix, qualifiers),
        });
        try dg.writeName(w, name);
        try renderTypeSuffix(dg.pass, &dg.ctype_pool, zcu, w, ctype, .suffix, .{});
    }

    fn writeName(dg: *DeclGen, w: anytype, c_value: CValue) !void {
        switch (c_value) {
            .new_local, .local => |i| try w.print("t{d}", .{i}),
            .constant => |uav| try renderUavName(w, uav),
            .nav => |nav| try dg.renderNavName(w, nav),
            .identifier => |ident| try w.print("{ }", .{fmtIdent(ident)}),
            else => unreachable,
        }
    }

    fn writeCValue(dg: *DeclGen, w: anytype, c_value: CValue) !void {
        switch (c_value) {
            .none, .new_local, .local, .local_ref => unreachable,
            .constant => |uav| try renderUavName(w, uav),
            .arg, .arg_array => unreachable,
            .field => |i| try w.print("f{d}", .{i}),
            .nav => |nav| try dg.renderNavName(w, nav),
            .nav_ref => |nav| {
                try w.writeByte('&');
                try dg.renderNavName(w, nav);
            },
            .undef => |ty| try dg.renderUndefValue(w, ty, .Other),
            .identifier => |ident| try w.print("{ }", .{fmtIdent(ident)}),
            .payload_identifier => |ident| try w.print("{ }.{ }", .{
                fmtIdent("payload"),
                fmtIdent(ident),
            }),
            .ctype_pool_string => |string| try w.print("{ }", .{
                fmtCTypePoolString(string, &dg.ctype_pool),
            }),
        }
    }

    fn writeCValueDeref(dg: *DeclGen, w: anytype, c_value: CValue) !void {
        switch (c_value) {
            .none,
            .new_local,
            .local,
            .local_ref,
            .constant,
            .arg,
            .arg_array,
            .ctype_pool_string,
            => unreachable,
            .field => |i| try w.print("f{d}", .{i}),
            .nav => |nav| {
                try w.writeAll("(*");
                try dg.renderNavName(w, nav);
                try w.writeByte(')');
            },
            .nav_ref => |nav| try dg.renderNavName(w, nav),
            .undef => unreachable,
            .identifier => |ident| try w.print("(*{ })", .{fmtIdent(ident)}),
            .payload_identifier => |ident| try w.print("(*{ }.{ })", .{
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
            .none,
            .new_local,
            .local,
            .local_ref,
            .constant,
            .field,
            .undef,
            .arg,
            .arg_array,
            .ctype_pool_string,
            => unreachable,
            .nav, .identifier, .payload_identifier => {
                try dg.writeCValue(writer, c_value);
                try writer.writeAll("->");
            },
            .nav_ref => {
                try dg.writeCValueDeref(writer, c_value);
                try writer.writeByte('.');
            },
        }
        try dg.writeCValue(writer, member);
    }

    fn renderFwdDecl(
        dg: *DeclGen,
        nav_index: InternPool.Nav.Index,
        flags: struct {
            is_extern: bool,
            is_const: bool,
            is_threadlocal: bool,
            is_weak_linkage: bool,
        },
    ) !void {
        const zcu = dg.pt.zcu;
        const ip = &zcu.intern_pool;
        const nav = ip.getNav(nav_index);
        const fwd = dg.fwdDeclWriter();
        try fwd.writeAll(if (flags.is_extern) "zig_extern " else "static ");
        if (flags.is_weak_linkage) try fwd.writeAll("zig_weak_linkage ");
        if (flags.is_threadlocal and !dg.mod.single_threaded) try fwd.writeAll("zig_threadlocal ");
        try dg.renderTypeAndName(
            fwd,
            Type.fromInterned(nav.typeOf(ip)),
            .{ .nav = nav_index },
            CQualifiers.init(.{ .@"const" = flags.is_const }),
            nav.status.resolved.alignment,
            .complete,
        );
        try fwd.writeAll(";\n");
    }

    fn renderNavName(dg: *DeclGen, writer: anytype, nav_index: InternPool.Nav.Index) !void {
        const zcu = dg.pt.zcu;
        const ip = &zcu.intern_pool;
        switch (ip.indexToKey(zcu.navValue(nav_index).toIntern())) {
            .@"extern" => |@"extern"| try writer.print("{ }", .{
                fmtIdent(ip.getNav(@"extern".owner_nav).name.toSlice(ip)),
            }),
            else => {
                // MSVC has a limit of 4095 character token length limit, and fmtIdent can (worst case),
                // expand to 3x the length of its input, but let's cut it off at a much shorter limit.
                const fqn_slice = ip.getNav(nav_index).fqn.toSlice(ip);
                try writer.print("{}__{d}", .{
                    fmtIdent(fqn_slice[0..@min(fqn_slice.len, 100)]),
                    @intFromEnum(nav_index),
                });
            },
        }
    }

    fn renderUavName(writer: anytype, uav: Value) !void {
        try writer.print("__anon_{d}", .{@intFromEnum(uav.toIntern())});
    }

    fn renderTypeForBuiltinFnName(dg: *DeclGen, writer: anytype, ty: Type) !void {
        try dg.renderCTypeForBuiltinFnName(writer, try dg.ctypeFromType(ty, .complete));
    }

    fn renderCTypeForBuiltinFnName(dg: *DeclGen, writer: anytype, ctype: CType) !void {
        switch (ctype.info(&dg.ctype_pool)) {
            else => |ctype_info| try writer.print("{c}{d}", .{
                if (ctype.isBool())
                    signAbbrev(.unsigned)
                else if (ctype.isInteger())
                    signAbbrev(ctype.signedness(dg.mod))
                else if (ctype.isFloat())
                    @as(u8, 'f')
                else if (ctype_info == .pointer)
                    @as(u8, 'p')
                else
                    return dg.fail("TODO: CBE: implement renderTypeForBuiltinFnName for {s} type", .{@tagName(ctype_info)}),
                if (ctype.isFloat()) ctype.floatActiveBits(dg.mod) else dg.byteSize(ctype) * 8,
            }),
            .array => try writer.writeAll("big"),
        }
    }

    fn renderBuiltinInfo(dg: *DeclGen, writer: anytype, ty: Type, info: BuiltinInfo) !void {
        const ctype = try dg.ctypeFromType(ty, .complete);
        const is_big = ctype.info(&dg.ctype_pool) == .array;
        switch (info) {
            .none => if (!is_big) return,
            .bits => {},
        }

        const pt = dg.pt;
        const zcu = pt.zcu;
        const int_info = if (ty.isAbiInt(zcu)) ty.intInfo(zcu) else std.builtin.Type.Int{
            .signedness = .unsigned,
            .bits = @as(u16, @intCast(ty.bitSize(zcu))),
        };

        if (is_big) try writer.print(", {}", .{int_info.signedness == .signed});
        try writer.print(", {}", .{try dg.fmtIntLiteral(
            try pt.intValue(if (is_big) Type.u16 else Type.u8, int_info.bits),
            .FunctionArgument,
        )});
    }

    fn fmtIntLiteral(
        dg: *DeclGen,
        val: Value,
        loc: ValueRenderLocation,
    ) !std.fmt.Formatter(formatIntLiteral) {
        const zcu = dg.pt.zcu;
        const kind = loc.toCTypeKind();
        const ty = val.typeOf(zcu);
        return std.fmt.Formatter(formatIntLiteral){ .data = .{
            .dg = dg,
            .int_info = ty.intInfo(zcu),
            .kind = kind,
            .ctype = try dg.ctypeFromType(ty, kind),
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
fn renderAlignedTypeName(w: anytype, ctype: CType) !void {
    try w.print("anon__aligned_{d}", .{@intFromEnum(ctype.index)});
}
fn renderFwdDeclTypeName(
    zcu: *Zcu,
    w: anytype,
    ctype: CType,
    fwd_decl: CType.Info.FwdDecl,
    attributes: []const u8,
) !void {
    const ip = &zcu.intern_pool;
    try w.print("{s} {s}", .{ @tagName(fwd_decl.tag), attributes });
    switch (fwd_decl.name) {
        .anon => try w.print("anon__lazy_{d}", .{@intFromEnum(ctype.index)}),
        .index => |index| try w.print("{}__{d}", .{
            fmtIdent(Type.fromInterned(index).containerTypeName(ip).toSlice(&zcu.intern_pool)),
            @intFromEnum(index),
        }),
    }
}
fn renderTypePrefix(
    pass: DeclGen.Pass,
    ctype_pool: *const CType.Pool,
    zcu: *Zcu,
    w: anytype,
    ctype: CType,
    parent_fix: CTypeFix,
    qualifiers: CQualifiers,
) @TypeOf(w).Error!RenderCTypeTrailing {
    var trailing = RenderCTypeTrailing.maybe_space;
    switch (ctype.info(ctype_pool)) {
        .basic => |basic_info| try w.writeAll(@tagName(basic_info)),

        .pointer => |pointer_info| {
            try w.print("{}*", .{try renderTypePrefix(
                pass,
                ctype_pool,
                zcu,
                w,
                pointer_info.elem_ctype,
                .prefix,
                CQualifiers.init(.{
                    .@"const" = pointer_info.@"const",
                    .@"volatile" = pointer_info.@"volatile",
                }),
            )});
            trailing = .no_space;
        },

        .aligned => switch (pass) {
            .nav => |nav| try w.print("nav__{d}_{d}", .{
                @intFromEnum(nav), @intFromEnum(ctype.index),
            }),
            .uav => |uav| try w.print("uav__{d}_{d}", .{
                @intFromEnum(uav), @intFromEnum(ctype.index),
            }),
            .flush => try renderAlignedTypeName(w, ctype),
        },

        .array, .vector => |sequence_info| {
            const child_trailing = try renderTypePrefix(
                pass,
                ctype_pool,
                zcu,
                w,
                sequence_info.elem_ctype,
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

        .fwd_decl => |fwd_decl_info| switch (fwd_decl_info.name) {
            .anon => switch (pass) {
                .nav => |nav| try w.print("nav__{d}_{d}", .{
                    @intFromEnum(nav), @intFromEnum(ctype.index),
                }),
                .uav => |uav| try w.print("uav__{d}_{d}", .{
                    @intFromEnum(uav), @intFromEnum(ctype.index),
                }),
                .flush => try renderFwdDeclTypeName(zcu, w, ctype, fwd_decl_info, ""),
            },
            .index => try renderFwdDeclTypeName(zcu, w, ctype, fwd_decl_info, ""),
        },

        .aggregate => |aggregate_info| switch (aggregate_info.name) {
            .anon => {
                try w.print("{s} {s}", .{
                    @tagName(aggregate_info.tag),
                    if (aggregate_info.@"packed") "zig_packed(" else "",
                });
                try renderFields(zcu, w, ctype_pool, aggregate_info, 1);
                if (aggregate_info.@"packed") try w.writeByte(')');
            },
            .fwd_decl => |fwd_decl| return renderTypePrefix(
                pass,
                ctype_pool,
                zcu,
                w,
                fwd_decl,
                parent_fix,
                qualifiers,
            ),
        },

        .function => |function_info| {
            const child_trailing = try renderTypePrefix(
                pass,
                ctype_pool,
                zcu,
                w,
                function_info.return_ctype,
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
    ctype_pool: *const CType.Pool,
    zcu: *Zcu,
    w: anytype,
    ctype: CType,
    parent_fix: CTypeFix,
    qualifiers: CQualifiers,
) @TypeOf(w).Error!void {
    switch (ctype.info(ctype_pool)) {
        .basic, .aligned, .fwd_decl, .aggregate => {},
        .pointer => |pointer_info| try renderTypeSuffix(
            pass,
            ctype_pool,
            zcu,
            w,
            pointer_info.elem_ctype,
            .prefix,
            .{},
        ),
        .array, .vector => |sequence_info| {
            switch (parent_fix) {
                .prefix => try w.writeByte(')'),
                .suffix => {},
            }

            try w.print("[{}]", .{sequence_info.len});
            try renderTypeSuffix(pass, ctype_pool, zcu, w, sequence_info.elem_ctype, .suffix, .{});
        },
        .function => |function_info| {
            switch (parent_fix) {
                .prefix => try w.writeByte(')'),
                .suffix => {},
            }

            try w.writeByte('(');
            var need_comma = false;
            for (0..function_info.param_ctypes.len) |param_index| {
                const param_type = function_info.param_ctypes.at(param_index, ctype_pool);
                if (need_comma) try w.writeAll(", ");
                need_comma = true;
                const trailing =
                    try renderTypePrefix(pass, ctype_pool, zcu, w, param_type, .suffix, qualifiers);
                if (qualifiers.contains(.@"const")) try w.print("{}a{d}", .{ trailing, param_index });
                try renderTypeSuffix(pass, ctype_pool, zcu, w, param_type, .suffix, .{});
            }
            if (function_info.varargs) {
                if (need_comma) try w.writeAll(", ");
                need_comma = true;
                try w.writeAll("...");
            }
            if (!need_comma) try w.writeAll("void");
            try w.writeByte(')');

            try renderTypeSuffix(pass, ctype_pool, zcu, w, function_info.return_ctype, .suffix, .{});
        },
    }
}
fn renderFields(
    zcu: *Zcu,
    writer: anytype,
    ctype_pool: *const CType.Pool,
    aggregate_info: CType.Info.Aggregate,
    indent: usize,
) !void {
    try writer.writeAll("{\n");
    for (0..aggregate_info.fields.len) |field_index| {
        const field_info = aggregate_info.fields.at(field_index, ctype_pool);
        try writer.writeByteNTimes(' ', indent + 1);
        switch (field_info.alignas.abiOrder()) {
            .lt => {
                std.debug.assert(aggregate_info.@"packed");
                if (field_info.alignas.@"align" != .@"1") try writer.print("zig_under_align({}) ", .{
                    field_info.alignas.toByteUnits(),
                });
            },
            .eq => if (aggregate_info.@"packed" and field_info.alignas.@"align" != .@"1")
                try writer.print("zig_align({}) ", .{field_info.alignas.toByteUnits()}),
            .gt => {
                std.debug.assert(field_info.alignas.@"align" != .@"1");
                try writer.print("zig_align({}) ", .{field_info.alignas.toByteUnits()});
            },
        }
        const trailing = try renderTypePrefix(
            .flush,
            ctype_pool,
            zcu,
            writer,
            field_info.ctype,
            .suffix,
            .{},
        );
        try writer.print("{}{ }", .{ trailing, fmtCTypePoolString(field_info.name, ctype_pool) });
        try renderTypeSuffix(.flush, ctype_pool, zcu, writer, field_info.ctype, .suffix, .{});
        try writer.writeAll(";\n");
    }
    try writer.writeByteNTimes(' ', indent);
    try writer.writeByte('}');
}

pub fn genTypeDecl(
    zcu: *Zcu,
    writer: anytype,
    global_ctype_pool: *const CType.Pool,
    global_ctype: CType,
    pass: DeclGen.Pass,
    decl_ctype_pool: *const CType.Pool,
    decl_ctype: CType,
    found_existing: bool,
) !void {
    switch (global_ctype.info(global_ctype_pool)) {
        .basic, .pointer, .array, .vector, .function => {},
        .aligned => |aligned_info| {
            if (!found_existing) {
                std.debug.assert(aligned_info.alignas.abiOrder().compare(.lt));
                try writer.print("typedef zig_under_align({d}) ", .{aligned_info.alignas.toByteUnits()});
                try writer.print("{}", .{try renderTypePrefix(
                    .flush,
                    global_ctype_pool,
                    zcu,
                    writer,
                    aligned_info.ctype,
                    .suffix,
                    .{},
                )});
                try renderAlignedTypeName(writer, global_ctype);
                try renderTypeSuffix(.flush, global_ctype_pool, zcu, writer, aligned_info.ctype, .suffix, .{});
                try writer.writeAll(";\n");
            }
            switch (pass) {
                .nav, .uav => {
                    try writer.writeAll("typedef ");
                    _ = try renderTypePrefix(.flush, global_ctype_pool, zcu, writer, global_ctype, .suffix, .{});
                    try writer.writeByte(' ');
                    _ = try renderTypePrefix(pass, decl_ctype_pool, zcu, writer, decl_ctype, .suffix, .{});
                    try writer.writeAll(";\n");
                },
                .flush => {},
            }
        },
        .fwd_decl => |fwd_decl_info| switch (fwd_decl_info.name) {
            .anon => switch (pass) {
                .nav, .uav => {
                    try writer.writeAll("typedef ");
                    _ = try renderTypePrefix(.flush, global_ctype_pool, zcu, writer, global_ctype, .suffix, .{});
                    try writer.writeByte(' ');
                    _ = try renderTypePrefix(pass, decl_ctype_pool, zcu, writer, decl_ctype, .suffix, .{});
                    try writer.writeAll(";\n");
                },
                .flush => {},
            },
            .index => |index| if (!found_existing) {
                const ip = &zcu.intern_pool;
                const ty = Type.fromInterned(index);
                _ = try renderTypePrefix(.flush, global_ctype_pool, zcu, writer, global_ctype, .suffix, .{});
                try writer.writeByte(';');
                const file_scope = ty.typeDeclInstAllowGeneratedTag(zcu).?.resolveFile(ip);
                if (!zcu.fileByIndex(file_scope).mod.strip) try writer.print(" /* {} */", .{
                    ty.containerTypeName(ip).fmt(ip),
                });
                try writer.writeByte('\n');
            },
        },
        .aggregate => |aggregate_info| switch (aggregate_info.name) {
            .anon => {},
            .fwd_decl => |fwd_decl| if (!found_existing) {
                try renderFwdDeclTypeName(
                    zcu,
                    writer,
                    fwd_decl,
                    fwd_decl.info(global_ctype_pool).fwd_decl,
                    if (aggregate_info.@"packed") "zig_packed(" else "",
                );
                try writer.writeByte(' ');
                try renderFields(zcu, writer, global_ctype_pool, aggregate_info, 0);
                if (aggregate_info.@"packed") try writer.writeByte(')');
                try writer.writeAll(";\n");
            },
        },
    }
}

pub fn genGlobalAsm(zcu: *Zcu, writer: anytype) !void {
    for (zcu.global_assembly.values()) |asm_source| {
        try writer.print("__asm({s});\n", .{fmtStringLiteral(asm_source, null)});
    }
}

pub fn genErrDecls(o: *Object) !void {
    const pt = o.dg.pt;
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const writer = o.writer();

    var max_name_len: usize = 0;
    // do not generate an invalid empty enum when the global error set is empty
    const names = ip.global_error_set.getNamesFromMainThread();
    if (names.len > 0) {
        try writer.writeAll("enum {\n");
        o.indent_writer.pushIndent();
        for (names, 1..) |name_nts, value| {
            const name = name_nts.toSlice(ip);
            max_name_len = @max(name.len, max_name_len);
            const err_val = try pt.intern(.{ .err = .{
                .ty = .anyerror_type,
                .name = name_nts,
            } });
            try o.dg.renderValue(writer, Value.fromInterned(err_val), .Other);
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
    for (names) |name| {
        const name_slice = name.toSlice(ip);
        @memcpy(name_buf[name_prefix.len..][0..name_slice.len], name_slice);
        const identifier = name_buf[0 .. name_prefix.len + name_slice.len];

        const name_ty = try pt.arrayType(.{
            .len = name_slice.len,
            .child = .u8_type,
            .sentinel = .zero_u8,
        });
        const name_val = try pt.intern(.{ .aggregate = .{
            .ty = name_ty.toIntern(),
            .storage = .{ .bytes = name.toString() },
        } });

        try writer.writeAll("static ");
        try o.dg.renderTypeAndName(
            writer,
            name_ty,
            .{ .identifier = identifier },
            Const,
            .none,
            .complete,
        );
        try writer.writeAll(" = ");
        try o.dg.renderValue(writer, Value.fromInterned(name_val), .StaticInitializer);
        try writer.writeAll(";\n");
    }

    const name_array_ty = try pt.arrayType(.{
        .len = 1 + names.len,
        .child = .slice_const_u8_sentinel_0_type,
    });

    try writer.writeAll("static ");
    try o.dg.renderTypeAndName(
        writer,
        name_array_ty,
        .{ .identifier = array_identifier },
        Const,
        .none,
        .complete,
    );
    try writer.writeAll(" = {");
    for (names, 1..) |name_nts, val| {
        const name = name_nts.toSlice(ip);
        if (val > 1) try writer.writeAll(", ");
        try writer.print("{{" ++ name_prefix ++ "{}, {}}}", .{
            fmtIdent(name),
            try o.dg.fmtIntLiteral(try pt.intValue(Type.usize, name.len), .StaticInitializer),
        });
    }
    try writer.writeAll("};\n");
}

pub fn genLazyFn(o: *Object, lazy_ctype_pool: *const CType.Pool, lazy_fn: LazyFnMap.Entry) !void {
    const pt = o.dg.pt;
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const ctype_pool = &o.dg.ctype_pool;
    const w = o.writer();
    const key = lazy_fn.key_ptr.*;
    const val = lazy_fn.value_ptr;
    switch (key) {
        .tag_name => |enum_ty_ip| {
            const enum_ty = Type.fromInterned(enum_ty_ip);
            const name_slice_ty = Type.slice_const_u8_sentinel_0;

            try w.writeAll("static ");
            try o.dg.renderType(w, name_slice_ty);
            try w.print(" {}(", .{val.fn_name.fmt(lazy_ctype_pool)});
            try o.dg.renderTypeAndName(w, enum_ty, .{ .identifier = "tag" }, Const, .none, .complete);
            try w.writeAll(") {\n switch (tag) {\n");
            const tag_names = enum_ty.enumFields(zcu);
            for (0..tag_names.len) |tag_index| {
                const tag_name = tag_names.get(ip)[tag_index];
                const tag_name_len = tag_name.length(ip);
                const tag_val = try pt.enumValueFieldIndex(enum_ty, @intCast(tag_index));

                const name_ty = try pt.arrayType(.{
                    .len = tag_name_len,
                    .child = .u8_type,
                    .sentinel = .zero_u8,
                });
                const name_val = try pt.intern(.{ .aggregate = .{
                    .ty = name_ty.toIntern(),
                    .storage = .{ .bytes = tag_name.toString() },
                } });

                try w.print("  case {}: {{\n   static ", .{
                    try o.dg.fmtIntLiteral(try tag_val.intFromEnum(enum_ty, pt), .Other),
                });
                try o.dg.renderTypeAndName(w, name_ty, .{ .identifier = "name" }, Const, .none, .complete);
                try w.writeAll(" = ");
                try o.dg.renderValue(w, Value.fromInterned(name_val), .Initializer);
                try w.writeAll(";\n   return (");
                try o.dg.renderType(w, name_slice_ty);
                try w.print("){{{}, {}}};\n", .{
                    fmtIdent("name"),
                    try o.dg.fmtIntLiteral(try pt.intValue(Type.usize, tag_name_len), .Other),
                });

                try w.writeAll("  }\n");
            }
            try w.writeAll(" }\n while (");
            try o.dg.renderValue(w, Value.true, .Other);
            try w.writeAll(") ");
            _ = try airBreakpoint(w);
            try w.writeAll("}\n");
        },
        .never_tail, .never_inline => |fn_nav_index| {
            const fn_val = zcu.navValue(fn_nav_index);
            const fn_ctype = try o.dg.ctypeFromType(fn_val.typeOf(zcu), .complete);
            const fn_info = fn_ctype.info(ctype_pool).function;
            const fn_name = fmtCTypePoolString(val.fn_name, lazy_ctype_pool);

            const fwd = o.dg.fwdDeclWriter();
            try fwd.print("static zig_{s} ", .{@tagName(key)});
            try o.dg.renderFunctionSignature(fwd, fn_val, ip.getNav(fn_nav_index).status.resolved.alignment, .forward, .{
                .fmt_ctype_pool_string = fn_name,
            });
            try fwd.writeAll(";\n");

            try w.print("zig_{s} ", .{@tagName(key)});
            try o.dg.renderFunctionSignature(w, fn_val, .none, .complete, .{
                .fmt_ctype_pool_string = fn_name,
            });
            try w.writeAll(" {\n return ");
            try o.dg.renderNavName(w, fn_nav_index);
            try w.writeByte('(');
            for (0..fn_info.param_ctypes.len) |arg| {
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
    const zcu = o.dg.pt.zcu;
    const ip = &zcu.intern_pool;
    const gpa = o.dg.gpa;
    const nav_index = o.dg.pass.nav;
    const nav_val = zcu.navValue(nav_index);
    const nav = ip.getNav(nav_index);

    o.code_header = std.ArrayList(u8).init(gpa);
    defer o.code_header.deinit();

    const fwd = o.dg.fwdDeclWriter();
    try fwd.writeAll("static ");
    try o.dg.renderFunctionSignature(
        fwd,
        nav_val,
        nav.status.resolved.alignment,
        .forward,
        .{ .nav = nav_index },
    );
    try fwd.writeAll(";\n");

    if (nav.status.resolved.@"linksection".toSlice(ip)) |s|
        try o.writer().print("zig_linksection_fn({s}) ", .{fmtStringLiteral(s, null)});
    try o.dg.renderFunctionSignature(
        o.writer(),
        nav_val,
        .none,
        .complete,
        .{ .nav = nav_index },
    );
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
            try o.dg.renderCTypeAndName(w, local.ctype, .{ .local = local_index }, .{}, local.flags.alignas);
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

    const pt = o.dg.pt;
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const nav = ip.getNav(o.dg.pass.nav);
    const nav_ty = Type.fromInterned(nav.typeOf(ip));

    if (!nav_ty.isFnOrHasRuntimeBitsIgnoreComptime(zcu)) return;
    switch (ip.indexToKey(nav.status.resolved.val)) {
        .@"extern" => |@"extern"| {
            if (!ip.isFunctionType(nav_ty.toIntern())) return o.dg.renderFwdDecl(o.dg.pass.nav, .{
                .is_extern = true,
                .is_const = @"extern".is_const,
                .is_threadlocal = @"extern".is_threadlocal,
                .is_weak_linkage = @"extern".is_weak_linkage,
            });

            const fwd = o.dg.fwdDeclWriter();
            try fwd.writeAll("zig_extern ");
            try o.dg.renderFunctionSignature(
                fwd,
                Value.fromInterned(nav.status.resolved.val),
                nav.status.resolved.alignment,
                .forward,
                .{ .@"export" = .{
                    .main_name = nav.name,
                    .extern_name = nav.name,
                } },
            );
            try fwd.writeAll(";\n");
        },
        .variable => |variable| {
            try o.dg.renderFwdDecl(o.dg.pass.nav, .{
                .is_extern = false,
                .is_const = false,
                .is_threadlocal = variable.is_threadlocal,
                .is_weak_linkage = variable.is_weak_linkage,
            });
            const w = o.writer();
            if (variable.is_weak_linkage) try w.writeAll("zig_weak_linkage ");
            if (variable.is_threadlocal and !o.dg.mod.single_threaded) try w.writeAll("zig_threadlocal ");
            if (nav.status.resolved.@"linksection".toSlice(&zcu.intern_pool)) |s|
                try w.print("zig_linksection({s}) ", .{fmtStringLiteral(s, null)});
            try o.dg.renderTypeAndName(
                w,
                nav_ty,
                .{ .nav = o.dg.pass.nav },
                .{},
                nav.status.resolved.alignment,
                .complete,
            );
            try w.writeAll(" = ");
            try o.dg.renderValue(w, Value.fromInterned(variable.init), .StaticInitializer);
            try w.writeByte(';');
            try o.indent_writer.insertNewline();
        },
        else => try genDeclValue(
            o,
            Value.fromInterned(nav.status.resolved.val),
            .{ .nav = o.dg.pass.nav },
            nav.status.resolved.alignment,
            nav.status.resolved.@"linksection",
        ),
    }
}

pub fn genDeclValue(
    o: *Object,
    val: Value,
    decl_c_value: CValue,
    alignment: Alignment,
    @"linksection": InternPool.OptionalNullTerminatedString,
) !void {
    const zcu = o.dg.pt.zcu;
    const ty = val.typeOf(zcu);

    const fwd = o.dg.fwdDeclWriter();
    try fwd.writeAll("static ");
    try o.dg.renderTypeAndName(fwd, ty, decl_c_value, Const, alignment, .complete);
    try fwd.writeAll(";\n");

    const w = o.writer();
    if (@"linksection".toSlice(&zcu.intern_pool)) |s|
        try w.print("zig_linksection({s}) ", .{fmtStringLiteral(s, null)});
    try o.dg.renderTypeAndName(w, ty, decl_c_value, Const, alignment, .complete);
    try w.writeAll(" = ");
    try o.dg.renderValue(w, val, .StaticInitializer);
    try w.writeAll(";\n");
}

pub fn genExports(dg: *DeclGen, exported: Zcu.Exported, export_indices: []const u32) !void {
    const zcu = dg.pt.zcu;
    const ip = &zcu.intern_pool;
    const fwd = dg.fwdDeclWriter();

    const main_name = zcu.all_exports.items[export_indices[0]].opts.name;
    try fwd.writeAll("#define ");
    switch (exported) {
        .nav => |nav| try dg.renderNavName(fwd, nav),
        .uav => |uav| try DeclGen.renderUavName(fwd, Value.fromInterned(uav)),
    }
    try fwd.writeByte(' ');
    try fwd.print("{ }", .{fmtIdent(main_name.toSlice(ip))});
    try fwd.writeByte('\n');

    const exported_val = exported.getValue(zcu);
    if (ip.isFunctionType(exported_val.typeOf(zcu).toIntern())) return for (export_indices) |export_index| {
        const @"export" = &zcu.all_exports.items[export_index];
        try fwd.writeAll("zig_extern ");
        if (@"export".opts.linkage == .weak) try fwd.writeAll("zig_weak_linkage_fn ");
        try dg.renderFunctionSignature(
            fwd,
            exported.getValue(zcu),
            exported.getAlign(zcu),
            .forward,
            .{ .@"export" = .{
                .main_name = main_name,
                .extern_name = @"export".opts.name,
            } },
        );
        try fwd.writeAll(";\n");
    };
    const is_const = switch (ip.indexToKey(exported_val.toIntern())) {
        .func => unreachable,
        .@"extern" => |@"extern"| @"extern".is_const,
        .variable => false,
        else => true,
    };
    for (export_indices) |export_index| {
        const @"export" = &zcu.all_exports.items[export_index];
        try fwd.writeAll("zig_extern ");
        if (@"export".opts.linkage == .weak) try fwd.writeAll("zig_weak_linkage ");
        const extern_name = @"export".opts.name.toSlice(ip);
        const is_mangled = isMangledIdent(extern_name, true);
        const is_export = @"export".opts.name != main_name;
        try dg.renderTypeAndName(
            fwd,
            exported.getValue(zcu).typeOf(zcu),
            .{ .identifier = extern_name },
            CQualifiers.init(.{ .@"const" = is_const }),
            exported.getAlign(zcu),
            .complete,
        );
        if (is_mangled and is_export) {
            try fwd.print(" zig_mangled_export({ }, {s}, {s})", .{
                fmtIdent(extern_name),
                fmtStringLiteral(extern_name, null),
                fmtStringLiteral(main_name.toSlice(ip), null),
            });
        } else if (is_mangled) {
            try fwd.print(" zig_mangled({ }, {s})", .{
                fmtIdent(extern_name), fmtStringLiteral(extern_name, null),
            });
        } else if (is_export) {
            try fwd.print(" zig_export({s}, {s})", .{
                fmtStringLiteral(main_name.toSlice(ip), null),
                fmtStringLiteral(extern_name, null),
            });
        }
        try fwd.writeAll(";\n");
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
    const zcu = f.object.dg.pt.zcu;
    const ip = &zcu.intern_pool;
    const air_tags = f.air.instructions.items(.tag);
    const air_datas = f.air.instructions.items(.data);

    for (body) |inst| {
        if (f.liveness.isUnused(inst) and !f.air.mustLower(inst, ip))
            continue;

        const result_value = switch (air_tags[@intFromEnum(inst)]) {
            // zig fmt: off
            .inferred_alloc, .inferred_alloc_comptime => unreachable,

            .arg      => try airArg(f, inst),

            .breakpoint => try airBreakpoint(f.object.writer()),
            .ret_addr   => try airRetAddr(f, inst),
            .frame_addr => try airFrameAddress(f, inst),

            .ptr_add => try airPtrAddSub(f, inst, '+'),
            .ptr_sub => try airPtrAddSub(f, inst, '-'),

            // TODO use a different strategy for add, sub, mul, div
            // that communicates to the optimizer that wrapping is UB.
            .add => try airBinOp(f, inst, "+", "add", .none),
            .sub => try airBinOp(f, inst, "-", "sub", .none),
            .mul => try airBinOp(f, inst, "*", "mul", .none),

            .neg => try airUnBuiltinCall(f, inst, air_datas[@intFromEnum(inst)].un_op, "neg", .none),
            .div_float => try airBinBuiltinCall(f, inst, "div", .none),

            .div_trunc, .div_exact => try airBinOp(f, inst, "/", "div_trunc", .none),
            .rem => blk: {
                const bin_op = air_datas[@intFromEnum(inst)].bin_op;
                const lhs_scalar_ty = f.typeOf(bin_op.lhs).scalarType(zcu);
                // For binary operations @TypeOf(lhs)==@TypeOf(rhs),
                // so we only check one.
                break :blk if (lhs_scalar_ty.isInt(zcu))
                    try airBinOp(f, inst, "%", "rem", .none)
                else
                    try airBinBuiltinCall(f, inst, "fmod", .none);
            },
            .div_floor => try airBinBuiltinCall(f, inst, "div_floor", .none),
            .mod       => try airBinBuiltinCall(f, inst, "mod", .none),
            .abs       => try airUnBuiltinCall(f, inst, air_datas[@intFromEnum(inst)].ty_op.operand, "abs", .none),

            .add_wrap => try airBinBuiltinCall(f, inst, "addw", .bits),
            .sub_wrap => try airBinBuiltinCall(f, inst, "subw", .bits),
            .mul_wrap => try airBinBuiltinCall(f, inst, "mulw", .bits),

            .add_sat => try airBinBuiltinCall(f, inst, "adds", .bits),
            .sub_sat => try airBinBuiltinCall(f, inst, "subs", .bits),
            .mul_sat => try airBinBuiltinCall(f, inst, "muls", .bits),
            .shl_sat => try airBinBuiltinCall(f, inst, "shls", .bits),

            .sqrt        => try airUnBuiltinCall(f, inst, air_datas[@intFromEnum(inst)].un_op, "sqrt", .none),
            .sin         => try airUnBuiltinCall(f, inst, air_datas[@intFromEnum(inst)].un_op, "sin", .none),
            .cos         => try airUnBuiltinCall(f, inst, air_datas[@intFromEnum(inst)].un_op, "cos", .none),
            .tan         => try airUnBuiltinCall(f, inst, air_datas[@intFromEnum(inst)].un_op, "tan", .none),
            .exp         => try airUnBuiltinCall(f, inst, air_datas[@intFromEnum(inst)].un_op, "exp", .none),
            .exp2        => try airUnBuiltinCall(f, inst, air_datas[@intFromEnum(inst)].un_op, "exp2", .none),
            .log         => try airUnBuiltinCall(f, inst, air_datas[@intFromEnum(inst)].un_op, "log", .none),
            .log2        => try airUnBuiltinCall(f, inst, air_datas[@intFromEnum(inst)].un_op, "log2", .none),
            .log10       => try airUnBuiltinCall(f, inst, air_datas[@intFromEnum(inst)].un_op, "log10", .none),
            .floor       => try airUnBuiltinCall(f, inst, air_datas[@intFromEnum(inst)].un_op, "floor", .none),
            .ceil        => try airUnBuiltinCall(f, inst, air_datas[@intFromEnum(inst)].un_op, "ceil", .none),
            .round       => try airUnBuiltinCall(f, inst, air_datas[@intFromEnum(inst)].un_op, "round", .none),
            .trunc_float => try airUnBuiltinCall(f, inst, air_datas[@intFromEnum(inst)].un_op, "trunc", .none),

            .mul_add => try airMulAdd(f, inst),

            .add_with_overflow => try airOverflow(f, inst, "add", .bits),
            .sub_with_overflow => try airOverflow(f, inst, "sub", .bits),
            .mul_with_overflow => try airOverflow(f, inst, "mul", .bits),
            .shl_with_overflow => try airOverflow(f, inst, "shl", .bits),

            .min => try airMinMax(f, inst, '<', "min"),
            .max => try airMinMax(f, inst, '>', "max"),

            .slice => try airSlice(f, inst),

            .cmp_gt  => try airCmpOp(f, inst, air_datas[@intFromEnum(inst)].bin_op, .gt),
            .cmp_gte => try airCmpOp(f, inst, air_datas[@intFromEnum(inst)].bin_op, .gte),
            .cmp_lt  => try airCmpOp(f, inst, air_datas[@intFromEnum(inst)].bin_op, .lt),
            .cmp_lte => try airCmpOp(f, inst, air_datas[@intFromEnum(inst)].bin_op, .lte),

            .cmp_eq  => try airEquality(f, inst, .eq),
            .cmp_neq => try airEquality(f, inst, .neq),

            .cmp_vector => blk: {
                const ty_pl = air_datas[@intFromEnum(inst)].ty_pl;
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

            .optional_payload         => try airOptionalPayload(f, inst, false),
            .optional_payload_ptr     => try airOptionalPayload(f, inst, true),
            .optional_payload_ptr_set => try airOptionalPayloadPtrSet(f, inst),
            .wrap_optional            => try airWrapOptional(f, inst),

            .is_err          => try airIsErr(f, inst, false, "!="),
            .is_non_err      => try airIsErr(f, inst, false, "=="),
            .is_err_ptr      => try airIsErr(f, inst, true, "!="),
            .is_non_err_ptr  => try airIsErr(f, inst, true, "=="),

            .is_null         => try airIsNull(f, inst, .eq, false),
            .is_non_null     => try airIsNull(f, inst, .neq, false),
            .is_null_ptr     => try airIsNull(f, inst, .eq, true),
            .is_non_null_ptr => try airIsNull(f, inst, .neq, true),

            .alloc            => try airAlloc(f, inst),
            .ret_ptr          => try airRetPtr(f, inst),
            .assembly         => try airAsm(f, inst),
            .bitcast          => try airBitcast(f, inst),
            .intcast          => try airIntCast(f, inst),
            .trunc            => try airTrunc(f, inst),
            .int_from_bool      => try airIntFromBool(f, inst),
            .load             => try airLoad(f, inst),
            .store            => try airStore(f, inst, false),
            .store_safe       => try airStore(f, inst, true),
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
            .clz              => try airUnBuiltinCall(f, inst, air_datas[@intFromEnum(inst)].ty_op.operand, "clz", .bits),
            .ctz              => try airUnBuiltinCall(f, inst, air_datas[@intFromEnum(inst)].ty_op.operand, "ctz", .bits),
            .popcount         => try airUnBuiltinCall(f, inst, air_datas[@intFromEnum(inst)].ty_op.operand, "popcount", .bits),
            .byte_swap        => try airUnBuiltinCall(f, inst, air_datas[@intFromEnum(inst)].ty_op.operand, "byte_swap", .bits),
            .bit_reverse      => try airUnBuiltinCall(f, inst, air_datas[@intFromEnum(inst)].ty_op.operand, "bit_reverse", .bits),
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

            .@"try"       => try airTry(f, inst),
            .try_cold     => try airTry(f, inst),
            .try_ptr      => try airTryPtr(f, inst),
            .try_ptr_cold => try airTryPtr(f, inst),

            .dbg_stmt => try airDbgStmt(f, inst),
            .dbg_var_ptr, .dbg_var_val, .dbg_arg_inline => try airDbgVar(f, inst),

            .float_from_int,
            .int_from_float,
            .fptrunc,
            .fpext,
            => try airFloatCast(f, inst),

            .int_from_ptr => try airIntFromPtr(f, inst),

            .atomic_store_unordered => try airAtomicStore(f, inst, toMemoryOrder(.unordered)),
            .atomic_store_monotonic => try airAtomicStore(f, inst, toMemoryOrder(.monotonic)),
            .atomic_store_release   => try airAtomicStore(f, inst, toMemoryOrder(.release)),
            .atomic_store_seq_cst   => try airAtomicStore(f, inst, toMemoryOrder(.seq_cst)),

            .struct_field_ptr_index_0 => try airStructFieldPtrIndex(f, inst, 0),
            .struct_field_ptr_index_1 => try airStructFieldPtrIndex(f, inst, 1),
            .struct_field_ptr_index_2 => try airStructFieldPtrIndex(f, inst, 2),
            .struct_field_ptr_index_3 => try airStructFieldPtrIndex(f, inst, 3),

            .field_parent_ptr => try airFieldParentPtr(f, inst),

            .struct_field_val => try airStructFieldVal(f, inst),
            .slice_ptr        => try airSliceField(f, inst, false, "ptr"),
            .slice_len        => try airSliceField(f, inst, false, "len"),

            .ptr_slice_ptr_ptr => try airSliceField(f, inst, true, "ptr"),
            .ptr_slice_len_ptr => try airSliceField(f, inst, true, "len"),

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

            // Instructions that are known to always be `noreturn` based on their tag.
            .br              => return airBr(f, inst),
            .repeat          => return airRepeat(f, inst),
            .switch_dispatch => return airSwitchDispatch(f, inst),
            .cond_br         => return airCondBr(f, inst),
            .switch_br       => return airSwitchBr(f, inst, false),
            .loop_switch_br  => return airSwitchBr(f, inst, true),
            .loop            => return airLoop(f, inst),
            .ret             => return airRet(f, inst, false),
            .ret_safe        => return airRet(f, inst, false), // TODO
            .ret_load        => return airRet(f, inst, true),
            .trap            => return airTrap(f, f.object.writer()),
            .unreach         => return airUnreach(f),

            // Instructions which may be `noreturn`.
            .block => res: {
                const res = try airBlock(f, inst);
                if (f.typeOfIndex(inst).isNoReturn(zcu)) return;
                break :res res;
            },
            .dbg_inline_block => res: {
                const res = try airDbgInlineBlock(f, inst);
                if (f.typeOfIndex(inst).isNoReturn(zcu)) return;
                break :res res;
            },
            // TODO: calls should be in this category! The AIR we emit for them is a bit weird.
            // The instruction has type `noreturn`, but there are instructions (and maybe a safety
            // check) following nonetheless. The `unreachable` or safety check should be emitted by
            // backends instead.
            .call              => try airCall(f, inst, .auto),
            .call_always_tail  => .none,
            .call_never_tail   => try airCall(f, inst, .never_tail),
            .call_never_inline => try airCall(f, inst, .never_inline),

            // zig fmt: on
        };
        if (result_value == .new_local) {
            log.debug("map %{d} to t{d}", .{ inst, result_value.new_local });
        }
        try f.value_map.putNoClobber(inst.toRef(), switch (result_value) {
            .none => continue,
            .new_local => |local_index| .{ .local = local_index },
            else => result_value,
        });
    }
    unreachable;
}

fn airSliceField(f: *Function, inst: Air.Inst.Index, is_ptr: bool, field_name: []const u8) !CValue {
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const inst_ty = f.typeOfIndex(inst);
    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const a = try Assignment.start(f, writer, try f.ctypeFromType(inst_ty, .complete));
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
    const zcu = f.object.dg.pt.zcu;
    const inst_ty = f.typeOfIndex(inst);
    const bin_op = f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    if (!inst_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
        try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
        return .none;
    }

    const ptr = try f.resolveInst(bin_op.lhs);
    const index = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const a = try Assignment.start(f, writer, try f.ctypeFromType(inst_ty, .complete));
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
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = f.air.extraData(Air.Bin, ty_pl.payload).data;

    const inst_ty = f.typeOfIndex(inst);
    const ptr_ty = f.typeOf(bin_op.lhs);
    const elem_has_bits = ptr_ty.elemType2(zcu).hasRuntimeBitsIgnoreComptime(zcu);

    const ptr = try f.resolveInst(bin_op.lhs);
    const index = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const a = try Assignment.start(f, writer, try f.ctypeFromType(inst_ty, .complete));
    try f.writeCValue(writer, local, .Other);
    try a.assign(f, writer);
    try writer.writeByte('(');
    try f.renderType(writer, inst_ty);
    try writer.writeByte(')');
    if (elem_has_bits) try writer.writeByte('&');
    if (elem_has_bits and ptr_ty.ptrSize(zcu) == .One) {
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
    const zcu = f.object.dg.pt.zcu;
    const inst_ty = f.typeOfIndex(inst);
    const bin_op = f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    if (!inst_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
        try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
        return .none;
    }

    const slice = try f.resolveInst(bin_op.lhs);
    const index = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const a = try Assignment.start(f, writer, try f.ctypeFromType(inst_ty, .complete));
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
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = f.air.extraData(Air.Bin, ty_pl.payload).data;

    const inst_ty = f.typeOfIndex(inst);
    const slice_ty = f.typeOf(bin_op.lhs);
    const elem_ty = slice_ty.elemType2(zcu);
    const elem_has_bits = elem_ty.hasRuntimeBitsIgnoreComptime(zcu);

    const slice = try f.resolveInst(bin_op.lhs);
    const index = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const a = try Assignment.start(f, writer, try f.ctypeFromType(inst_ty, .complete));
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
    const zcu = f.object.dg.pt.zcu;
    const bin_op = f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const inst_ty = f.typeOfIndex(inst);
    if (!inst_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
        try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
        return .none;
    }

    const array = try f.resolveInst(bin_op.lhs);
    const index = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const a = try Assignment.start(f, writer, try f.ctypeFromType(inst_ty, .complete));
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
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const inst_ty = f.typeOfIndex(inst);
    const elem_ty = inst_ty.childType(zcu);
    if (!elem_ty.isFnOrHasRuntimeBitsIgnoreComptime(zcu)) return .{ .undef = inst_ty };

    const local = try f.allocLocalValue(.{
        .ctype = try f.ctypeFromType(elem_ty, .complete),
        .alignas = CType.AlignAs.fromAlignment(.{
            .@"align" = inst_ty.ptrInfo(zcu).flags.alignment,
            .abi = elem_ty.abiAlignment(zcu),
        }),
    });
    log.debug("%{d}: allocated unfreeable t{d}", .{ inst, local.new_local });
    try f.allocs.put(zcu.gpa, local.new_local, true);
    return .{ .local_ref = local.new_local };
}

fn airRetPtr(f: *Function, inst: Air.Inst.Index) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const inst_ty = f.typeOfIndex(inst);
    const elem_ty = inst_ty.childType(zcu);
    if (!elem_ty.isFnOrHasRuntimeBitsIgnoreComptime(zcu)) return .{ .undef = inst_ty };

    const local = try f.allocLocalValue(.{
        .ctype = try f.ctypeFromType(elem_ty, .complete),
        .alignas = CType.AlignAs.fromAlignment(.{
            .@"align" = inst_ty.ptrInfo(zcu).flags.alignment,
            .abi = elem_ty.abiAlignment(zcu),
        }),
    });
    log.debug("%{d}: allocated unfreeable t{d}", .{ inst, local.new_local });
    try f.allocs.put(zcu.gpa, local.new_local, true);
    return .{ .local_ref = local.new_local };
}

fn airArg(f: *Function, inst: Air.Inst.Index) !CValue {
    const inst_ty = f.typeOfIndex(inst);
    const inst_ctype = try f.ctypeFromType(inst_ty, .parameter);

    const i = f.next_arg_index;
    f.next_arg_index += 1;
    const result: CValue = if (inst_ctype.eql(try f.ctypeFromType(inst_ty, .complete)))
        .{ .arg = i }
    else
        .{ .arg_array = i };

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
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const ptr_ty = f.typeOf(ty_op.operand);
    const ptr_scalar_ty = ptr_ty.scalarType(zcu);
    const ptr_info = ptr_scalar_ty.ptrInfo(zcu);
    const src_ty = Type.fromInterned(ptr_info.child);

    if (!src_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
        try reap(f, inst, &.{ty_op.operand});
        return .none;
    }

    const operand = try f.resolveInst(ty_op.operand);

    try reap(f, inst, &.{ty_op.operand});

    const is_aligned = if (ptr_info.flags.alignment != .none)
        ptr_info.flags.alignment.order(src_ty.abiAlignment(zcu)).compare(.gte)
    else
        true;
    const is_array = lowersToArray(src_ty, pt);
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
        const host_ty = try pt.intType(.unsigned, host_bits);

        const bit_offset_ty = try pt.intType(.unsigned, Type.smallestUnsignedBits(host_bits - 1));
        const bit_offset_val = try pt.intValue(bit_offset_ty, ptr_info.packed_offset.bit_offset);

        const field_ty = try pt.intType(.unsigned, @as(u16, @intCast(src_ty.bitSize(zcu))));

        try f.writeCValue(writer, local, .Other);
        try v.elem(f, writer);
        try writer.writeAll(" = (");
        try f.renderType(writer, src_ty);
        try writer.writeAll(")zig_wrap_");
        try f.object.dg.renderTypeForBuiltinFnName(writer, field_ty);
        try writer.writeAll("((");
        try f.renderType(writer, field_ty);
        try writer.writeByte(')');
        const cant_cast = host_ty.isInt(zcu) and host_ty.bitSize(zcu) > 64;
        if (cant_cast) {
            if (field_ty.bitSize(zcu) > 64) return f.fail("TODO: C backend: implement casting between types > 64 bits", .{});
            try writer.writeAll("zig_lo_");
            try f.object.dg.renderTypeForBuiltinFnName(writer, host_ty);
            try writer.writeByte('(');
        }
        try writer.writeAll("zig_shr_");
        try f.object.dg.renderTypeForBuiltinFnName(writer, host_ty);
        try writer.writeByte('(');
        try f.writeCValueDeref(writer, operand);
        try v.elem(f, writer);
        try writer.print(", {})", .{try f.fmtIntLiteral(bit_offset_val)});
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

fn airRet(f: *Function, inst: Air.Inst.Index, is_ptr: bool) !void {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const un_op = f.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const writer = f.object.writer();
    const op_inst = un_op.toIndex();
    const op_ty = f.typeOf(un_op);
    const ret_ty = if (is_ptr) op_ty.childType(zcu) else op_ty;
    const ret_ctype = try f.ctypeFromType(ret_ty, .parameter);

    if (op_inst != null and f.air.instructions.items(.tag)[@intFromEnum(op_inst.?)] == .call_always_tail) {
        try reap(f, inst, &.{un_op});
        _ = try airCall(f, op_inst.?, .always_tail);
    } else if (ret_ctype.index != .void) {
        const operand = try f.resolveInst(un_op);
        try reap(f, inst, &.{un_op});
        var deref = is_ptr;
        const is_array = lowersToArray(ret_ty, pt);
        const ret_val = if (is_array) ret_val: {
            const array_local = try f.allocAlignedLocal(inst, .{
                .ctype = ret_ctype,
                .alignas = CType.AlignAs.fromAbiAlignment(ret_ty.abiAlignment(zcu)),
            });
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
}

fn airIntCast(f: *Function, inst: Air.Inst.Index) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});

    const inst_ty = f.typeOfIndex(inst);
    const inst_scalar_ty = inst_ty.scalarType(zcu);
    const operand_ty = f.typeOf(ty_op.operand);
    const scalar_ty = operand_ty.scalarType(zcu);

    if (f.object.dg.intCastIsNoop(inst_scalar_ty, scalar_ty)) return f.moveCValue(inst, inst_ty, operand);

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const v = try Vectorize.start(f, inst, writer, operand_ty);
    const a = try Assignment.start(f, writer, try f.ctypeFromType(scalar_ty, .complete));
    try f.writeCValue(writer, local, .Other);
    try v.elem(f, writer);
    try a.assign(f, writer);
    try f.renderIntCast(writer, inst_scalar_ty, operand, v, scalar_ty, .Other);
    try a.end(f, writer);
    try v.end(f, inst, writer);
    return local;
}

fn airTrunc(f: *Function, inst: Air.Inst.Index) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});

    const inst_ty = f.typeOfIndex(inst);
    const inst_scalar_ty = inst_ty.scalarType(zcu);
    const dest_int_info = inst_scalar_ty.intInfo(zcu);
    const dest_bits = dest_int_info.bits;
    const dest_c_bits = toCIntBits(dest_bits) orelse
        return f.fail("TODO: C backend: implement integer types larger than 128 bits", .{});
    const operand_ty = f.typeOf(ty_op.operand);
    const scalar_ty = operand_ty.scalarType(zcu);
    const scalar_int_info = scalar_ty.intInfo(zcu);

    const need_cast = dest_c_bits < 64;
    const need_lo = scalar_int_info.bits > 64 and dest_bits <= 64;
    const need_mask = dest_bits < 8 or !std.math.isPowerOfTwo(dest_bits);
    if (!need_cast and !need_lo and !need_mask) return f.moveCValue(inst, inst_ty, operand);

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const v = try Vectorize.start(f, inst, writer, operand_ty);
    const a = try Assignment.start(f, writer, try f.ctypeFromType(inst_scalar_ty, .complete));
    try f.writeCValue(writer, local, .Other);
    try v.elem(f, writer);
    try a.assign(f, writer);
    if (need_cast) {
        try writer.writeByte('(');
        try f.renderType(writer, inst_scalar_ty);
        try writer.writeByte(')');
    }
    if (need_lo) {
        try writer.writeAll("zig_lo_");
        try f.object.dg.renderTypeForBuiltinFnName(writer, scalar_ty);
        try writer.writeByte('(');
    }
    if (!need_mask) {
        try f.writeCValue(writer, operand, .Other);
        try v.elem(f, writer);
    } else switch (dest_int_info.signedness) {
        .unsigned => {
            try writer.writeAll("zig_and_");
            try f.object.dg.renderTypeForBuiltinFnName(writer, scalar_ty);
            try writer.writeByte('(');
            try f.writeCValue(writer, operand, .FunctionArgument);
            try v.elem(f, writer);
            try writer.print(", {x})", .{
                try f.fmtIntLiteral(try inst_scalar_ty.maxIntScalar(pt, scalar_ty)),
            });
        },
        .signed => {
            const c_bits = toCIntBits(scalar_int_info.bits) orelse
                return f.fail("TODO: C backend: implement integer types larger than 128 bits", .{});
            const shift_val = try pt.intValue(Type.u8, c_bits - dest_bits);

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
            try writer.print(", {})", .{try f.fmtIntLiteral(shift_val)});
            if (c_bits == 128) try writer.writeByte(')');
            try writer.print(", {})", .{try f.fmtIntLiteral(shift_val)});
        },
    }
    if (need_lo) try writer.writeByte(')');
    try a.end(f, writer);
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
    const a = try Assignment.start(f, writer, try f.ctypeFromType(inst_ty, .complete));
    try f.writeCValue(writer, local, .Other);
    try a.assign(f, writer);
    try f.writeCValue(writer, operand, .Other);
    try a.end(f, writer);
    return local;
}

fn airStore(f: *Function, inst: Air.Inst.Index, safety: bool) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    // *a = b;
    const bin_op = f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const ptr_ty = f.typeOf(bin_op.lhs);
    const ptr_scalar_ty = ptr_ty.scalarType(zcu);
    const ptr_info = ptr_scalar_ty.ptrInfo(zcu);

    const ptr_val = try f.resolveInst(bin_op.lhs);
    const src_ty = f.typeOf(bin_op.rhs);

    const val_is_undef = if (try f.air.value(bin_op.rhs, pt)) |v| v.isUndefDeep(zcu) else false;

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
        ptr_info.flags.alignment.order(src_ty.abiAlignment(zcu)).compare(.gte)
    else
        true;
    const is_array = lowersToArray(Type.fromInterned(ptr_info.child), pt);
    const need_memcpy = !is_aligned or is_array;

    const src_val = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const src_scalar_ctype = try f.ctypeFromType(src_ty.scalarType(zcu), .complete);
    const writer = f.object.writer();
    if (need_memcpy) {
        // For this memcpy to safely work we need the rhs to have the same
        // underlying type as the lhs (i.e. they must both be arrays of the same underlying type).
        assert(src_ty.eql(Type.fromInterned(ptr_info.child), zcu));

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

        const v = try Vectorize.start(f, inst, writer, ptr_ty);
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
        try f.freeCValue(inst, array_src);
        try writer.writeAll(";\n");
        try v.end(f, inst, writer);
    } else if (ptr_info.packed_offset.host_size > 0 and ptr_info.flags.vector_index == .none) {
        const host_bits = ptr_info.packed_offset.host_size * 8;
        const host_ty = try pt.intType(.unsigned, host_bits);

        const bit_offset_ty = try pt.intType(.unsigned, Type.smallestUnsignedBits(host_bits - 1));
        const bit_offset_val = try pt.intValue(bit_offset_ty, ptr_info.packed_offset.bit_offset);

        const src_bits = src_ty.bitSize(zcu);

        const ExpectedContents = [BigInt.Managed.default_capacity]BigIntLimb;
        var stack align(@alignOf(ExpectedContents)) =
            std.heap.stackFallback(@sizeOf(ExpectedContents), f.object.dg.gpa);

        var mask = try BigInt.Managed.initCapacity(stack.get(), BigInt.calcTwosCompLimbCount(host_bits));
        defer mask.deinit();

        try mask.setTwosCompIntLimit(.max, .unsigned, @as(usize, @intCast(src_bits)));
        try mask.shiftLeft(&mask, ptr_info.packed_offset.bit_offset);
        try mask.bitNotWrap(&mask, .unsigned, host_bits);

        const mask_val = try pt.intValue_big(host_ty, mask.toConst());

        const v = try Vectorize.start(f, inst, writer, ptr_ty);
        const a = try Assignment.start(f, writer, src_scalar_ctype);
        try f.writeCValueDeref(writer, ptr_val);
        try v.elem(f, writer);
        try a.assign(f, writer);
        try writer.writeAll("zig_or_");
        try f.object.dg.renderTypeForBuiltinFnName(writer, host_ty);
        try writer.writeAll("(zig_and_");
        try f.object.dg.renderTypeForBuiltinFnName(writer, host_ty);
        try writer.writeByte('(');
        try f.writeCValueDeref(writer, ptr_val);
        try v.elem(f, writer);
        try writer.print(", {x}), zig_shl_", .{try f.fmtIntLiteral(mask_val)});
        try f.object.dg.renderTypeForBuiltinFnName(writer, host_ty);
        try writer.writeByte('(');
        const cant_cast = host_ty.isInt(zcu) and host_ty.bitSize(zcu) > 64;
        if (cant_cast) {
            if (src_ty.bitSize(zcu) > 64) return f.fail("TODO: C backend: implement casting between types > 64 bits", .{});
            try writer.writeAll("zig_make_");
            try f.object.dg.renderTypeForBuiltinFnName(writer, host_ty);
            try writer.writeAll("(0, ");
        } else {
            try writer.writeByte('(');
            try f.renderType(writer, host_ty);
            try writer.writeByte(')');
        }

        if (src_ty.isPtrAtRuntime(zcu)) {
            try writer.writeByte('(');
            try f.renderType(writer, Type.usize);
            try writer.writeByte(')');
        }
        try f.writeCValue(writer, src_val, .Other);
        try v.elem(f, writer);
        if (cant_cast) try writer.writeByte(')');
        try writer.print(", {}))", .{try f.fmtIntLiteral(bit_offset_val)});
        try a.end(f, writer);
        try v.end(f, inst, writer);
    } else {
        switch (ptr_val) {
            .local_ref => |ptr_local_index| switch (src_val) {
                .new_local, .local => |src_local_index| if (ptr_local_index == src_local_index)
                    return .none,
                else => {},
            },
            else => {},
        }
        const v = try Vectorize.start(f, inst, writer, ptr_ty);
        const a = try Assignment.start(f, writer, src_scalar_ctype);
        try f.writeCValueDeref(writer, ptr_val);
        try v.elem(f, writer);
        try a.assign(f, writer);
        try f.writeCValue(writer, src_val, .Other);
        try v.elem(f, writer);
        try a.end(f, writer);
        try v.end(f, inst, writer);
    }
    return .none;
}

fn airOverflow(f: *Function, inst: Air.Inst.Index, operation: []const u8, info: BuiltinInfo) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = f.air.extraData(Air.Bin, ty_pl.payload).data;

    const lhs = try f.resolveInst(bin_op.lhs);
    const rhs = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const inst_ty = f.typeOfIndex(inst);
    const operand_ty = f.typeOf(bin_op.lhs);
    const scalar_ty = operand_ty.scalarType(zcu);

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
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const operand_ty = f.typeOf(ty_op.operand);
    const scalar_ty = operand_ty.scalarType(zcu);
    if (scalar_ty.toIntern() != .bool_type) return try airUnBuiltinCall(f, inst, ty_op.operand, "not", .bits);

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
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const bin_op = f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const operand_ty = f.typeOf(bin_op.lhs);
    const scalar_ty = operand_ty.scalarType(zcu);
    if ((scalar_ty.isInt(zcu) and scalar_ty.bitSize(zcu) > 64) or scalar_ty.isRuntimeFloat())
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
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const lhs_ty = f.typeOf(data.lhs);
    const scalar_ty = lhs_ty.scalarType(zcu);

    const scalar_bits = scalar_ty.bitSize(zcu);
    if (scalar_ty.isInt(zcu) and scalar_bits > 64)
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
    const need_cast = lhs_ty.isSinglePointer(zcu) or rhs_ty.isSinglePointer(zcu);
    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const v = try Vectorize.start(f, inst, writer, lhs_ty);
    try f.writeCValue(writer, local, .Other);
    try v.elem(f, writer);
    try writer.writeAll(" = ");
    if (need_cast) try writer.writeAll("(void*)");
    try f.writeCValue(writer, lhs, .Other);
    try v.elem(f, writer);
    try writer.writeAll(compareOperatorC(operator));
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
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const ctype_pool = &f.object.dg.ctype_pool;
    const bin_op = f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const operand_ty = f.typeOf(bin_op.lhs);
    const operand_bits = operand_ty.bitSize(zcu);
    if (operand_ty.isAbiInt(zcu) and operand_bits > 64)
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
    const local = try f.allocLocal(inst, Type.bool);
    const a = try Assignment.start(f, writer, CType.bool);
    try f.writeCValue(writer, local, .Other);
    try a.assign(f, writer);

    const operand_ctype = try f.ctypeFromType(operand_ty, .complete);
    switch (operand_ctype.info(ctype_pool)) {
        .basic, .pointer => {
            try f.writeCValue(writer, lhs, .Other);
            try writer.writeAll(compareOperatorC(operator));
            try f.writeCValue(writer, rhs, .Other);
        },
        .aligned, .array, .vector, .fwd_decl, .function => unreachable,
        .aggregate => |aggregate| if (aggregate.fields.len == 2 and
            (aggregate.fields.at(0, ctype_pool).name.index == .is_null or
            aggregate.fields.at(1, ctype_pool).name.index == .is_null))
        {
            try f.writeCValueMember(writer, lhs, .{ .identifier = "is_null" });
            try writer.writeAll(" || ");
            try f.writeCValueMember(writer, rhs, .{ .identifier = "is_null" });
            try writer.writeAll(" ? ");
            try f.writeCValueMember(writer, lhs, .{ .identifier = "is_null" });
            try writer.writeAll(compareOperatorC(operator));
            try f.writeCValueMember(writer, rhs, .{ .identifier = "is_null" });
            try writer.writeAll(" : ");
            try f.writeCValueMember(writer, lhs, .{ .identifier = "payload" });
            try writer.writeAll(compareOperatorC(operator));
            try f.writeCValueMember(writer, rhs, .{ .identifier = "payload" });
        } else for (0..aggregate.fields.len) |field_index| {
            if (field_index > 0) try writer.writeAll(switch (operator) {
                .lt, .lte, .gte, .gt => unreachable,
                .eq => " && ",
                .neq => " || ",
            });
            const field_name: CValue = .{
                .ctype_pool_string = aggregate.fields.at(field_index, ctype_pool).name,
            };
            try f.writeCValueMember(writer, lhs, field_name);
            try writer.writeAll(compareOperatorC(operator));
            try f.writeCValueMember(writer, rhs, field_name);
        },
    }
    try a.end(f, writer);

    return local;
}

fn airCmpLtErrorsLen(f: *Function, inst: Air.Inst.Index) !CValue {
    const un_op = f.air.instructions.items(.data)[@intFromEnum(inst)].un_op;

    const operand = try f.resolveInst(un_op);
    try reap(f, inst, &.{un_op});

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, Type.bool);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = ");
    try f.writeCValue(writer, operand, .Other);
    try writer.print(" < sizeof({ }) / sizeof(*{0 });\n", .{fmtIdent("zig_errorName")});
    return local;
}

fn airPtrAddSub(f: *Function, inst: Air.Inst.Index, operator: u8) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = f.air.extraData(Air.Bin, ty_pl.payload).data;

    const lhs = try f.resolveInst(bin_op.lhs);
    const rhs = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const inst_ty = f.typeOfIndex(inst);
    const inst_scalar_ty = inst_ty.scalarType(zcu);
    const elem_ty = inst_scalar_ty.elemType2(zcu);
    if (!elem_ty.hasRuntimeBitsIgnoreComptime(zcu)) return f.moveCValue(inst, inst_ty, lhs);
    const inst_scalar_ctype = try f.ctypeFromType(inst_scalar_ty, .complete);

    const local = try f.allocLocal(inst, inst_ty);
    const writer = f.object.writer();
    const v = try Vectorize.start(f, inst, writer, inst_ty);
    const a = try Assignment.start(f, writer, inst_scalar_ctype);
    try f.writeCValue(writer, local, .Other);
    try v.elem(f, writer);
    try a.assign(f, writer);
    // We must convert to and from integer types to prevent UB if the operation
    // results in a NULL pointer, or if LHS is NULL. The operation is only UB
    // if the result is NULL and then dereferenced.
    try writer.writeByte('(');
    try f.renderCType(writer, inst_scalar_ctype);
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
    try a.end(f, writer);
    try v.end(f, inst, writer);
    return local;
}

fn airMinMax(f: *Function, inst: Air.Inst.Index, operator: u8, operation: []const u8) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const bin_op = f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const inst_ty = f.typeOfIndex(inst);
    const inst_scalar_ty = inst_ty.scalarType(zcu);

    if ((inst_scalar_ty.isInt(zcu) and inst_scalar_ty.bitSize(zcu) > 64) or inst_scalar_ty.isRuntimeFloat())
        return try airBinBuiltinCall(f, inst, operation, .none);

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
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = f.air.extraData(Air.Bin, ty_pl.payload).data;

    const ptr = try f.resolveInst(bin_op.lhs);
    const len = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const inst_ty = f.typeOfIndex(inst);
    const ptr_ty = inst_ty.slicePtrFieldType(zcu);

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    {
        const a = try Assignment.start(f, writer, try f.ctypeFromType(ptr_ty, .complete));
        try f.writeCValueMember(writer, local, .{ .identifier = "ptr" });
        try a.assign(f, writer);
        try f.writeCValue(writer, ptr, .Other);
        try a.end(f, writer);
    }
    {
        const a = try Assignment.start(f, writer, CType.usize);
        try f.writeCValueMember(writer, local, .{ .identifier = "len" });
        try a.assign(f, writer);
        try f.writeCValue(writer, len, .Initializer);
        try a.end(f, writer);
    }
    return local;
}

fn airCall(
    f: *Function,
    inst: Air.Inst.Index,
    modifier: std.builtin.CallModifier,
) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
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
        const arg_ctype = try f.ctypeFromType(arg_ty, .parameter);
        if (arg_ctype.index == .void) {
            resolved_arg.* = .none;
            continue;
        }
        resolved_arg.* = try f.resolveInst(arg);
        if (!arg_ctype.eql(try f.ctypeFromType(arg_ty, .complete))) {
            const array_local = try f.allocAlignedLocal(inst, .{
                .ctype = arg_ctype,
                .alignas = CType.AlignAs.fromAbiAlignment(arg_ty.abiAlignment(zcu)),
            });
            try writer.writeAll("memcpy(");
            try f.writeCValueMember(writer, array_local, .{ .identifier = "array" });
            try writer.writeAll(", ");
            try f.writeCValue(writer, resolved_arg.*, .FunctionArgument);
            try writer.writeAll(", sizeof(");
            try f.renderCType(writer, arg_ctype);
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
    const fn_info = zcu.typeToFunc(switch (callee_ty.zigTypeTag(zcu)) {
        .@"fn" => callee_ty,
        .pointer => callee_ty.childType(zcu),
        else => unreachable,
    }).?;
    const ret_ty = Type.fromInterned(fn_info.return_type);
    const ret_ctype: CType = if (ret_ty.isNoReturn(zcu))
        CType.void
    else
        try f.ctypeFromType(ret_ty, .parameter);

    const result_local = result: {
        if (modifier == .always_tail) {
            try writer.writeAll("zig_always_tail return ");
            break :result .none;
        } else if (ret_ctype.index == .void) {
            break :result .none;
        } else if (f.liveness.isUnused(inst)) {
            try writer.writeByte('(');
            try f.renderCType(writer, CType.void);
            try writer.writeByte(')');
            break :result .none;
        } else {
            const local = try f.allocAlignedLocal(inst, .{
                .ctype = ret_ctype,
                .alignas = CType.AlignAs.fromAbiAlignment(ret_ty.abiAlignment(zcu)),
            });
            try f.writeCValue(writer, local, .Other);
            try writer.writeAll(" = ");
            break :result local;
        }
    };

    callee: {
        known: {
            const callee_val = (try f.air.value(pl_op.operand, pt)) orelse break :known;
            const fn_nav = switch (zcu.intern_pool.indexToKey(callee_val.toIntern())) {
                .@"extern" => |@"extern"| @"extern".owner_nav,
                .func => |func| func.owner_nav,
                .ptr => |ptr| if (ptr.byte_offset == 0) switch (ptr.base_addr) {
                    .nav => |nav| nav,
                    else => break :known,
                } else break :known,
                else => break :known,
            };
            switch (modifier) {
                .auto, .always_tail => try f.object.dg.renderNavName(writer, fn_nav),
                inline .never_tail, .never_inline => |m| try writer.writeAll(try f.getLazyFnName(@unionInit(LazyFnKey, @tagName(m), fn_nav))),
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
    var need_comma = false;
    for (resolved_args) |resolved_arg| {
        if (resolved_arg == .none) continue;
        if (need_comma) try writer.writeAll(", ");
        need_comma = true;
        try f.writeCValue(writer, resolved_arg, .FunctionArgument);
        try f.freeCValue(inst, resolved_arg);
    }
    try writer.writeAll(");\n");

    const result = result: {
        if (result_local == .none or !lowersToArray(ret_ty, pt))
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

fn airDbgInlineBlock(f: *Function, inst: Air.Inst.Index) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = f.air.extraData(Air.DbgInlineBlock, ty_pl.payload);
    const owner_nav = ip.getNav(zcu.funcInfo(extra.data.func).owner_nav);
    const writer = f.object.writer();
    try writer.print("/* inline:{} */\n", .{owner_nav.fqn.fmt(&zcu.intern_pool)});
    return lowerBlock(f, inst, @ptrCast(f.air.extra[extra.end..][0..extra.data.body_len]));
}

fn airDbgVar(f: *Function, inst: Air.Inst.Index) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const tag = f.air.instructions.items(.tag)[@intFromEnum(inst)];
    const pl_op = f.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const name: Air.NullTerminatedString = @enumFromInt(pl_op.payload);
    const operand_is_undef = if (try f.air.value(pl_op.operand, pt)) |v| v.isUndefDeep(zcu) else false;
    if (!operand_is_undef) _ = try f.resolveInst(pl_op.operand);

    try reap(f, inst, &.{pl_op.operand});
    const writer = f.object.writer();
    try writer.print("/* {s}:{s} */\n", .{ @tagName(tag), name.toSlice(f.air) });
    return .none;
}

fn airBlock(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = f.air.extraData(Air.Block, ty_pl.payload);
    return lowerBlock(f, inst, @ptrCast(f.air.extra[extra.end..][0..extra.data.body_len]));
}

fn lowerBlock(f: *Function, inst: Air.Inst.Index, body: []const Air.Inst.Index) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const liveness_block = f.liveness.getBlock(inst);

    const block_id: usize = f.next_block_index;
    f.next_block_index += 1;
    const writer = f.object.writer();

    const inst_ty = f.typeOfIndex(inst);
    const result = if (inst_ty.hasRuntimeBitsIgnoreComptime(zcu) and !f.liveness.isUnused(inst))
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
    if (!f.typeOfIndex(inst).isNoReturn(zcu)) {
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
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = f.air.extraData(Air.TryPtr, ty_pl.payload);
    const body: []const Air.Inst.Index = @ptrCast(f.air.extra[extra.end..][0..extra.data.body_len]);
    const err_union_ty = f.typeOf(extra.data.ptr).childType(zcu);
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
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const err_union = try f.resolveInst(operand);
    const inst_ty = f.typeOfIndex(inst);
    const liveness_condbr = f.liveness.getCondBr(inst);
    const writer = f.object.writer();
    const payload_ty = err_union_ty.errorUnionPayload(zcu);
    const payload_has_bits = payload_ty.hasRuntimeBitsIgnoreComptime(zcu);

    if (!err_union_ty.errorUnionSet(zcu).errorSetIsEmpty(zcu)) {
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
    const a = try Assignment.start(f, writer, try f.ctypeFromType(inst_ty, .complete));
    try f.writeCValue(writer, local, .Other);
    try a.assign(f, writer);
    if (is_ptr) {
        try writer.writeByte('&');
        try f.writeCValueDerefMember(writer, err_union, .{ .identifier = "payload" });
    } else try f.writeCValueMember(writer, err_union, .{ .identifier = "payload" });
    try a.end(f, writer);
    return local;
}

fn airBr(f: *Function, inst: Air.Inst.Index) !void {
    const branch = f.air.instructions.items(.data)[@intFromEnum(inst)].br;
    const block = f.blocks.get(branch.block_inst).?;
    const result = block.result;
    const writer = f.object.writer();

    // If result is .none then the value of the block is unused.
    if (result != .none) {
        const operand_ty = f.typeOf(branch.operand);
        const operand = try f.resolveInst(branch.operand);
        try reap(f, inst, &.{branch.operand});

        const a = try Assignment.start(f, writer, try f.ctypeFromType(operand_ty, .complete));
        try f.writeCValue(writer, result, .Other);
        try a.assign(f, writer);
        try f.writeCValue(writer, operand, .Other);
        try a.end(f, writer);
    }

    try writer.print("goto zig_block_{d};\n", .{block.block_id});
}

fn airRepeat(f: *Function, inst: Air.Inst.Index) !void {
    const repeat = f.air.instructions.items(.data)[@intFromEnum(inst)].repeat;
    const writer = f.object.writer();
    try writer.print("goto zig_loop_{d};\n", .{@intFromEnum(repeat.loop_inst)});
}

fn airSwitchDispatch(f: *Function, inst: Air.Inst.Index) !void {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const br = f.air.instructions.items(.data)[@intFromEnum(inst)].br;
    const writer = f.object.writer();

    if (try f.air.value(br.operand, pt)) |cond_val| {
        // Comptime-known dispatch. Iterate the cases to find the correct
        // one, and branch directly to the corresponding case.
        const switch_br = f.air.unwrapSwitch(br.block_inst);
        var it = switch_br.iterateCases();
        const target_case_idx: u32 = target: while (it.next()) |case| {
            for (case.items) |item| {
                const val = Value.fromInterned(item.toInterned().?);
                if (cond_val.compareHetero(.eq, val, zcu)) break :target case.idx;
            }
            for (case.ranges) |range| {
                const low = Value.fromInterned(range[0].toInterned().?);
                const high = Value.fromInterned(range[1].toInterned().?);
                if (cond_val.compareHetero(.gte, low, zcu) and
                    cond_val.compareHetero(.lte, high, zcu))
                {
                    break :target case.idx;
                }
            }
        } else switch_br.cases_len;
        try writer.print("goto zig_switch_{d}_dispatch_{d};\n", .{ @intFromEnum(br.block_inst), target_case_idx });
        return;
    }

    // Runtime-known dispatch. Set the switch condition, and branch back.
    const cond = try f.resolveInst(br.operand);
    const cond_local = f.loop_switch_conds.get(br.block_inst).?;
    try f.writeCValue(writer, .{ .local = cond_local }, .Other);
    try writer.writeAll(" = ");
    try f.writeCValue(writer, cond, .Initializer);
    try writer.writeAll(";\n");
    try writer.print("goto zig_switch_{d}_loop;", .{@intFromEnum(br.block_inst)});
}

fn airBitcast(f: *Function, inst: Air.Inst.Index) !CValue {
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const inst_ty = f.typeOfIndex(inst);

    const operand = try f.resolveInst(ty_op.operand);
    const operand_ty = f.typeOf(ty_op.operand);

    const bitcasted = try bitcast(f, inst_ty, operand, operand_ty);
    try reap(f, inst, &.{ty_op.operand});
    return f.moveCValue(inst, inst_ty, bitcasted);
}

fn bitcast(f: *Function, dest_ty: Type, operand: CValue, operand_ty: Type) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const target = &f.object.dg.mod.resolved_target.result;
    const ctype_pool = &f.object.dg.ctype_pool;
    const writer = f.object.writer();

    if (operand_ty.isAbiInt(zcu) and dest_ty.isAbiInt(zcu)) {
        const src_info = dest_ty.intInfo(zcu);
        const dest_info = operand_ty.intInfo(zcu);
        if (src_info.signedness == dest_info.signedness and
            src_info.bits == dest_info.bits) return operand;
    }

    if (dest_ty.isPtrAtRuntime(zcu) and operand_ty.isPtrAtRuntime(zcu)) {
        const local = try f.allocLocal(null, dest_ty);
        try f.writeCValue(writer, local, .Other);
        try writer.writeAll(" = (");
        try f.renderType(writer, dest_ty);
        try writer.writeByte(')');
        try f.writeCValue(writer, operand, .Other);
        try writer.writeAll(";\n");
        return local;
    }

    const operand_lval = if (operand == .constant) blk: {
        const operand_local = try f.allocLocal(null, operand_ty);
        try f.writeCValue(writer, operand_local, .Other);
        if (operand_ty.isAbiInt(zcu)) {
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
        if (dest_ty.abiSize(zcu) <= operand_ty.abiSize(zcu)) dest_ty else operand_ty,
    );
    try writer.writeAll("));\n");

    // Ensure padding bits have the expected value.
    if (dest_ty.isAbiInt(zcu)) {
        const dest_ctype = try f.ctypeFromType(dest_ty, .complete);
        const dest_info = dest_ty.intInfo(zcu);
        var bits: u16 = dest_info.bits;
        var wrap_ctype: ?CType = null;
        var need_bitcasts = false;

        try f.writeCValue(writer, local, .Other);
        switch (dest_ctype.info(ctype_pool)) {
            else => {},
            .array => |array_info| {
                try writer.print("[{d}]", .{switch (target.cpu.arch.endian()) {
                    .little => array_info.len - 1,
                    .big => 0,
                }});
                wrap_ctype = array_info.elem_ctype.toSignedness(dest_info.signedness);
                need_bitcasts = wrap_ctype.?.index == .zig_i128;
                bits -= 1;
                bits %= @as(u16, @intCast(f.byteSize(array_info.elem_ctype) * 8));
                bits += 1;
            },
        }
        try writer.writeAll(" = ");
        if (need_bitcasts) {
            try writer.writeAll("zig_bitCast_");
            try f.object.dg.renderCTypeForBuiltinFnName(writer, wrap_ctype.?.toUnsigned());
            try writer.writeByte('(');
        }
        try writer.writeAll("zig_wrap_");
        const info_ty = try pt.intType(dest_info.signedness, bits);
        if (wrap_ctype) |ctype|
            try f.object.dg.renderCTypeForBuiltinFnName(writer, ctype)
        else
            try f.object.dg.renderTypeForBuiltinFnName(writer, info_ty);
        try writer.writeByte('(');
        if (need_bitcasts) {
            try writer.writeAll("zig_bitCast_");
            try f.object.dg.renderCTypeForBuiltinFnName(writer, wrap_ctype.?);
            try writer.writeByte('(');
        }
        try f.writeCValue(writer, local, .Other);
        switch (dest_ctype.info(ctype_pool)) {
            else => {},
            .array => |array_info| try writer.print("[{d}]", .{
                switch (target.cpu.arch.endian()) {
                    .little => array_info.len - 1,
                    .big => 0,
                },
            }),
        }
        if (need_bitcasts) try writer.writeByte(')');
        try f.object.dg.renderBuiltinInfo(writer, info_ty, .bits);
        if (need_bitcasts) try writer.writeByte(')');
        try writer.writeAll(");\n");
    }

    try f.freeCValue(null, operand_lval);
    return local;
}

fn airTrap(f: *Function, writer: anytype) !void {
    // Not even allowed to call trap in a naked function.
    if (f.object.dg.is_naked_fn) return;
    try writer.writeAll("zig_trap();\n");
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

fn airUnreach(f: *Function) !void {
    // Not even allowed to call unreachable in a naked function.
    if (f.object.dg.is_naked_fn) return;
    try f.object.writer().writeAll("zig_unreachable();\n");
}

fn airLoop(f: *Function, inst: Air.Inst.Index) !void {
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const loop = f.air.extraData(Air.Block, ty_pl.payload);
    const body: []const Air.Inst.Index = @ptrCast(f.air.extra[loop.end..][0..loop.data.body_len]);
    const writer = f.object.writer();

    // `repeat` instructions matching this loop will branch to
    // this label. Since we need a label for arbitrary `repeat`
    // anyway, there's actually no need to use a "real" looping
    // construct at all!
    try writer.print("zig_loop_{d}:\n", .{@intFromEnum(inst)});
    try genBodyInner(f, body); // no need to restore state, we're noreturn
}

fn airCondBr(f: *Function, inst: Air.Inst.Index) !void {
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
}

fn airSwitchBr(f: *Function, inst: Air.Inst.Index, is_dispatch_loop: bool) !void {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const gpa = f.object.dg.gpa;
    const switch_br = f.air.unwrapSwitch(inst);
    const init_condition = try f.resolveInst(switch_br.operand);
    try reap(f, inst, &.{switch_br.operand});
    const condition_ty = f.typeOf(switch_br.operand);
    const writer = f.object.writer();

    // For dispatches, we will create a local alloc to contain the condition value.
    // This may not result in optimal codegen for switch loops, but it minimizes the
    // amount of C code we generate, which is probably more desirable here (and is simpler).
    const condition = if (is_dispatch_loop) cond: {
        const new_local = try f.allocLocal(inst, condition_ty);
        try f.copyCValue(try f.ctypeFromType(condition_ty, .complete), new_local, init_condition);
        try writer.print("zig_switch_{d}_loop:\n", .{@intFromEnum(inst)});
        try f.loop_switch_conds.put(gpa, inst, new_local.new_local);
        break :cond new_local;
    } else init_condition;

    defer if (is_dispatch_loop) {
        assert(f.loop_switch_conds.remove(inst));
    };

    try writer.writeAll("switch (");

    const lowered_condition_ty = if (condition_ty.toIntern() == .bool_type)
        Type.u1
    else if (condition_ty.isPtrAtRuntime(zcu))
        Type.usize
    else
        condition_ty;
    if (condition_ty.toIntern() != lowered_condition_ty.toIntern()) {
        try writer.writeByte('(');
        try f.renderType(writer, lowered_condition_ty);
        try writer.writeByte(')');
    }
    try f.writeCValue(writer, condition, .Other);
    try writer.writeAll(") {");
    f.object.indent_writer.pushIndent();

    const liveness = try f.liveness.getSwitchBr(gpa, inst, switch_br.cases_len + 1);
    defer gpa.free(liveness.deaths);

    var any_range_cases = false;
    var it = switch_br.iterateCases();
    while (it.next()) |case| {
        if (case.ranges.len > 0) {
            any_range_cases = true;
            continue;
        }
        for (case.items) |item| {
            try f.object.indent_writer.insertNewline();
            try writer.writeAll("case ");
            const item_value = try f.air.value(item, pt);
            // If `item_value` is a pointer with a known integer address, print the address
            // with no cast to avoid a warning.
            write_val: {
                if (condition_ty.isPtrAtRuntime(zcu)) {
                    if (item_value.?.getUnsignedInt(zcu)) |item_int| {
                        try writer.print("{}", .{try f.fmtIntLiteral(try pt.intValue(lowered_condition_ty, item_int))});
                        break :write_val;
                    }
                }
                if (condition_ty.isPtrAtRuntime(zcu)) {
                    try writer.writeByte('(');
                    try f.renderType(writer, Type.usize);
                    try writer.writeByte(')');
                }
                try f.object.dg.renderValue(writer, (try f.air.value(item, pt)).?, .Other);
            }
            try writer.writeByte(':');
        }
        try writer.writeAll(" {\n");
        f.object.indent_writer.pushIndent();
        if (is_dispatch_loop) {
            try writer.print("zig_switch_{d}_dispatch_{d}: ", .{ @intFromEnum(inst), case.idx });
        }
        try genBodyResolveState(f, inst, liveness.deaths[case.idx], case.body, true);
        f.object.indent_writer.popIndent();
        try writer.writeByte('}');

        // The case body must be noreturn so we don't need to insert a break.
    }

    const else_body = it.elseBody();
    try f.object.indent_writer.insertNewline();

    try writer.writeAll("default: ");
    if (any_range_cases) {
        // We will iterate the cases again to handle those with ranges, and generate
        // code using conditions rather than switch cases for such cases.
        it = switch_br.iterateCases();
        while (it.next()) |case| {
            if (case.ranges.len == 0) continue; // handled above

            try writer.writeAll("if (");
            for (case.items, 0..) |item, item_i| {
                if (item_i != 0) try writer.writeAll(" || ");
                try f.writeCValue(writer, condition, .Other);
                try writer.writeAll(" == ");
                try f.object.dg.renderValue(writer, (try f.air.value(item, pt)).?, .Other);
            }
            for (case.ranges, 0..) |range, range_i| {
                if (case.items.len != 0 or range_i != 0) try writer.writeAll(" || ");
                // "(x >= lower && x <= upper)"
                try writer.writeByte('(');
                try f.writeCValue(writer, condition, .Other);
                try writer.writeAll(" >= ");
                try f.object.dg.renderValue(writer, (try f.air.value(range[0], pt)).?, .Other);
                try writer.writeAll(" && ");
                try f.writeCValue(writer, condition, .Other);
                try writer.writeAll(" <= ");
                try f.object.dg.renderValue(writer, (try f.air.value(range[1], pt)).?, .Other);
                try writer.writeByte(')');
            }
            try writer.writeAll(") {\n");
            f.object.indent_writer.pushIndent();
            if (is_dispatch_loop) {
                try writer.print("zig_switch_{d}_dispatch_{d}: ", .{ @intFromEnum(inst), case.idx });
            }
            try genBodyResolveState(f, inst, liveness.deaths[case.idx], case.body, true);
            f.object.indent_writer.popIndent();
            try writer.writeByte('}');
        }
    }
    if (is_dispatch_loop) {
        try writer.print("zig_switch_{d}_dispatch_{d}: ", .{ @intFromEnum(inst), switch_br.cases_len });
    }
    if (else_body.len > 0) {
        // Note that this must be the last case, so we do not need to use `genBodyResolveState` since
        // the parent block will do it (because the case body is noreturn).
        for (liveness.deaths[liveness.deaths.len - 1]) |death| {
            try die(f, inst, death.toRef());
        }
        try genBody(f, else_body);
    } else {
        try writer.writeAll("zig_unreachable();");
    }
    try f.object.indent_writer.insertNewline();

    f.object.indent_writer.popIndent();
    try writer.writeAll("}\n");
}

fn asmInputNeedsLocal(f: *Function, constraint: []const u8, value: CValue) bool {
    const dg = f.object.dg;
    const target = &dg.mod.resolved_target.result;
    return switch (constraint[0]) {
        '{' => true,
        'i', 'r' => false,
        'I' => !target.cpu.arch.isArmOrThumb(),
        else => switch (value) {
            .constant => |val| switch (dg.pt.zcu.intern_pool.indexToKey(val.toIntern())) {
                .ptr => |ptr| if (ptr.byte_offset == 0) switch (ptr.base_addr) {
                    .nav => false,
                    else => true,
                } else true,
                else => true,
            },
            else => false,
        },
    };
}

fn airAsm(f: *Function, inst: Air.Inst.Index) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
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
        const inst_local = if (inst_ty.hasRuntimeBitsIgnoreComptime(zcu)) local: {
            const inst_local = try f.allocLocalValue(.{
                .ctype = try f.ctypeFromType(inst_ty, .complete),
                .alignas = CType.AlignAs.fromAbiAlignment(inst_ty.abiAlignment(zcu)),
            });
            if (f.wantSafety()) {
                try f.writeCValue(writer, inst_local, .Other);
                try writer.writeAll(" = ");
                try f.writeCValue(writer, .{ .undef = inst_ty }, .Other);
                try writer.writeAll(";\n");
            }
            break :local inst_local;
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
                const output_ty = if (output == .none) inst_ty else f.typeOf(output).childType(zcu);
                try writer.writeAll("register ");
                const output_local = try f.allocLocalValue(.{
                    .ctype = try f.ctypeFromType(output_ty, .complete),
                    .alignas = CType.AlignAs.fromAbiAlignment(output_ty.abiAlignment(zcu)),
                });
                try f.allocs.put(gpa, output_local.new_local, false);
                try f.object.dg.renderTypeAndName(writer, output_ty, output_local, .{}, .none, .complete);
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
                const input_local = try f.allocLocalValue(.{
                    .ctype = try f.ctypeFromType(input_ty, .complete),
                    .alignas = CType.AlignAs.fromAbiAlignment(input_ty.abiAlignment(zcu)),
                });
                try f.allocs.put(gpa, input_local.new_local, false);
                try f.object.dg.renderTypeAndName(writer, input_ty, input_local, Const, .none, .complete);
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
                try f.writeCValue(writer, inst_local, .FunctionArgument);
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
                    .{ .local_ref = inst_local.new_local }
                else
                    try f.resolveInst(output));
                try writer.writeAll(" = ");
                try f.writeCValue(writer, .{ .local = locals_index }, .Other);
                locals_index += 1;
                try writer.writeAll(";\n");
            }
        }

        break :result if (f.liveness.isUnused(inst)) .none else inst_local;
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
    operator: std.math.CompareOperator,
    is_ptr: bool,
) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const ctype_pool = &f.object.dg.ctype_pool;
    const un_op = f.air.instructions.items(.data)[@intFromEnum(inst)].un_op;

    const writer = f.object.writer();
    const operand = try f.resolveInst(un_op);
    try reap(f, inst, &.{un_op});

    const local = try f.allocLocal(inst, Type.bool);
    const a = try Assignment.start(f, writer, CType.bool);
    try f.writeCValue(writer, local, .Other);
    try a.assign(f, writer);

    const operand_ty = f.typeOf(un_op);
    const optional_ty = if (is_ptr) operand_ty.childType(zcu) else operand_ty;
    const opt_ctype = try f.ctypeFromType(optional_ty, .complete);
    const rhs = switch (opt_ctype.info(ctype_pool)) {
        .basic, .pointer => rhs: {
            if (is_ptr)
                try f.writeCValueDeref(writer, operand)
            else
                try f.writeCValue(writer, operand, .Other);
            break :rhs if (opt_ctype.isBool())
                "true"
            else if (opt_ctype.isInteger())
                "0"
            else
                "NULL";
        },
        .aligned, .array, .vector, .fwd_decl, .function => unreachable,
        .aggregate => |aggregate| switch (aggregate.fields.at(0, ctype_pool).name.index) {
            .is_null, .payload => rhs: {
                if (is_ptr)
                    try f.writeCValueDerefMember(writer, operand, .{ .identifier = "is_null" })
                else
                    try f.writeCValueMember(writer, operand, .{ .identifier = "is_null" });
                break :rhs "true";
            },
            .ptr, .len => rhs: {
                if (is_ptr)
                    try f.writeCValueDerefMember(writer, operand, .{ .identifier = "ptr" })
                else
                    try f.writeCValueMember(writer, operand, .{ .identifier = "ptr" });
                break :rhs "NULL";
            },
            else => unreachable,
        },
    };
    try writer.writeAll(compareOperatorC(operator));
    try writer.writeAll(rhs);
    try a.end(f, writer);
    return local;
}

fn airOptionalPayload(f: *Function, inst: Air.Inst.Index, is_ptr: bool) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const ctype_pool = &f.object.dg.ctype_pool;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const inst_ty = f.typeOfIndex(inst);
    const operand_ty = f.typeOf(ty_op.operand);
    const opt_ty = if (is_ptr) operand_ty.childType(zcu) else operand_ty;
    const opt_ctype = try f.ctypeFromType(opt_ty, .complete);
    if (opt_ctype.isBool()) return if (is_ptr) .{ .undef = inst_ty } else .none;

    const operand = try f.resolveInst(ty_op.operand);
    switch (opt_ctype.info(ctype_pool)) {
        .basic, .pointer => return f.moveCValue(inst, inst_ty, operand),
        .aligned, .array, .vector, .fwd_decl, .function => unreachable,
        .aggregate => |aggregate| switch (aggregate.fields.at(0, ctype_pool).name.index) {
            .is_null, .payload => {
                const writer = f.object.writer();
                const local = try f.allocLocal(inst, inst_ty);
                const a = try Assignment.start(f, writer, try f.ctypeFromType(inst_ty, .complete));
                try f.writeCValue(writer, local, .Other);
                try a.assign(f, writer);
                if (is_ptr) {
                    try writer.writeByte('&');
                    try f.writeCValueDerefMember(writer, operand, .{ .identifier = "payload" });
                } else try f.writeCValueMember(writer, operand, .{ .identifier = "payload" });
                try a.end(f, writer);
                return local;
            },
            .ptr, .len => return f.moveCValue(inst, inst_ty, operand),
            else => unreachable,
        },
    }
}

fn airOptionalPayloadPtrSet(f: *Function, inst: Air.Inst.Index) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const writer = f.object.writer();
    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const operand_ty = f.typeOf(ty_op.operand);

    const inst_ty = f.typeOfIndex(inst);
    const opt_ctype = try f.ctypeFromType(operand_ty.childType(zcu), .complete);
    switch (opt_ctype.info(&f.object.dg.ctype_pool)) {
        .basic => {
            const a = try Assignment.start(f, writer, opt_ctype);
            try f.writeCValueDeref(writer, operand);
            try a.assign(f, writer);
            try f.object.dg.renderValue(writer, Value.false, .Initializer);
            try a.end(f, writer);
            return .none;
        },
        .pointer => {
            if (f.liveness.isUnused(inst)) return .none;
            const local = try f.allocLocal(inst, inst_ty);
            const a = try Assignment.start(f, writer, opt_ctype);
            try f.writeCValue(writer, local, .Other);
            try a.assign(f, writer);
            try f.writeCValue(writer, operand, .Other);
            try a.end(f, writer);
            return local;
        },
        .aligned, .array, .vector, .fwd_decl, .function => unreachable,
        .aggregate => {
            {
                const a = try Assignment.start(f, writer, opt_ctype);
                try f.writeCValueDerefMember(writer, operand, .{ .identifier = "is_null" });
                try a.assign(f, writer);
                try f.object.dg.renderValue(writer, Value.false, .Initializer);
                try a.end(f, writer);
            }
            if (f.liveness.isUnused(inst)) return .none;
            const local = try f.allocLocal(inst, inst_ty);
            const a = try Assignment.start(f, writer, opt_ctype);
            try f.writeCValue(writer, local, .Other);
            try a.assign(f, writer);
            try writer.writeByte('&');
            try f.writeCValueDerefMember(writer, operand, .{ .identifier = "payload" });
            try a.end(f, writer);
            return local;
        },
    }
}

fn fieldLocation(
    container_ptr_ty: Type,
    field_ptr_ty: Type,
    field_index: u32,
    pt: Zcu.PerThread,
) union(enum) {
    begin: void,
    field: CValue,
    byte_offset: u64,
} {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const container_ty = Type.fromInterned(ip.indexToKey(container_ptr_ty.toIntern()).ptr_type.child);
    switch (ip.indexToKey(container_ty.toIntern())) {
        .struct_type => {
            const loaded_struct = ip.loadStructType(container_ty.toIntern());
            return switch (loaded_struct.layout) {
                .auto, .@"extern" => if (!container_ty.hasRuntimeBitsIgnoreComptime(zcu))
                    .begin
                else if (!field_ptr_ty.childType(zcu).hasRuntimeBitsIgnoreComptime(zcu))
                    .{ .byte_offset = loaded_struct.offsets.get(ip)[field_index] }
                else
                    .{ .field = if (loaded_struct.fieldName(ip, field_index).unwrap()) |field_name|
                        .{ .identifier = field_name.toSlice(ip) }
                    else
                        .{ .field = field_index } },
                .@"packed" => if (field_ptr_ty.ptrInfo(zcu).packed_offset.host_size == 0)
                    .{ .byte_offset = @divExact(pt.structPackedFieldBitOffset(loaded_struct, field_index) +
                        container_ptr_ty.ptrInfo(zcu).packed_offset.bit_offset, 8) }
                else
                    .begin,
            };
        },
        .anon_struct_type => |anon_struct_info| return if (!container_ty.hasRuntimeBitsIgnoreComptime(zcu))
            .begin
        else if (!field_ptr_ty.childType(zcu).hasRuntimeBitsIgnoreComptime(zcu))
            .{ .byte_offset = container_ty.structFieldOffset(field_index, zcu) }
        else
            .{ .field = if (anon_struct_info.fieldName(ip, field_index).unwrap()) |field_name|
                .{ .identifier = field_name.toSlice(ip) }
            else
                .{ .field = field_index } },
        .union_type => {
            const loaded_union = ip.loadUnionType(container_ty.toIntern());
            switch (loaded_union.flagsUnordered(ip).layout) {
                .auto, .@"extern" => {
                    const field_ty = Type.fromInterned(loaded_union.field_types.get(ip)[field_index]);
                    if (!field_ty.hasRuntimeBitsIgnoreComptime(zcu))
                        return if (loaded_union.hasTag(ip) and !container_ty.unionHasAllZeroBitFieldTypes(zcu))
                            .{ .field = .{ .identifier = "payload" } }
                        else
                            .begin;
                    const field_name = loaded_union.loadTagType(ip).names.get(ip)[field_index];
                    return .{ .field = if (loaded_union.hasTag(ip))
                        .{ .payload_identifier = field_name.toSlice(ip) }
                    else
                        .{ .identifier = field_name.toSlice(ip) } };
                },
                .@"packed" => return .begin,
            }
        },
        .ptr_type => |ptr_info| switch (ptr_info.flags.size) {
            .One, .Many, .C => unreachable,
            .Slice => switch (field_index) {
                0 => return .{ .field = .{ .identifier = "ptr" } },
                1 => return .{ .field = .{ .identifier = "len" } },
                else => unreachable,
            },
        },
        else => unreachable,
    }
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
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = f.air.extraData(Air.FieldParentPtr, ty_pl.payload).data;

    const container_ptr_ty = f.typeOfIndex(inst);
    const container_ty = container_ptr_ty.childType(zcu);

    const field_ptr_ty = f.typeOf(extra.field_ptr);
    const field_ptr_val = try f.resolveInst(extra.field_ptr);
    try reap(f, inst, &.{extra.field_ptr});

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, container_ptr_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = (");
    try f.renderType(writer, container_ptr_ty);
    try writer.writeByte(')');

    switch (fieldLocation(container_ptr_ty, field_ptr_ty, extra.field_index, pt)) {
        .begin => try f.writeCValue(writer, field_ptr_val, .Initializer),
        .field => |field| {
            const u8_ptr_ty = try pt.adjustPtrTypeChild(field_ptr_ty, Type.u8);

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
            const u8_ptr_ty = try pt.adjustPtrTypeChild(field_ptr_ty, Type.u8);

            try writer.writeAll("((");
            try f.renderType(writer, u8_ptr_ty);
            try writer.writeByte(')');
            try f.writeCValue(writer, field_ptr_val, .Other);
            try writer.print(" - {})", .{
                try f.fmtIntLiteral(try pt.intValue(Type.usize, byte_offset)),
            });
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
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const container_ty = container_ptr_ty.childType(zcu);
    const field_ptr_ty = f.typeOfIndex(inst);

    // Ensure complete type definition is visible before accessing fields.
    _ = try f.ctypeFromType(container_ty, .complete);

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, field_ptr_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = (");
    try f.renderType(writer, field_ptr_ty);
    try writer.writeByte(')');

    switch (fieldLocation(container_ptr_ty, field_ptr_ty, field_index, pt)) {
        .begin => try f.writeCValue(writer, container_ptr_val, .Initializer),
        .field => |field| {
            try writer.writeByte('&');
            try f.writeCValueDerefMember(writer, container_ptr_val, field);
        },
        .byte_offset => |byte_offset| {
            const u8_ptr_ty = try pt.adjustPtrTypeChild(field_ptr_ty, Type.u8);

            try writer.writeAll("((");
            try f.renderType(writer, u8_ptr_ty);
            try writer.writeByte(')');
            try f.writeCValue(writer, container_ptr_val, .Other);
            try writer.print(" + {})", .{
                try f.fmtIntLiteral(try pt.intValue(Type.usize, byte_offset)),
            });
        },
    }

    try writer.writeAll(";\n");
    return local;
}

fn airStructFieldVal(f: *Function, inst: Air.Inst.Index) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = f.air.extraData(Air.StructField, ty_pl.payload).data;

    const inst_ty = f.typeOfIndex(inst);
    if (!inst_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
        try reap(f, inst, &.{extra.struct_operand});
        return .none;
    }

    const struct_byval = try f.resolveInst(extra.struct_operand);
    try reap(f, inst, &.{extra.struct_operand});
    const struct_ty = f.typeOf(extra.struct_operand);
    const writer = f.object.writer();

    // Ensure complete type definition is visible before accessing fields.
    _ = try f.ctypeFromType(struct_ty, .complete);

    const field_name: CValue = switch (ip.indexToKey(struct_ty.toIntern())) {
        .struct_type => field_name: {
            const loaded_struct = ip.loadStructType(struct_ty.toIntern());
            switch (loaded_struct.layout) {
                .auto, .@"extern" => break :field_name if (loaded_struct.fieldName(ip, extra.field_index).unwrap()) |field_name|
                    .{ .identifier = field_name.toSlice(ip) }
                else
                    .{ .field = extra.field_index },
                .@"packed" => {
                    const int_info = struct_ty.intInfo(zcu);

                    const bit_offset_ty = try pt.intType(.unsigned, Type.smallestUnsignedBits(int_info.bits - 1));

                    const bit_offset = pt.structPackedFieldBitOffset(loaded_struct, extra.field_index);

                    const field_int_signedness = if (inst_ty.isAbiInt(zcu))
                        inst_ty.intInfo(zcu).signedness
                    else
                        .unsigned;
                    const field_int_ty = try pt.intType(field_int_signedness, @as(u16, @intCast(inst_ty.bitSize(zcu))));

                    const temp_local = try f.allocLocal(inst, field_int_ty);
                    try f.writeCValue(writer, temp_local, .Other);
                    try writer.writeAll(" = zig_wrap_");
                    try f.object.dg.renderTypeForBuiltinFnName(writer, field_int_ty);
                    try writer.writeAll("((");
                    try f.renderType(writer, field_int_ty);
                    try writer.writeByte(')');
                    const cant_cast = int_info.bits > 64;
                    if (cant_cast) {
                        if (field_int_ty.bitSize(zcu) > 64) return f.fail("TODO: C backend: implement casting between types > 64 bits", .{});
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
                    if (bit_offset > 0) try writer.print(", {})", .{
                        try f.fmtIntLiteral(try pt.intValue(bit_offset_ty, bit_offset)),
                    });
                    if (cant_cast) try writer.writeByte(')');
                    try f.object.dg.renderBuiltinInfo(writer, field_int_ty, .bits);
                    try writer.writeAll(");\n");
                    if (inst_ty.eql(field_int_ty, zcu)) return temp_local;

                    const local = try f.allocLocal(inst, inst_ty);
                    if (local.new_local != temp_local.new_local) {
                        try writer.writeAll("memcpy(");
                        try f.writeCValue(writer, .{ .local_ref = local.new_local }, .FunctionArgument);
                        try writer.writeAll(", ");
                        try f.writeCValue(writer, .{ .local_ref = temp_local.new_local }, .FunctionArgument);
                        try writer.writeAll(", sizeof(");
                        try f.renderType(writer, inst_ty);
                        try writer.writeAll("));\n");
                    }
                    try freeLocal(f, inst, temp_local.new_local, null);
                    return local;
                },
            }
        },
        .anon_struct_type => |anon_struct_info| if (anon_struct_info.fieldName(ip, extra.field_index).unwrap()) |field_name|
            .{ .identifier = field_name.toSlice(ip) }
        else
            .{ .field = extra.field_index },
        .union_type => field_name: {
            const loaded_union = ip.loadUnionType(struct_ty.toIntern());
            switch (loaded_union.flagsUnordered(ip).layout) {
                .auto, .@"extern" => {
                    const name = loaded_union.loadTagType(ip).names.get(ip)[extra.field_index];
                    break :field_name if (loaded_union.hasTag(ip))
                        .{ .payload_identifier = name.toSlice(ip) }
                    else
                        .{ .identifier = name.toSlice(ip) };
                },
                .@"packed" => {
                    const operand_lval = if (struct_byval == .constant) blk: {
                        const operand_local = try f.allocLocal(inst, struct_ty);
                        try f.writeCValue(writer, operand_local, .Other);
                        try writer.writeAll(" = ");
                        try f.writeCValue(writer, struct_byval, .Initializer);
                        try writer.writeAll(";\n");
                        break :blk operand_local;
                    } else struct_byval;
                    const local = try f.allocLocal(inst, inst_ty);
                    if (switch (local) {
                        .new_local, .local => |local_index| switch (operand_lval) {
                            .new_local, .local => |operand_local_index| local_index != operand_local_index,
                            else => true,
                        },
                        else => true,
                    }) {
                        try writer.writeAll("memcpy(&");
                        try f.writeCValue(writer, local, .Other);
                        try writer.writeAll(", &");
                        try f.writeCValue(writer, operand_lval, .Other);
                        try writer.writeAll(", sizeof(");
                        try f.renderType(writer, inst_ty);
                        try writer.writeAll("));\n");
                    }
                    try f.freeCValue(inst, operand_lval);
                    return local;
                },
            }
        },
        else => unreachable,
    };

    const local = try f.allocLocal(inst, inst_ty);
    const a = try Assignment.start(f, writer, try f.ctypeFromType(inst_ty, .complete));
    try f.writeCValue(writer, local, .Other);
    try a.assign(f, writer);
    try f.writeCValueMember(writer, struct_byval, field_name);
    try a.end(f, writer);
    return local;
}

/// *(E!T) -> E
/// Note that the result is never a pointer.
fn airUnwrapErrUnionErr(f: *Function, inst: Air.Inst.Index) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const inst_ty = f.typeOfIndex(inst);
    const operand = try f.resolveInst(ty_op.operand);
    const operand_ty = f.typeOf(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});

    const operand_is_ptr = operand_ty.zigTypeTag(zcu) == .pointer;
    const error_union_ty = if (operand_is_ptr) operand_ty.childType(zcu) else operand_ty;
    const error_ty = error_union_ty.errorUnionSet(zcu);
    const payload_ty = error_union_ty.errorUnionPayload(zcu);
    const local = try f.allocLocal(inst, inst_ty);

    if (!payload_ty.hasRuntimeBits(zcu) and operand == .local and operand.local == local.new_local) {
        // The store will be 'x = x'; elide it.
        return local;
    }

    const writer = f.object.writer();
    try f.writeCValue(writer, local, .Other);
    try writer.writeAll(" = ");

    if (!payload_ty.hasRuntimeBits(zcu))
        try f.writeCValue(writer, operand, .Other)
    else if (error_ty.errorSetIsEmpty(zcu))
        try writer.print("{}", .{
            try f.fmtIntLiteral(try pt.intValue(try pt.errorIntType(), 0)),
        })
    else if (operand_is_ptr)
        try f.writeCValueDerefMember(writer, operand, .{ .identifier = "error" })
    else
        try f.writeCValueMember(writer, operand, .{ .identifier = "error" });
    try writer.writeAll(";\n");
    return local;
}

fn airUnwrapErrUnionPay(f: *Function, inst: Air.Inst.Index, is_ptr: bool) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const inst_ty = f.typeOfIndex(inst);
    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const operand_ty = f.typeOf(ty_op.operand);
    const error_union_ty = if (is_ptr) operand_ty.childType(zcu) else operand_ty;

    const writer = f.object.writer();
    if (!error_union_ty.errorUnionPayload(zcu).hasRuntimeBits(zcu)) {
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
    const a = try Assignment.start(f, writer, try f.ctypeFromType(inst_ty, .complete));
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
    const ctype_pool = &f.object.dg.ctype_pool;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const inst_ty = f.typeOfIndex(inst);
    const inst_ctype = try f.ctypeFromType(inst_ty, .complete);
    if (inst_ctype.isBool()) return .{ .constant = Value.true };

    const operand = try f.resolveInst(ty_op.operand);
    switch (inst_ctype.info(ctype_pool)) {
        .basic, .pointer => return f.moveCValue(inst, inst_ty, operand),
        .aligned, .array, .vector, .fwd_decl, .function => unreachable,
        .aggregate => |aggregate| switch (aggregate.fields.at(0, ctype_pool).name.index) {
            .is_null, .payload => {
                const operand_ctype = try f.ctypeFromType(f.typeOf(ty_op.operand), .complete);
                const writer = f.object.writer();
                const local = try f.allocLocal(inst, inst_ty);
                {
                    const a = try Assignment.start(f, writer, CType.bool);
                    try f.writeCValueMember(writer, local, .{ .identifier = "is_null" });
                    try a.assign(f, writer);
                    try writer.writeAll("false");
                    try a.end(f, writer);
                }
                {
                    const a = try Assignment.start(f, writer, operand_ctype);
                    try f.writeCValueMember(writer, local, .{ .identifier = "payload" });
                    try a.assign(f, writer);
                    try f.writeCValue(writer, operand, .Initializer);
                    try a.end(f, writer);
                }
                return local;
            },
            .ptr, .len => return f.moveCValue(inst, inst_ty, operand),
            else => unreachable,
        },
    }
}

fn airWrapErrUnionErr(f: *Function, inst: Air.Inst.Index) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const inst_ty = f.typeOfIndex(inst);
    const payload_ty = inst_ty.errorUnionPayload(zcu);
    const repr_is_err = !payload_ty.hasRuntimeBitsIgnoreComptime(zcu);
    const err_ty = inst_ty.errorUnionSet(zcu);
    const err = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);

    if (repr_is_err and err == .local and err.local == local.new_local) {
        // The store will be 'x = x'; elide it.
        return local;
    }

    if (!repr_is_err) {
        const a = try Assignment.start(f, writer, try f.ctypeFromType(payload_ty, .complete));
        try f.writeCValueMember(writer, local, .{ .identifier = "payload" });
        try a.assign(f, writer);
        try f.object.dg.renderUndefValue(writer, payload_ty, .Other);
        try a.end(f, writer);
    }
    {
        const a = try Assignment.start(f, writer, try f.ctypeFromType(err_ty, .complete));
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
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const writer = f.object.writer();
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const inst_ty = f.typeOfIndex(inst);
    const operand = try f.resolveInst(ty_op.operand);
    const operand_ty = f.typeOf(ty_op.operand);
    const error_union_ty = operand_ty.childType(zcu);

    const payload_ty = error_union_ty.errorUnionPayload(zcu);
    const err_int_ty = try pt.errorIntType();
    const no_err = try pt.intValue(err_int_ty, 0);
    try reap(f, inst, &.{ty_op.operand});

    // First, set the non-error value.
    if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
        const a = try Assignment.start(f, writer, try f.ctypeFromType(operand_ty, .complete));
        try f.writeCValueDeref(writer, operand);
        try a.assign(f, writer);
        try writer.print("{}", .{try f.fmtIntLiteral(no_err)});
        try a.end(f, writer);
        return .none;
    }
    {
        const a = try Assignment.start(f, writer, try f.ctypeFromType(err_int_ty, .complete));
        try f.writeCValueDerefMember(writer, operand, .{ .identifier = "error" });
        try a.assign(f, writer);
        try writer.print("{}", .{try f.fmtIntLiteral(no_err)});
        try a.end(f, writer);
    }

    // Then return the payload pointer (only if it is used)
    if (f.liveness.isUnused(inst)) return .none;

    const local = try f.allocLocal(inst, inst_ty);
    const a = try Assignment.start(f, writer, try f.ctypeFromType(inst_ty, .complete));
    try f.writeCValue(writer, local, .Other);
    try a.assign(f, writer);
    try writer.writeByte('&');
    try f.writeCValueDerefMember(writer, operand, .{ .identifier = "payload" });
    try a.end(f, writer);
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
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const inst_ty = f.typeOfIndex(inst);
    const payload_ty = inst_ty.errorUnionPayload(zcu);
    const payload = try f.resolveInst(ty_op.operand);
    const repr_is_err = !payload_ty.hasRuntimeBitsIgnoreComptime(zcu);
    const err_ty = inst_ty.errorUnionSet(zcu);
    try reap(f, inst, &.{ty_op.operand});

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    if (!repr_is_err) {
        const a = try Assignment.start(f, writer, try f.ctypeFromType(payload_ty, .complete));
        try f.writeCValueMember(writer, local, .{ .identifier = "payload" });
        try a.assign(f, writer);
        try f.writeCValue(writer, payload, .Other);
        try a.end(f, writer);
    }
    {
        const a = try Assignment.start(f, writer, try f.ctypeFromType(err_ty, .complete));
        if (repr_is_err)
            try f.writeCValue(writer, local, .Other)
        else
            try f.writeCValueMember(writer, local, .{ .identifier = "error" });
        try a.assign(f, writer);
        try f.object.dg.renderValue(writer, try pt.intValue(try pt.errorIntType(), 0), .Other);
        try a.end(f, writer);
    }
    return local;
}

fn airIsErr(f: *Function, inst: Air.Inst.Index, is_ptr: bool, operator: []const u8) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const un_op = f.air.instructions.items(.data)[@intFromEnum(inst)].un_op;

    const writer = f.object.writer();
    const operand = try f.resolveInst(un_op);
    try reap(f, inst, &.{un_op});
    const operand_ty = f.typeOf(un_op);
    const local = try f.allocLocal(inst, Type.bool);
    const err_union_ty = if (is_ptr) operand_ty.childType(zcu) else operand_ty;
    const payload_ty = err_union_ty.errorUnionPayload(zcu);
    const error_ty = err_union_ty.errorUnionSet(zcu);

    const a = try Assignment.start(f, writer, CType.bool);
    try f.writeCValue(writer, local, .Other);
    try a.assign(f, writer);
    const err_int_ty = try pt.errorIntType();
    if (!error_ty.errorSetIsEmpty(zcu))
        if (payload_ty.hasRuntimeBits(zcu))
            if (is_ptr)
                try f.writeCValueDerefMember(writer, operand, .{ .identifier = "error" })
            else
                try f.writeCValueMember(writer, operand, .{ .identifier = "error" })
        else
            try f.writeCValue(writer, operand, .Other)
    else
        try f.object.dg.renderValue(writer, try pt.intValue(err_int_ty, 0), .Other);
    try writer.writeByte(' ');
    try writer.writeAll(operator);
    try writer.writeByte(' ');
    try f.object.dg.renderValue(writer, try pt.intValue(err_int_ty, 0), .Other);
    try a.end(f, writer);
    return local;
}

fn airArrayToSlice(f: *Function, inst: Air.Inst.Index) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const ctype_pool = &f.object.dg.ctype_pool;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const inst_ty = f.typeOfIndex(inst);
    const ptr_ty = inst_ty.slicePtrFieldType(zcu);
    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const operand_ty = f.typeOf(ty_op.operand);
    const array_ty = operand_ty.childType(zcu);

    {
        const a = try Assignment.start(f, writer, try f.ctypeFromType(ptr_ty, .complete));
        try f.writeCValueMember(writer, local, .{ .identifier = "ptr" });
        try a.assign(f, writer);
        if (operand == .undef) {
            try f.writeCValue(writer, .{ .undef = inst_ty.slicePtrFieldType(zcu) }, .Initializer);
        } else {
            const ptr_ctype = try f.ctypeFromType(ptr_ty, .complete);
            const ptr_child_ctype = ptr_ctype.info(ctype_pool).pointer.elem_ctype;
            const elem_ty = array_ty.childType(zcu);
            const elem_ctype = try f.ctypeFromType(elem_ty, .complete);
            if (!ptr_child_ctype.eql(elem_ctype)) {
                try writer.writeByte('(');
                try f.renderCType(writer, ptr_ctype);
                try writer.writeByte(')');
            }
            const operand_ctype = try f.ctypeFromType(operand_ty, .complete);
            const operand_child_ctype = operand_ctype.info(ctype_pool).pointer.elem_ctype;
            if (operand_child_ctype.info(ctype_pool) == .array) {
                try writer.writeByte('&');
                try f.writeCValueDeref(writer, operand);
                try writer.print("[{}]", .{try f.fmtIntLiteral(try pt.intValue(Type.usize, 0))});
            } else try f.writeCValue(writer, operand, .Initializer);
        }
        try a.end(f, writer);
    }
    {
        const a = try Assignment.start(f, writer, CType.usize);
        try f.writeCValueMember(writer, local, .{ .identifier = "len" });
        try a.assign(f, writer);
        try writer.print("{}", .{
            try f.fmtIntLiteral(try pt.intValue(Type.usize, array_ty.arrayLen(zcu))),
        });
        try a.end(f, writer);
    }

    return local;
}

fn airFloatCast(f: *Function, inst: Air.Inst.Index) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const inst_ty = f.typeOfIndex(inst);
    const inst_scalar_ty = inst_ty.scalarType(zcu);
    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});
    const operand_ty = f.typeOf(ty_op.operand);
    const scalar_ty = operand_ty.scalarType(zcu);
    const target = &f.object.dg.mod.resolved_target.result;
    const operation = if (inst_scalar_ty.isRuntimeFloat() and scalar_ty.isRuntimeFloat())
        if (inst_scalar_ty.floatBits(target.*) < scalar_ty.floatBits(target.*)) "trunc" else "extend"
    else if (inst_scalar_ty.isInt(zcu) and scalar_ty.isRuntimeFloat())
        if (inst_scalar_ty.isSignedInt(zcu)) "fix" else "fixuns"
    else if (inst_scalar_ty.isRuntimeFloat() and scalar_ty.isInt(zcu))
        if (scalar_ty.isSignedInt(zcu)) "float" else "floatun"
    else
        unreachable;

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const v = try Vectorize.start(f, inst, writer, operand_ty);
    const a = try Assignment.start(f, writer, try f.ctypeFromType(scalar_ty, .complete));
    try f.writeCValue(writer, local, .Other);
    try v.elem(f, writer);
    try a.assign(f, writer);
    if (inst_scalar_ty.isInt(zcu) and scalar_ty.isRuntimeFloat()) {
        try writer.writeAll("zig_wrap_");
        try f.object.dg.renderTypeForBuiltinFnName(writer, inst_scalar_ty);
        try writer.writeByte('(');
    }
    try writer.writeAll("zig_");
    try writer.writeAll(operation);
    try writer.writeAll(compilerRtAbbrev(scalar_ty, zcu, target.*));
    try writer.writeAll(compilerRtAbbrev(inst_scalar_ty, zcu, target.*));
    try writer.writeByte('(');
    try f.writeCValue(writer, operand, .FunctionArgument);
    try v.elem(f, writer);
    try writer.writeByte(')');
    if (inst_scalar_ty.isInt(zcu) and scalar_ty.isRuntimeFloat()) {
        try f.object.dg.renderBuiltinInfo(writer, inst_scalar_ty, .bits);
        try writer.writeByte(')');
    }
    try a.end(f, writer);
    try v.end(f, inst, writer);

    return local;
}

fn airIntFromPtr(f: *Function, inst: Air.Inst.Index) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
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
    if (operand_ty.isSlice(zcu))
        try f.writeCValueMember(writer, operand, .{ .identifier = "ptr" })
    else
        try f.writeCValue(writer, operand, .Other);
    try writer.writeAll(";\n");
    return local;
}

fn airUnBuiltinCall(
    f: *Function,
    inst: Air.Inst.Index,
    operand_ref: Air.Inst.Ref,
    operation: []const u8,
    info: BuiltinInfo,
) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;

    const operand = try f.resolveInst(operand_ref);
    try reap(f, inst, &.{operand_ref});
    const inst_ty = f.typeOfIndex(inst);
    const inst_scalar_ty = inst_ty.scalarType(zcu);
    const operand_ty = f.typeOf(operand_ref);
    const scalar_ty = operand_ty.scalarType(zcu);

    const inst_scalar_ctype = try f.ctypeFromType(inst_scalar_ty, .complete);
    const ref_ret = inst_scalar_ctype.info(&f.object.dg.ctype_pool) == .array;

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
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const bin_op = f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const operand_ty = f.typeOf(bin_op.lhs);
    const operand_ctype = try f.ctypeFromType(operand_ty, .complete);
    const is_big = operand_ctype.info(&f.object.dg.ctype_pool) == .array;

    const lhs = try f.resolveInst(bin_op.lhs);
    const rhs = try f.resolveInst(bin_op.rhs);
    if (!is_big) try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const inst_ty = f.typeOfIndex(inst);
    const inst_scalar_ty = inst_ty.scalarType(zcu);
    const scalar_ty = operand_ty.scalarType(zcu);

    const inst_scalar_ctype = try f.ctypeFromType(inst_scalar_ty, .complete);
    const ref_ret = inst_scalar_ctype.info(&f.object.dg.ctype_pool) == .array;

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
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const lhs = try f.resolveInst(data.lhs);
    const rhs = try f.resolveInst(data.rhs);
    try reap(f, inst, &.{ data.lhs, data.rhs });

    const inst_ty = f.typeOfIndex(inst);
    const inst_scalar_ty = inst_ty.scalarType(zcu);
    const operand_ty = f.typeOf(data.lhs);
    const scalar_ty = operand_ty.scalarType(zcu);

    const inst_scalar_ctype = try f.ctypeFromType(inst_scalar_ty, .complete);
    const ref_ret = inst_scalar_ctype.info(&f.object.dg.ctype_pool) == .array;

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
    if (!ref_ret) try writer.print("{s}{}", .{
        compareOperatorC(operator),
        try f.fmtIntLiteral(try pt.intValue(Type.i32, 0)),
    });
    try writer.writeAll(";\n");
    try v.end(f, inst, writer);

    return local;
}

fn airCmpxchg(f: *Function, inst: Air.Inst.Index, flavor: [*:0]const u8) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = f.air.extraData(Air.Cmpxchg, ty_pl.payload).data;
    const inst_ty = f.typeOfIndex(inst);
    const ptr = try f.resolveInst(extra.ptr);
    const expected_value = try f.resolveInst(extra.expected_value);
    const new_value = try f.resolveInst(extra.new_value);
    const ptr_ty = f.typeOf(extra.ptr);
    const ty = ptr_ty.childType(zcu);
    const ctype = try f.ctypeFromType(ty, .complete);

    const writer = f.object.writer();
    const new_value_mat = try Materialize.start(f, inst, ty, new_value);
    try reap(f, inst, &.{ extra.ptr, extra.expected_value, extra.new_value });

    const repr_ty = if (ty.isRuntimeFloat())
        pt.intType(.unsigned, @as(u16, @intCast(ty.abiSize(zcu) * 8))) catch unreachable
    else
        ty;

    const local = try f.allocLocal(inst, inst_ty);
    if (inst_ty.isPtrLikeOptional(zcu)) {
        {
            const a = try Assignment.start(f, writer, ctype);
            try f.writeCValue(writer, local, .Other);
            try a.assign(f, writer);
            try f.writeCValue(writer, expected_value, .Other);
            try a.end(f, writer);
        }

        try writer.writeAll("if (");
        try writer.print("zig_cmpxchg_{s}((zig_atomic(", .{flavor});
        try f.renderType(writer, ty);
        try writer.writeByte(')');
        if (ptr_ty.isVolatilePtr(zcu)) try writer.writeAll(" volatile");
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
        try f.renderType(writer, repr_ty);
        try writer.writeByte(')');
        try writer.writeAll(") {\n");
        f.object.indent_writer.pushIndent();
        {
            const a = try Assignment.start(f, writer, ctype);
            try f.writeCValue(writer, local, .Other);
            try a.assign(f, writer);
            try writer.writeAll("NULL");
            try a.end(f, writer);
        }
        f.object.indent_writer.popIndent();
        try writer.writeAll("}\n");
    } else {
        {
            const a = try Assignment.start(f, writer, ctype);
            try f.writeCValueMember(writer, local, .{ .identifier = "payload" });
            try a.assign(f, writer);
            try f.writeCValue(writer, expected_value, .Other);
            try a.end(f, writer);
        }
        {
            const a = try Assignment.start(f, writer, CType.bool);
            try f.writeCValueMember(writer, local, .{ .identifier = "is_null" });
            try a.assign(f, writer);
            try writer.print("zig_cmpxchg_{s}((zig_atomic(", .{flavor});
            try f.renderType(writer, ty);
            try writer.writeByte(')');
            if (ptr_ty.isVolatilePtr(zcu)) try writer.writeAll(" volatile");
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
            try f.renderType(writer, repr_ty);
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
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const pl_op = f.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const extra = f.air.extraData(Air.AtomicRmw, pl_op.payload).data;
    const inst_ty = f.typeOfIndex(inst);
    const ptr_ty = f.typeOf(pl_op.operand);
    const ty = ptr_ty.childType(zcu);
    const ptr = try f.resolveInst(pl_op.operand);
    const operand = try f.resolveInst(extra.operand);

    const writer = f.object.writer();
    const operand_mat = try Materialize.start(f, inst, ty, operand);
    try reap(f, inst, &.{ pl_op.operand, extra.operand });

    const repr_bits = @as(u16, @intCast(ty.abiSize(zcu) * 8));
    const is_float = ty.isRuntimeFloat();
    const is_128 = repr_bits == 128;
    const repr_ty = if (is_float) pt.intType(.unsigned, repr_bits) catch unreachable else ty;

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
    if (ptr_ty.isVolatilePtr(zcu)) try writer.writeAll(" volatile");
    try writer.writeAll(" *)");
    try f.writeCValue(writer, ptr, .Other);
    try writer.writeAll(", ");
    try operand_mat.mat(f, writer);
    try writer.writeAll(", ");
    try writeMemoryOrder(writer, extra.ordering());
    try writer.writeAll(", ");
    try f.object.dg.renderTypeForBuiltinFnName(writer, ty);
    try writer.writeAll(", ");
    try f.renderType(writer, repr_ty);
    try writer.writeAll(");\n");
    try operand_mat.end(f, inst);

    if (f.liveness.isUnused(inst)) {
        try freeLocal(f, inst, local.new_local, null);
        return .none;
    }

    return local;
}

fn airAtomicLoad(f: *Function, inst: Air.Inst.Index) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const atomic_load = f.air.instructions.items(.data)[@intFromEnum(inst)].atomic_load;
    const ptr = try f.resolveInst(atomic_load.ptr);
    try reap(f, inst, &.{atomic_load.ptr});
    const ptr_ty = f.typeOf(atomic_load.ptr);
    const ty = ptr_ty.childType(zcu);

    const repr_ty = if (ty.isRuntimeFloat())
        pt.intType(.unsigned, @as(u16, @intCast(ty.abiSize(zcu) * 8))) catch unreachable
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
    if (ptr_ty.isVolatilePtr(zcu)) try writer.writeAll(" volatile");
    try writer.writeAll(" *)");
    try f.writeCValue(writer, ptr, .Other);
    try writer.writeAll(", ");
    try writeMemoryOrder(writer, atomic_load.order);
    try writer.writeAll(", ");
    try f.object.dg.renderTypeForBuiltinFnName(writer, ty);
    try writer.writeAll(", ");
    try f.renderType(writer, repr_ty);
    try writer.writeAll(");\n");

    return local;
}

fn airAtomicStore(f: *Function, inst: Air.Inst.Index, order: [*:0]const u8) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const bin_op = f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const ptr_ty = f.typeOf(bin_op.lhs);
    const ty = ptr_ty.childType(zcu);
    const ptr = try f.resolveInst(bin_op.lhs);
    const element = try f.resolveInst(bin_op.rhs);

    const writer = f.object.writer();
    const element_mat = try Materialize.start(f, inst, ty, element);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const repr_ty = if (ty.isRuntimeFloat())
        pt.intType(.unsigned, @as(u16, @intCast(ty.abiSize(zcu) * 8))) catch unreachable
    else
        ty;

    try writer.writeAll("zig_atomic_store((zig_atomic(");
    try f.renderType(writer, ty);
    try writer.writeByte(')');
    if (ptr_ty.isVolatilePtr(zcu)) try writer.writeAll(" volatile");
    try writer.writeAll(" *)");
    try f.writeCValue(writer, ptr, .Other);
    try writer.writeAll(", ");
    try element_mat.mat(f, writer);
    try writer.print(", {s}, ", .{order});
    try f.object.dg.renderTypeForBuiltinFnName(writer, ty);
    try writer.writeAll(", ");
    try f.renderType(writer, repr_ty);
    try writer.writeAll(");\n");
    try element_mat.end(f, inst);

    return .none;
}

fn writeSliceOrPtr(f: *Function, writer: anytype, ptr: CValue, ptr_ty: Type) !void {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    if (ptr_ty.isSlice(zcu)) {
        try f.writeCValueMember(writer, ptr, .{ .identifier = "ptr" });
    } else {
        try f.writeCValue(writer, ptr, .FunctionArgument);
    }
}

fn airMemset(f: *Function, inst: Air.Inst.Index, safety: bool) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const bin_op = f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const dest_ty = f.typeOf(bin_op.lhs);
    const dest_slice = try f.resolveInst(bin_op.lhs);
    const value = try f.resolveInst(bin_op.rhs);
    const elem_ty = f.typeOf(bin_op.rhs);
    const elem_abi_size = elem_ty.abiSize(zcu);
    const val_is_undef = if (try f.air.value(bin_op.rhs, pt)) |val| val.isUndefDeep(zcu) else false;
    const writer = f.object.writer();

    if (val_is_undef) {
        if (!safety) {
            try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
            return .none;
        }

        try writer.writeAll("memset(");
        switch (dest_ty.ptrSize(zcu)) {
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
                const array_ty = dest_ty.childType(zcu);
                const len = array_ty.arrayLen(zcu) * elem_abi_size;

                try f.writeCValue(writer, dest_slice, .FunctionArgument);
                try writer.print(", 0xaa, {d});\n", .{len});
            },
            .Many, .C => unreachable,
        }
        try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
        return .none;
    }

    if (elem_abi_size > 1 or dest_ty.isVolatilePtr(zcu)) {
        // For the assignment in this loop, the array pointer needs to get
        // casted to a regular pointer, otherwise an error like this occurs:
        // error: array type 'uint32_t[20]' (aka 'unsigned int[20]') is not assignable
        const elem_ptr_ty = try pt.ptrType(.{
            .child = elem_ty.toIntern(),
            .flags = .{
                .size = .C,
            },
        });

        const index = try f.allocLocal(inst, Type.usize);

        try writer.writeAll("for (");
        try f.writeCValue(writer, index, .Other);
        try writer.writeAll(" = ");
        try f.object.dg.renderValue(writer, try pt.intValue(Type.usize, 0), .Initializer);
        try writer.writeAll("; ");
        try f.writeCValue(writer, index, .Other);
        try writer.writeAll(" != ");
        switch (dest_ty.ptrSize(zcu)) {
            .Slice => {
                try f.writeCValueMember(writer, dest_slice, .{ .identifier = "len" });
            },
            .One => {
                const array_ty = dest_ty.childType(zcu);
                try writer.print("{d}", .{array_ty.arrayLen(zcu)});
            },
            .Many, .C => unreachable,
        }
        try writer.writeAll("; ++");
        try f.writeCValue(writer, index, .Other);
        try writer.writeAll(") ");

        const a = try Assignment.start(f, writer, try f.ctypeFromType(elem_ty, .complete));
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
    switch (dest_ty.ptrSize(zcu)) {
        .Slice => {
            try f.writeCValueMember(writer, dest_slice, .{ .identifier = "ptr" });
            try writer.writeAll(", ");
            try f.writeCValue(writer, bitcasted, .FunctionArgument);
            try writer.writeAll(", ");
            try f.writeCValueMember(writer, dest_slice, .{ .identifier = "len" });
            try writer.writeAll(");\n");
        },
        .One => {
            const array_ty = dest_ty.childType(zcu);
            const len = array_ty.arrayLen(zcu) * elem_abi_size;

            try f.writeCValue(writer, dest_slice, .FunctionArgument);
            try writer.writeAll(", ");
            try f.writeCValue(writer, bitcasted, .FunctionArgument);
            try writer.print(", {d});\n", .{len});
        },
        .Many, .C => unreachable,
    }
    try f.freeCValue(inst, bitcasted);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
    return .none;
}

fn airMemcpy(f: *Function, inst: Air.Inst.Index) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const bin_op = f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const dest_ptr = try f.resolveInst(bin_op.lhs);
    const src_ptr = try f.resolveInst(bin_op.rhs);
    const dest_ty = f.typeOf(bin_op.lhs);
    const src_ty = f.typeOf(bin_op.rhs);
    const writer = f.object.writer();

    if (dest_ty.ptrSize(zcu) != .One) {
        try writer.writeAll("if (");
        try writeArrayLen(f, writer, dest_ptr, dest_ty);
        try writer.writeAll(" != 0) ");
    }
    try writer.writeAll("memcpy(");
    try writeSliceOrPtr(f, writer, dest_ptr, dest_ty);
    try writer.writeAll(", ");
    try writeSliceOrPtr(f, writer, src_ptr, src_ty);
    try writer.writeAll(", ");
    try writeArrayLen(f, writer, dest_ptr, dest_ty);
    try writer.writeAll(" * sizeof(");
    try f.renderType(writer, dest_ty.elemType2(zcu));
    try writer.writeAll("));\n");

    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });
    return .none;
}

fn writeArrayLen(f: *Function, writer: ArrayListWriter, dest_ptr: CValue, dest_ty: Type) !void {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    switch (dest_ty.ptrSize(zcu)) {
        .One => try writer.print("{}", .{
            try f.fmtIntLiteral(try pt.intValue(Type.usize, dest_ty.childType(zcu).arrayLen(zcu))),
        }),
        .Many, .C => unreachable,
        .Slice => try f.writeCValueMember(writer, dest_ptr, .{ .identifier = "len" }),
    }
}

fn airSetUnionTag(f: *Function, inst: Air.Inst.Index) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const bin_op = f.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const union_ptr = try f.resolveInst(bin_op.lhs);
    const new_tag = try f.resolveInst(bin_op.rhs);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs });

    const union_ty = f.typeOf(bin_op.lhs).childType(zcu);
    const layout = union_ty.unionGetLayout(zcu);
    if (layout.tag_size == 0) return .none;
    const tag_ty = union_ty.unionTagTypeSafety(zcu).?;

    const writer = f.object.writer();
    const a = try Assignment.start(f, writer, try f.ctypeFromType(tag_ty, .complete));
    try f.writeCValueDerefMember(writer, union_ptr, .{ .identifier = "tag" });
    try a.assign(f, writer);
    try f.writeCValue(writer, new_tag, .Other);
    try a.end(f, writer);
    return .none;
}

fn airGetUnionTag(f: *Function, inst: Air.Inst.Index) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});

    const union_ty = f.typeOf(ty_op.operand);
    const layout = union_ty.unionGetLayout(zcu);
    if (layout.tag_size == 0) return .none;

    const inst_ty = f.typeOfIndex(inst);
    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const a = try Assignment.start(f, writer, try f.ctypeFromType(inst_ty, .complete));
    try f.writeCValue(writer, local, .Other);
    try a.assign(f, writer);
    try f.writeCValueMember(writer, operand, .{ .identifier = "tag" });
    try a.end(f, writer);
    return local;
}

fn airTagName(f: *Function, inst: Air.Inst.Index) !CValue {
    const un_op = f.air.instructions.items(.data)[@intFromEnum(inst)].un_op;

    const inst_ty = f.typeOfIndex(inst);
    const enum_ty = f.typeOf(un_op);
    const operand = try f.resolveInst(un_op);
    try reap(f, inst, &.{un_op});

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try writer.print(" = {s}(", .{
        try f.getLazyFnName(.{ .tag_name = enum_ty.toIntern() }),
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
    try writer.writeAll(" - 1];\n");
    return local;
}

fn airSplat(f: *Function, inst: Air.Inst.Index) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const ty_op = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const operand = try f.resolveInst(ty_op.operand);
    try reap(f, inst, &.{ty_op.operand});

    const inst_ty = f.typeOfIndex(inst);
    const inst_scalar_ty = inst_ty.scalarType(zcu);

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const v = try Vectorize.start(f, inst, writer, inst_ty);
    const a = try Assignment.start(f, writer, try f.ctypeFromType(inst_scalar_ty, .complete));
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
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
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
        try f.object.dg.renderValue(writer, try pt.intValue(Type.usize, index), .Other);
        try writer.writeAll("] = ");

        const mask_elem = (try mask.elemValue(pt, index)).toSignedInt(zcu);
        const src_val = try pt.intValue(Type.usize, @as(u64, @intCast(mask_elem ^ mask_elem >> 63)));

        try f.writeCValue(writer, if (mask_elem >= 0) lhs else rhs, .Other);
        try writer.writeByte('[');
        try f.object.dg.renderValue(writer, src_val, .Other);
        try writer.writeAll("];\n");
    }

    return local;
}

fn airReduce(f: *Function, inst: Air.Inst.Index) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const reduce = f.air.instructions.items(.data)[@intFromEnum(inst)].reduce;

    const scalar_ty = f.typeOfIndex(inst);
    const operand = try f.resolveInst(reduce.operand);
    try reap(f, inst, &.{reduce.operand});
    const operand_ty = f.typeOf(reduce.operand);
    const writer = f.object.writer();

    const use_operator = scalar_ty.bitSize(zcu) <= 64;
    const op: union(enum) {
        const Func = struct { operation: []const u8, info: BuiltinInfo = .none };
        builtin: Func,
        infix: []const u8,
        ternary: []const u8,
    } = switch (reduce.operation) {
        .And => if (use_operator) .{ .infix = " &= " } else .{ .builtin = .{ .operation = "and" } },
        .Or => if (use_operator) .{ .infix = " |= " } else .{ .builtin = .{ .operation = "or" } },
        .Xor => if (use_operator) .{ .infix = " ^= " } else .{ .builtin = .{ .operation = "xor" } },
        .Min => switch (scalar_ty.zigTypeTag(zcu)) {
            .int => if (use_operator) .{ .ternary = " < " } else .{ .builtin = .{ .operation = "min" } },
            .float => .{ .builtin = .{ .operation = "min" } },
            else => unreachable,
        },
        .Max => switch (scalar_ty.zigTypeTag(zcu)) {
            .int => if (use_operator) .{ .ternary = " > " } else .{ .builtin = .{ .operation = "max" } },
            .float => .{ .builtin = .{ .operation = "max" } },
            else => unreachable,
        },
        .Add => switch (scalar_ty.zigTypeTag(zcu)) {
            .int => if (use_operator) .{ .infix = " += " } else .{ .builtin = .{ .operation = "addw", .info = .bits } },
            .float => .{ .builtin = .{ .operation = "add" } },
            else => unreachable,
        },
        .Mul => switch (scalar_ty.zigTypeTag(zcu)) {
            .int => if (use_operator) .{ .infix = " *= " } else .{ .builtin = .{ .operation = "mulw", .info = .bits } },
            .float => .{ .builtin = .{ .operation = "mul" } },
            else => unreachable,
        },
    };

    // Reduce a vector by repeatedly applying a function to produce an
    // accumulated result.
    //
    // Equivalent to:
    //   reduce: {
    //     var accum: T = init;
    //     for (vec) |elem| {
    //       accum = func(accum, elem);
    //     }
    //     break :reduce accum;
    //   }

    const accum = try f.allocLocal(inst, scalar_ty);
    try f.writeCValue(writer, accum, .Other);
    try writer.writeAll(" = ");

    try f.object.dg.renderValue(writer, switch (reduce.operation) {
        .Or, .Xor => switch (scalar_ty.zigTypeTag(zcu)) {
            .bool => Value.false,
            .int => try pt.intValue(scalar_ty, 0),
            else => unreachable,
        },
        .And => switch (scalar_ty.zigTypeTag(zcu)) {
            .bool => Value.true,
            .int => switch (scalar_ty.intInfo(zcu).signedness) {
                .unsigned => try scalar_ty.maxIntScalar(pt, scalar_ty),
                .signed => try pt.intValue(scalar_ty, -1),
            },
            else => unreachable,
        },
        .Add => switch (scalar_ty.zigTypeTag(zcu)) {
            .int => try pt.intValue(scalar_ty, 0),
            .float => try pt.floatValue(scalar_ty, 0.0),
            else => unreachable,
        },
        .Mul => switch (scalar_ty.zigTypeTag(zcu)) {
            .int => try pt.intValue(scalar_ty, 1),
            .float => try pt.floatValue(scalar_ty, 1.0),
            else => unreachable,
        },
        .Min => switch (scalar_ty.zigTypeTag(zcu)) {
            .bool => Value.true,
            .int => try scalar_ty.maxIntScalar(pt, scalar_ty),
            .float => try pt.floatValue(scalar_ty, std.math.nan(f128)),
            else => unreachable,
        },
        .Max => switch (scalar_ty.zigTypeTag(zcu)) {
            .bool => Value.false,
            .int => try scalar_ty.minIntScalar(pt, scalar_ty),
            .float => try pt.floatValue(scalar_ty, std.math.nan(f128)),
            else => unreachable,
        },
    }, .Initializer);
    try writer.writeAll(";\n");

    const v = try Vectorize.start(f, inst, writer, operand_ty);
    try f.writeCValue(writer, accum, .Other);
    switch (op) {
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
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const inst_ty = f.typeOfIndex(inst);
    const len = @as(usize, @intCast(inst_ty.arrayLen(zcu)));
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
    switch (ip.indexToKey(inst_ty.toIntern())) {
        inline .array_type, .vector_type => |info, tag| {
            const a: Assignment = .{
                .ctype = try f.ctypeFromType(Type.fromInterned(info.child), .complete),
            };
            for (resolved_elements, 0..) |element, i| {
                try a.restart(f, writer);
                try f.writeCValue(writer, local, .Other);
                try writer.print("[{d}]", .{i});
                try a.assign(f, writer);
                try f.writeCValue(writer, element, .Other);
                try a.end(f, writer);
            }
            if (tag == .array_type and info.sentinel != .none) {
                try a.restart(f, writer);
                try f.writeCValue(writer, local, .Other);
                try writer.print("[{d}]", .{info.len});
                try a.assign(f, writer);
                try f.object.dg.renderValue(writer, Value.fromInterned(info.sentinel), .Other);
                try a.end(f, writer);
            }
        },
        .struct_type => {
            const loaded_struct = ip.loadStructType(inst_ty.toIntern());
            switch (loaded_struct.layout) {
                .auto, .@"extern" => {
                    var field_it = loaded_struct.iterateRuntimeOrder(ip);
                    while (field_it.next()) |field_index| {
                        const field_ty = Type.fromInterned(loaded_struct.field_types.get(ip)[field_index]);
                        if (!field_ty.hasRuntimeBitsIgnoreComptime(zcu)) continue;

                        const a = try Assignment.start(f, writer, try f.ctypeFromType(field_ty, .complete));
                        try f.writeCValueMember(writer, local, if (loaded_struct.fieldName(ip, field_index).unwrap()) |field_name|
                            .{ .identifier = field_name.toSlice(ip) }
                        else
                            .{ .field = field_index });
                        try a.assign(f, writer);
                        try f.writeCValue(writer, resolved_elements[field_index], .Other);
                        try a.end(f, writer);
                    }
                },
                .@"packed" => {
                    try f.writeCValue(writer, local, .Other);
                    try writer.writeAll(" = ");
                    const int_info = inst_ty.intInfo(zcu);

                    const bit_offset_ty = try pt.intType(.unsigned, Type.smallestUnsignedBits(int_info.bits - 1));

                    var bit_offset: u64 = 0;

                    var empty = true;
                    for (0..elements.len) |field_index| {
                        if (inst_ty.structFieldIsComptime(field_index, zcu)) continue;
                        const field_ty = inst_ty.fieldType(field_index, zcu);
                        if (!field_ty.hasRuntimeBitsIgnoreComptime(zcu)) continue;

                        if (!empty) {
                            try writer.writeAll("zig_or_");
                            try f.object.dg.renderTypeForBuiltinFnName(writer, inst_ty);
                            try writer.writeByte('(');
                        }
                        empty = false;
                    }
                    empty = true;
                    for (resolved_elements, 0..) |element, field_index| {
                        if (inst_ty.structFieldIsComptime(field_index, zcu)) continue;
                        const field_ty = inst_ty.fieldType(field_index, zcu);
                        if (!field_ty.hasRuntimeBitsIgnoreComptime(zcu)) continue;

                        if (!empty) try writer.writeAll(", ");
                        // TODO: Skip this entire shift if val is 0?
                        try writer.writeAll("zig_shlw_");
                        try f.object.dg.renderTypeForBuiltinFnName(writer, inst_ty);
                        try writer.writeByte('(');

                        if (inst_ty.isAbiInt(zcu) and (field_ty.isAbiInt(zcu) or field_ty.isPtrAtRuntime(zcu))) {
                            try f.renderIntCast(writer, inst_ty, element, .{}, field_ty, .FunctionArgument);
                        } else {
                            try writer.writeByte('(');
                            try f.renderType(writer, inst_ty);
                            try writer.writeByte(')');
                            if (field_ty.isPtrAtRuntime(zcu)) {
                                try writer.writeByte('(');
                                try f.renderType(writer, switch (int_info.signedness) {
                                    .unsigned => Type.usize,
                                    .signed => Type.isize,
                                });
                                try writer.writeByte(')');
                            }
                            try f.writeCValue(writer, element, .Other);
                        }

                        try writer.print(", {}", .{
                            try f.fmtIntLiteral(try pt.intValue(bit_offset_ty, bit_offset)),
                        });
                        try f.object.dg.renderBuiltinInfo(writer, inst_ty, .bits);
                        try writer.writeByte(')');
                        if (!empty) try writer.writeByte(')');

                        bit_offset += field_ty.bitSize(zcu);
                        empty = false;
                    }
                    try writer.writeAll(";\n");
                },
            }
        },
        .anon_struct_type => |anon_struct_info| for (0..anon_struct_info.types.len) |field_index| {
            if (anon_struct_info.values.get(ip)[field_index] != .none) continue;
            const field_ty = Type.fromInterned(anon_struct_info.types.get(ip)[field_index]);
            if (!field_ty.hasRuntimeBitsIgnoreComptime(zcu)) continue;

            const a = try Assignment.start(f, writer, try f.ctypeFromType(field_ty, .complete));
            try f.writeCValueMember(writer, local, if (anon_struct_info.fieldName(ip, field_index).unwrap()) |field_name|
                .{ .identifier = field_name.toSlice(ip) }
            else
                .{ .field = field_index });
            try a.assign(f, writer);
            try f.writeCValue(writer, resolved_elements[field_index], .Other);
            try a.end(f, writer);
        },
        else => unreachable,
    }

    return local;
}

fn airUnionInit(f: *Function, inst: Air.Inst.Index) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const ty_pl = f.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = f.air.extraData(Air.UnionInit, ty_pl.payload).data;

    const union_ty = f.typeOfIndex(inst);
    const loaded_union = ip.loadUnionType(union_ty.toIntern());
    const field_name = loaded_union.loadTagType(ip).names.get(ip)[extra.field_index];
    const payload_ty = f.typeOf(extra.init);
    const payload = try f.resolveInst(extra.init);
    try reap(f, inst, &.{extra.init});

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, union_ty);
    if (loaded_union.flagsUnordered(ip).layout == .@"packed") return f.moveCValue(inst, union_ty, payload);

    const field: CValue = if (union_ty.unionTagTypeSafety(zcu)) |tag_ty| field: {
        const layout = union_ty.unionGetLayout(zcu);
        if (layout.tag_size != 0) {
            const field_index = tag_ty.enumFieldIndex(field_name, zcu).?;
            const tag_val = try pt.enumValueFieldIndex(tag_ty, field_index);

            const a = try Assignment.start(f, writer, try f.ctypeFromType(tag_ty, .complete));
            try f.writeCValueMember(writer, local, .{ .identifier = "tag" });
            try a.assign(f, writer);
            try writer.print("{}", .{try f.fmtIntLiteral(try tag_val.intFromEnum(tag_ty, pt))});
            try a.end(f, writer);
        }
        break :field .{ .payload_identifier = field_name.toSlice(ip) };
    } else .{ .identifier = field_name.toSlice(ip) };

    const a = try Assignment.start(f, writer, try f.ctypeFromType(payload_ty, .complete));
    try f.writeCValueMember(writer, local, field);
    try a.assign(f, writer);
    try f.writeCValue(writer, payload, .Other);
    try a.end(f, writer);
    return local;
}

fn airPrefetch(f: *Function, inst: Air.Inst.Index) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const prefetch = f.air.instructions.items(.data)[@intFromEnum(inst)].prefetch;

    const ptr_ty = f.typeOf(prefetch.ptr);
    const ptr = try f.resolveInst(prefetch.ptr);
    try reap(f, inst, &.{prefetch.ptr});

    const writer = f.object.writer();
    switch (prefetch.cache) {
        .data => {
            try writer.writeAll("zig_prefetch(");
            if (ptr_ty.isSlice(zcu))
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

fn airMulAdd(f: *Function, inst: Air.Inst.Index) !CValue {
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const pl_op = f.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const bin_op = f.air.extraData(Air.Bin, pl_op.payload).data;

    const mulend1 = try f.resolveInst(bin_op.lhs);
    const mulend2 = try f.resolveInst(bin_op.rhs);
    const addend = try f.resolveInst(pl_op.operand);
    try reap(f, inst, &.{ bin_op.lhs, bin_op.rhs, pl_op.operand });

    const inst_ty = f.typeOfIndex(inst);
    const inst_scalar_ty = inst_ty.scalarType(zcu);

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    const v = try Vectorize.start(f, inst, writer, inst_ty);
    try f.writeCValue(writer, local, .Other);
    try v.elem(f, writer);
    try writer.writeAll(" = zig_fma_");
    try f.object.dg.renderTypeForBuiltinFnName(writer, inst_scalar_ty);
    try writer.writeByte('(');
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
    const pt = f.object.dg.pt;
    const zcu = pt.zcu;
    const inst_ty = f.typeOfIndex(inst);
    const function_ty = zcu.navValue(f.object.dg.pass.nav).typeOf(zcu);
    const function_info = (try f.ctypeFromType(function_ty, .complete)).info(&f.object.dg.ctype_pool).function;
    assert(function_info.varargs);

    const writer = f.object.writer();
    const local = try f.allocLocal(inst, inst_ty);
    try writer.writeAll("va_start(*(va_list *)&");
    try f.writeCValue(writer, local, .Other);
    if (function_info.param_ctypes.len > 0) {
        try writer.writeAll(", ");
        try f.writeCValue(writer, .{ .arg = function_info.param_ctypes.len - 1 }, .FunctionArgument);
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
        .unordered, .monotonic => "zig_memory_order_relaxed",
        .acquire => "zig_memory_order_acquire",
        .release => "zig_memory_order_release",
        .acq_rel => "zig_memory_order_acq_rel",
        .seq_cst => "zig_memory_order_seq_cst",
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

fn compilerRtAbbrev(ty: Type, zcu: *Zcu, target: std.Target) []const u8 {
    return if (ty.isInt(zcu)) switch (ty.intInfo(zcu).bits) {
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
        .lt => " < ",
        .lte => " <= ",
        .eq => " == ",
        .gte => " >= ",
        .gt => " > ",
        .neq => " != ",
    };
}

fn StringLiteral(comptime WriterType: type) type {
    // MSVC throws C2078 if an array of size 65536 or greater is initialized with a string literal,
    // regardless of the length of the string literal initializing it. Array initializer syntax is
    // used instead.
    // C99 only requires 4095.
    const max_string_initializer_len = @min(65535, 4095);

    // MSVC has a length limit of 16380 per string literal (before concatenation)
    // C99 only requires 4095.
    const max_char_len = 4;
    const max_literal_len = @min(16380 - max_char_len, 4095);

    return struct {
        len: u64,
        cur_len: u64 = 0,
        counting_writer: std.io.CountingWriter(WriterType),

        pub const Error = WriterType.Error;

        const Self = @This();

        pub fn start(self: *Self) Error!void {
            const writer = self.counting_writer.writer();
            if (self.len <= max_string_initializer_len) {
                try writer.writeByte('\"');
            } else {
                try writer.writeByte('{');
            }
        }

        pub fn end(self: *Self) Error!void {
            const writer = self.counting_writer.writer();
            if (self.len <= max_string_initializer_len) {
                try writer.writeByte('\"');
            } else {
                try writer.writeByte('}');
            }
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
            if (self.len <= max_string_initializer_len) {
                if (self.cur_len == 0 and self.counting_writer.bytes_written > 1)
                    try writer.writeAll("\"\"");

                const len = self.counting_writer.bytes_written;
                try writeStringLiteralChar(writer, c);

                const char_length = self.counting_writer.bytes_written - len;
                assert(char_length <= max_char_len);
                self.cur_len += char_length;

                if (self.cur_len >= max_literal_len) self.cur_len = 0;
            } else {
                if (self.counting_writer.bytes_written > 1) try writer.writeByte(',');
                try writer.print("'\\x{x}'", .{c});
            }
        }
    };
}

fn stringLiteral(
    child_stream: anytype,
    len: u64,
) StringLiteral(@TypeOf(child_stream)) {
    return .{
        .len = len,
        .counting_writer = std.io.countingWriter(child_stream),
    };
}

const FormatStringContext = struct { str: []const u8, sentinel: ?u8 };
fn formatStringLiteral(
    data: FormatStringContext,
    comptime fmt: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    if (fmt.len != 1 or fmt[0] != 's') @compileError("Invalid fmt: " ++ fmt);

    var literal = stringLiteral(writer, data.str.len + @intFromBool(data.sentinel != null));
    try literal.start();
    for (data.str) |c| try literal.writeChar(c);
    if (data.sentinel) |sentinel| if (sentinel != 0) try literal.writeChar(sentinel);
    try literal.end();
}

fn fmtStringLiteral(str: []const u8, sentinel: ?u8) std.fmt.Formatter(formatStringLiteral) {
    return .{ .data = .{ .str = str, .sentinel = sentinel } };
}

fn undefPattern(comptime IntType: type) IntType {
    const int_info = @typeInfo(IntType).int;
    const UnsignedType = std.meta.Int(.unsigned, int_info.bits);
    return @as(IntType, @bitCast(@as(UnsignedType, (1 << (int_info.bits | 1)) / 3)));
}

const FormatIntLiteralContext = struct {
    dg: *DeclGen,
    int_info: InternPool.Key.IntType,
    kind: CType.Kind,
    ctype: CType,
    val: Value,
};
fn formatIntLiteral(
    data: FormatIntLiteralContext,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    const pt = data.dg.pt;
    const zcu = pt.zcu;
    const target = &data.dg.mod.resolved_target.result;
    const ctype_pool = &data.dg.ctype_pool;

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
    const int = if (data.val.isUndefDeep(zcu)) blk: {
        undef_limbs = try allocator.alloc(BigIntLimb, BigInt.calcTwosCompLimbCount(data.int_info.bits));
        @memset(undef_limbs, undefPattern(BigIntLimb));

        var undef_int = BigInt.Mutable{
            .limbs = undef_limbs,
            .len = undef_limbs.len,
            .positive = true,
        };
        undef_int.truncate(undef_int.toConst(), data.int_info.signedness, data.int_info.bits);
        break :blk undef_int.toConst();
    } else data.val.toBigInt(&int_buf, zcu);
    assert(int.fitsInTwosComp(data.int_info.signedness, data.int_info.bits));

    const c_bits: usize = @intCast(data.ctype.byteSize(ctype_pool, data.dg.mod) * 8);
    var one_limbs: [BigInt.calcLimbLen(1)]BigIntLimb = undefined;
    const one = BigInt.Mutable.init(&one_limbs, 1).toConst();

    var wrap = BigInt.Mutable{
        .limbs = try allocator.alloc(BigIntLimb, BigInt.calcTwosCompLimbCount(c_bits)),
        .len = undefined,
        .positive = undefined,
    };
    defer allocator.free(wrap.limbs);

    const c_limb_info: struct {
        ctype: CType,
        count: usize,
        endian: std.builtin.Endian,
        homogeneous: bool,
    } = switch (data.ctype.info(ctype_pool)) {
        .basic => |basic_info| switch (basic_info) {
            else => .{
                .ctype = CType.void,
                .count = 1,
                .endian = .little,
                .homogeneous = true,
            },
            .zig_u128, .zig_i128 => .{
                .ctype = CType.u64,
                .count = 2,
                .endian = .big,
                .homogeneous = false,
            },
        },
        .array => |array_info| .{
            .ctype = array_info.elem_ctype,
            .count = @intCast(array_info.len),
            .endian = target.cpu.arch.endian(),
            .homogeneous = true,
        },
        else => unreachable,
    };
    if (c_limb_info.count == 1) {
        if (wrap.addWrap(int, one, data.int_info.signedness, c_bits) or
            data.int_info.signedness == .signed and wrap.subWrap(int, one, data.int_info.signedness, c_bits))
            return writer.print("{s}_{s}", .{
                data.ctype.getStandardDefineAbbrev() orelse return writer.print("zig_{s}Int_{c}{d}", .{
                    if (int.positive) "max" else "min", signAbbrev(data.int_info.signedness), c_bits,
                }),
                if (int.positive) "MAX" else "MIN",
            });

        if (!int.positive) try writer.writeByte('-');
        try data.ctype.renderLiteralPrefix(writer, data.kind, ctype_pool);

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
        try data.ctype.renderLiteralPrefix(writer, data.kind, ctype_pool);
        wrap.convertToTwosComplement(int, data.int_info.signedness, c_bits);
        @memset(wrap.limbs[wrap.len..], 0);
        wrap.len = wrap.limbs.len;
        const limbs_per_c_limb = @divExact(wrap.len, c_limb_info.count);

        var c_limb_int_info = std.builtin.Type.Int{
            .signedness = undefined,
            .bits = @as(u16, @intCast(@divExact(c_bits, c_limb_info.count))),
        };
        var c_limb_ctype: CType = undefined;

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
                c_limb_ctype = c_limb_info.ctype.toSigned();

                c_limb_mut.positive = wrap.positive;
                c_limb_mut.truncate(
                    c_limb_mut.toConst(),
                    .signed,
                    data.int_info.bits - limb_i * @bitSizeOf(BigIntLimb),
                );
            } else {
                c_limb_int_info.signedness = .unsigned;
                c_limb_ctype = c_limb_info.ctype;
            }

            if (limb_offset > 0) try writer.writeAll(", ");
            try formatIntLiteral(.{
                .dg = data.dg,
                .int_info = c_limb_int_info,
                .kind = data.kind,
                .ctype = c_limb_ctype,
                .val = try pt.intValue_big(Type.comptime_int, c_limb_mut.toConst()),
            }, fmt, options, writer);
        }
    }
    try data.ctype.renderLiteralSuffix(writer, ctype_pool);
}

const Materialize = struct {
    local: CValue,

    pub fn start(f: *Function, inst: Air.Inst.Index, ty: Type, value: CValue) !Materialize {
        return .{ .local = switch (value) {
            .local_ref, .constant, .nav_ref, .undef => try f.moveCValue(inst, ty, value),
            .new_local => |local| .{ .local = local },
            else => value,
        } };
    }

    pub fn mat(self: Materialize, f: *Function, writer: anytype) !void {
        try f.writeCValue(writer, self.local, .Other);
    }

    pub fn end(self: Materialize, f: *Function, inst: Air.Inst.Index) !void {
        try f.freeCValue(inst, self.local);
    }
};

const Assignment = struct {
    ctype: CType,

    pub fn start(f: *Function, writer: anytype, ctype: CType) !Assignment {
        const self: Assignment = .{ .ctype = ctype };
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
                try f.renderCType(writer, self.ctype);
                try writer.writeAll("))");
            },
        }
        try writer.writeAll(";\n");
    }

    fn strategy(self: Assignment, f: *Function) enum { assign, memcpy } {
        return switch (self.ctype.info(&f.object.dg.ctype_pool)) {
            else => .assign,
            .array, .vector => .memcpy,
        };
    }
};

const Vectorize = struct {
    index: CValue = .none,

    pub fn start(f: *Function, inst: Air.Inst.Index, writer: anytype, ty: Type) !Vectorize {
        const pt = f.object.dg.pt;
        const zcu = pt.zcu;
        return if (ty.zigTypeTag(zcu) == .vector) index: {
            const local = try f.allocLocal(inst, Type.usize);

            try writer.writeAll("for (");
            try f.writeCValue(writer, local, .Other);
            try writer.print(" = {d}; ", .{try f.fmtIntLiteral(try pt.intValue(Type.usize, 0))});
            try f.writeCValue(writer, local, .Other);
            try writer.print(" < {d}; ", .{try f.fmtIntLiteral(try pt.intValue(Type.usize, ty.vectorLen(zcu)))});
            try f.writeCValue(writer, local, .Other);
            try writer.print(" += {d}) {{\n", .{try f.fmtIntLiteral(try pt.intValue(Type.usize, 1))});
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

fn lowersToArray(ty: Type, pt: Zcu.PerThread) bool {
    const zcu = pt.zcu;
    return switch (ty.zigTypeTag(zcu)) {
        .array, .vector => return true,
        else => return ty.isAbiInt(zcu) and toCIntBits(@as(u32, @intCast(ty.bitSize(zcu)))) == null,
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
        .new_local, .local => |l| l,
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
