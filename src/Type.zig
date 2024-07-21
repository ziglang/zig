//! Both types and values are canonically represented by a single 32-bit integer
//! which is an index into an `InternPool` data structure.
//! This struct abstracts around this storage by providing methods only
//! applicable to types rather than values in general.

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const Value = @import("Value.zig");
const assert = std.debug.assert;
const Target = std.Target;
const Zcu = @import("Zcu.zig");
/// Deprecated.
const Module = Zcu;
const log = std.log.scoped(.Type);
const target_util = @import("target.zig");
const Sema = @import("Sema.zig");
const InternPool = @import("InternPool.zig");
const Alignment = InternPool.Alignment;
const Zir = std.zig.Zir;
const Type = @This();
const SemaError = Zcu.SemaError;

ip_index: InternPool.Index,

pub fn zigTypeTag(ty: Type, mod: *const Module) std.builtin.TypeId {
    return ty.zigTypeTagOrPoison(mod) catch unreachable;
}

pub fn zigTypeTagOrPoison(ty: Type, mod: *const Module) error{GenericPoison}!std.builtin.TypeId {
    return mod.intern_pool.zigTypeTagOrPoison(ty.toIntern());
}

pub fn baseZigTypeTag(self: Type, mod: *Module) std.builtin.TypeId {
    return switch (self.zigTypeTag(mod)) {
        .ErrorUnion => self.errorUnionPayload(mod).baseZigTypeTag(mod),
        .Optional => {
            return self.optionalChild(mod).baseZigTypeTag(mod);
        },
        else => |t| t,
    };
}

pub fn isSelfComparable(ty: Type, mod: *const Module, is_equality_cmp: bool) bool {
    return switch (ty.zigTypeTag(mod)) {
        .Int,
        .Float,
        .ComptimeFloat,
        .ComptimeInt,
        => true,

        .Vector => ty.elemType2(mod).isSelfComparable(mod, is_equality_cmp),

        .Bool,
        .Type,
        .Void,
        .ErrorSet,
        .Fn,
        .Opaque,
        .AnyFrame,
        .Enum,
        .EnumLiteral,
        => is_equality_cmp,

        .NoReturn,
        .Array,
        .Struct,
        .Undefined,
        .Null,
        .ErrorUnion,
        .Union,
        .Frame,
        => false,

        .Pointer => !ty.isSlice(mod) and (is_equality_cmp or ty.isCPtr(mod)),
        .Optional => {
            if (!is_equality_cmp) return false;
            return ty.optionalChild(mod).isSelfComparable(mod, is_equality_cmp);
        },
    };
}

/// If it is a function pointer, returns the function type. Otherwise returns null.
pub fn castPtrToFn(ty: Type, mod: *const Module) ?Type {
    if (ty.zigTypeTag(mod) != .Pointer) return null;
    const elem_ty = ty.childType(mod);
    if (elem_ty.zigTypeTag(mod) != .Fn) return null;
    return elem_ty;
}

/// Asserts the type is a pointer.
pub fn ptrIsMutable(ty: Type, mod: *const Module) bool {
    return !mod.intern_pool.indexToKey(ty.toIntern()).ptr_type.flags.is_const;
}

pub const ArrayInfo = struct {
    elem_type: Type,
    sentinel: ?Value = null,
    len: u64,
};

pub fn arrayInfo(self: Type, mod: *const Module) ArrayInfo {
    return .{
        .len = self.arrayLen(mod),
        .sentinel = self.sentinel(mod),
        .elem_type = self.childType(mod),
    };
}

pub fn ptrInfo(ty: Type, mod: *const Module) InternPool.Key.PtrType {
    return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
        .ptr_type => |p| p,
        .opt_type => |child| switch (mod.intern_pool.indexToKey(child)) {
            .ptr_type => |p| p,
            else => unreachable,
        },
        else => unreachable,
    };
}

pub fn eql(a: Type, b: Type, mod: *const Module) bool {
    _ = mod; // TODO: remove this parameter
    // The InternPool data structure hashes based on Key to make interned objects
    // unique. An Index can be treated simply as u32 value for the
    // purpose of Type/Value hashing and equality.
    return a.toIntern() == b.toIntern();
}

pub fn format(ty: Type, comptime unused_fmt_string: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    _ = ty;
    _ = unused_fmt_string;
    _ = options;
    _ = writer;
    @compileError("do not format types directly; use either ty.fmtDebug() or ty.fmt()");
}

pub const Formatter = std.fmt.Formatter(format2);

pub fn fmt(ty: Type, pt: Zcu.PerThread) Formatter {
    return .{ .data = .{
        .ty = ty,
        .pt = pt,
    } };
}

const FormatContext = struct {
    ty: Type,
    pt: Zcu.PerThread,
};

fn format2(
    ctx: FormatContext,
    comptime unused_format_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    comptime assert(unused_format_string.len == 0);
    _ = options;
    return print(ctx.ty, writer, ctx.pt);
}

pub fn fmtDebug(ty: Type) std.fmt.Formatter(dump) {
    return .{ .data = ty };
}

/// This is a debug function. In order to print types in a meaningful way
/// we also need access to the module.
pub fn dump(
    start_type: Type,
    comptime unused_format_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    _ = options;
    comptime assert(unused_format_string.len == 0);
    return writer.print("{any}", .{start_type.ip_index});
}

/// Prints a name suitable for `@typeName`.
/// TODO: take an `opt_sema` to pass to `fmtValue` when printing sentinels.
pub fn print(ty: Type, writer: anytype, pt: Zcu.PerThread) @TypeOf(writer).Error!void {
    const mod = pt.zcu;
    const ip = &mod.intern_pool;
    switch (ip.indexToKey(ty.toIntern())) {
        .int_type => |int_type| {
            const sign_char: u8 = switch (int_type.signedness) {
                .signed => 'i',
                .unsigned => 'u',
            };
            return writer.print("{c}{d}", .{ sign_char, int_type.bits });
        },
        .ptr_type => {
            const info = ty.ptrInfo(mod);

            if (info.sentinel != .none) switch (info.flags.size) {
                .One, .C => unreachable,
                .Many => try writer.print("[*:{}]", .{Value.fromInterned(info.sentinel).fmtValue(pt)}),
                .Slice => try writer.print("[:{}]", .{Value.fromInterned(info.sentinel).fmtValue(pt)}),
            } else switch (info.flags.size) {
                .One => try writer.writeAll("*"),
                .Many => try writer.writeAll("[*]"),
                .C => try writer.writeAll("[*c]"),
                .Slice => try writer.writeAll("[]"),
            }
            if (info.flags.alignment != .none or
                info.packed_offset.host_size != 0 or
                info.flags.vector_index != .none)
            {
                const alignment = if (info.flags.alignment != .none)
                    info.flags.alignment
                else
                    Type.fromInterned(info.child).abiAlignment(pt);
                try writer.print("align({d}", .{alignment.toByteUnits() orelse 0});

                if (info.packed_offset.bit_offset != 0 or info.packed_offset.host_size != 0) {
                    try writer.print(":{d}:{d}", .{
                        info.packed_offset.bit_offset, info.packed_offset.host_size,
                    });
                }
                if (info.flags.vector_index == .runtime) {
                    try writer.writeAll(":?");
                } else if (info.flags.vector_index != .none) {
                    try writer.print(":{d}", .{@intFromEnum(info.flags.vector_index)});
                }
                try writer.writeAll(") ");
            }
            if (info.flags.address_space != .generic) {
                try writer.print("addrspace(.{s}) ", .{@tagName(info.flags.address_space)});
            }
            if (info.flags.is_const) try writer.writeAll("const ");
            if (info.flags.is_volatile) try writer.writeAll("volatile ");
            if (info.flags.is_allowzero and info.flags.size != .C) try writer.writeAll("allowzero ");

            try print(Type.fromInterned(info.child), writer, pt);
            return;
        },
        .array_type => |array_type| {
            if (array_type.sentinel == .none) {
                try writer.print("[{d}]", .{array_type.len});
                try print(Type.fromInterned(array_type.child), writer, pt);
            } else {
                try writer.print("[{d}:{}]", .{
                    array_type.len,
                    Value.fromInterned(array_type.sentinel).fmtValue(pt),
                });
                try print(Type.fromInterned(array_type.child), writer, pt);
            }
            return;
        },
        .vector_type => |vector_type| {
            try writer.print("@Vector({d}, ", .{vector_type.len});
            try print(Type.fromInterned(vector_type.child), writer, pt);
            try writer.writeAll(")");
            return;
        },
        .opt_type => |child| {
            try writer.writeByte('?');
            return print(Type.fromInterned(child), writer, pt);
        },
        .error_union_type => |error_union_type| {
            try print(Type.fromInterned(error_union_type.error_set_type), writer, pt);
            try writer.writeByte('!');
            if (error_union_type.payload_type == .generic_poison_type) {
                try writer.writeAll("anytype");
            } else {
                try print(Type.fromInterned(error_union_type.payload_type), writer, pt);
            }
            return;
        },
        .inferred_error_set_type => |func_index| {
            const owner_decl = mod.funcOwnerDeclPtr(func_index);
            try writer.print("@typeInfo(@typeInfo(@TypeOf({})).Fn.return_type.?).ErrorUnion.error_set", .{
                owner_decl.fqn.fmt(ip),
            });
        },
        .error_set_type => |error_set_type| {
            const names = error_set_type.names;
            try writer.writeAll("error{");
            for (names.get(ip), 0..) |name, i| {
                if (i != 0) try writer.writeByte(',');
                try writer.print("{}", .{name.fmt(ip)});
            }
            try writer.writeAll("}");
        },
        .simple_type => |s| switch (s) {
            .f16,
            .f32,
            .f64,
            .f80,
            .f128,
            .usize,
            .isize,
            .c_char,
            .c_short,
            .c_ushort,
            .c_int,
            .c_uint,
            .c_long,
            .c_ulong,
            .c_longlong,
            .c_ulonglong,
            .c_longdouble,
            .anyopaque,
            .bool,
            .void,
            .type,
            .anyerror,
            .comptime_int,
            .comptime_float,
            .noreturn,
            .adhoc_inferred_error_set,
            => return writer.writeAll(@tagName(s)),

            .null,
            .undefined,
            => try writer.print("@TypeOf({s})", .{@tagName(s)}),

            .enum_literal => try writer.print("@TypeOf(.{s})", .{@tagName(s)}),
            .atomic_order => try writer.writeAll("std.builtin.AtomicOrder"),
            .atomic_rmw_op => try writer.writeAll("std.builtin.AtomicRmwOp"),
            .calling_convention => try writer.writeAll("std.builtin.CallingConvention"),
            .address_space => try writer.writeAll("std.builtin.AddressSpace"),
            .float_mode => try writer.writeAll("std.builtin.FloatMode"),
            .reduce_op => try writer.writeAll("std.builtin.ReduceOp"),
            .call_modifier => try writer.writeAll("std.builtin.CallModifier"),
            .prefetch_options => try writer.writeAll("std.builtin.PrefetchOptions"),
            .export_options => try writer.writeAll("std.builtin.ExportOptions"),
            .extern_options => try writer.writeAll("std.builtin.ExternOptions"),
            .type_info => try writer.writeAll("std.builtin.Type"),

            .generic_poison => unreachable,
        },
        .struct_type => {
            const struct_type = ip.loadStructType(ty.toIntern());
            if (struct_type.decl.unwrap()) |decl_index| {
                const decl = mod.declPtr(decl_index);
                try writer.print("{}", .{decl.fqn.fmt(ip)});
            } else if (ip.loadStructType(ty.toIntern()).namespace.unwrap()) |namespace_index| {
                const namespace = mod.namespacePtr(namespace_index);
                try namespace.renderFullyQualifiedName(ip, .empty, writer);
            } else {
                try writer.writeAll("@TypeOf(.{})");
            }
        },
        .anon_struct_type => |anon_struct| {
            if (anon_struct.types.len == 0) {
                return writer.writeAll("@TypeOf(.{})");
            }
            try writer.writeAll("struct{");
            for (anon_struct.types.get(ip), anon_struct.values.get(ip), 0..) |field_ty, val, i| {
                if (i != 0) try writer.writeAll(", ");
                if (val != .none) {
                    try writer.writeAll("comptime ");
                }
                if (anon_struct.names.len != 0) {
                    try writer.print("{}: ", .{anon_struct.names.get(ip)[i].fmt(&mod.intern_pool)});
                }

                try print(Type.fromInterned(field_ty), writer, pt);

                if (val != .none) {
                    try writer.print(" = {}", .{Value.fromInterned(val).fmtValue(pt)});
                }
            }
            try writer.writeAll("}");
        },

        .union_type => {
            const decl = mod.declPtr(ip.loadUnionType(ty.toIntern()).decl);
            try writer.print("{}", .{decl.fqn.fmt(ip)});
        },
        .opaque_type => {
            const decl = mod.declPtr(ip.loadOpaqueType(ty.toIntern()).decl);
            try writer.print("{}", .{decl.fqn.fmt(ip)});
        },
        .enum_type => {
            const decl = mod.declPtr(ip.loadEnumType(ty.toIntern()).decl);
            try writer.print("{}", .{decl.fqn.fmt(ip)});
        },
        .func_type => |fn_info| {
            if (fn_info.is_noinline) {
                try writer.writeAll("noinline ");
            }
            try writer.writeAll("fn (");
            const param_types = fn_info.param_types.get(&mod.intern_pool);
            for (param_types, 0..) |param_ty, i| {
                if (i != 0) try writer.writeAll(", ");
                if (std.math.cast(u5, i)) |index| {
                    if (fn_info.paramIsComptime(index)) {
                        try writer.writeAll("comptime ");
                    }
                    if (fn_info.paramIsNoalias(index)) {
                        try writer.writeAll("noalias ");
                    }
                }
                if (param_ty == .generic_poison_type) {
                    try writer.writeAll("anytype");
                } else {
                    try print(Type.fromInterned(param_ty), writer, pt);
                }
            }
            if (fn_info.is_var_args) {
                if (param_types.len != 0) {
                    try writer.writeAll(", ");
                }
                try writer.writeAll("...");
            }
            try writer.writeAll(") ");
            if (fn_info.cc != .Unspecified) {
                try writer.writeAll("callconv(.");
                try writer.writeAll(@tagName(fn_info.cc));
                try writer.writeAll(") ");
            }
            if (fn_info.return_type == .generic_poison_type) {
                try writer.writeAll("anytype");
            } else {
                try print(Type.fromInterned(fn_info.return_type), writer, pt);
            }
        },
        .anyframe_type => |child| {
            if (child == .none) return writer.writeAll("anyframe");
            try writer.writeAll("anyframe->");
            return print(Type.fromInterned(child), writer, pt);
        },

        // values, not types
        .undef,
        .simple_value,
        .variable,
        .extern_func,
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
        // memoization, not types
        .memoized_call,
        => unreachable,
    }
}

pub fn fromInterned(i: InternPool.Index) Type {
    assert(i != .none);
    return .{ .ip_index = i };
}

pub fn toIntern(ty: Type) InternPool.Index {
    assert(ty.ip_index != .none);
    return ty.ip_index;
}

pub fn toValue(self: Type) Value {
    return Value.fromInterned(self.toIntern());
}

const RuntimeBitsError = SemaError || error{NeedLazy};

/// true if and only if the type takes up space in memory at runtime.
/// There are two reasons a type will return false:
/// * the type is a comptime-only type. For example, the type `type` itself.
///   - note, however, that a struct can have mixed fields and only the non-comptime-only
///     fields will count towards the ABI size. For example, `struct {T: type, x: i32}`
///     hasRuntimeBits()=true and abiSize()=4
/// * the type has only one possible value, making its ABI size 0.
///   - an enum with an explicit tag type has the ABI size of the integer tag type,
///     making it one-possible-value only if the integer tag type has 0 bits.
/// When `ignore_comptime_only` is true, then types that are comptime-only
/// may return false positives.
pub fn hasRuntimeBitsAdvanced(
    ty: Type,
    pt: Zcu.PerThread,
    ignore_comptime_only: bool,
    comptime strat: ResolveStratLazy,
) RuntimeBitsError!bool {
    const mod = pt.zcu;
    const ip = &mod.intern_pool;
    return switch (ty.toIntern()) {
        // False because it is a comptime-only type.
        .empty_struct_type => false,
        else => switch (ip.indexToKey(ty.toIntern())) {
            .int_type => |int_type| int_type.bits != 0,
            .ptr_type => {
                // Pointers to zero-bit types still have a runtime address; however, pointers
                // to comptime-only types do not, with the exception of function pointers.
                if (ignore_comptime_only) return true;
                return switch (strat) {
                    .sema => !try ty.comptimeOnlyAdvanced(pt, .sema),
                    .eager => !ty.comptimeOnly(pt),
                    .lazy => error.NeedLazy,
                };
            },
            .anyframe_type => true,
            .array_type => |array_type| return array_type.lenIncludingSentinel() > 0 and
                try Type.fromInterned(array_type.child).hasRuntimeBitsAdvanced(pt, ignore_comptime_only, strat),
            .vector_type => |vector_type| return vector_type.len > 0 and
                try Type.fromInterned(vector_type.child).hasRuntimeBitsAdvanced(pt, ignore_comptime_only, strat),
            .opt_type => |child| {
                const child_ty = Type.fromInterned(child);
                if (child_ty.isNoReturn(mod)) {
                    // Then the optional is comptime-known to be null.
                    return false;
                }
                if (ignore_comptime_only) return true;
                return switch (strat) {
                    .sema => !try child_ty.comptimeOnlyAdvanced(pt, .sema),
                    .eager => !child_ty.comptimeOnly(pt),
                    .lazy => error.NeedLazy,
                };
            },
            .error_union_type,
            .error_set_type,
            .inferred_error_set_type,
            => true,

            // These are function *bodies*, not pointers.
            // They return false here because they are comptime-only types.
            // Special exceptions have to be made when emitting functions due to
            // this returning false.
            .func_type => false,

            .simple_type => |t| switch (t) {
                .f16,
                .f32,
                .f64,
                .f80,
                .f128,
                .usize,
                .isize,
                .c_char,
                .c_short,
                .c_ushort,
                .c_int,
                .c_uint,
                .c_long,
                .c_ulong,
                .c_longlong,
                .c_ulonglong,
                .c_longdouble,
                .bool,
                .anyerror,
                .adhoc_inferred_error_set,
                .anyopaque,
                .atomic_order,
                .atomic_rmw_op,
                .calling_convention,
                .address_space,
                .float_mode,
                .reduce_op,
                .call_modifier,
                .prefetch_options,
                .export_options,
                .extern_options,
                => true,

                // These are false because they are comptime-only types.
                .void,
                .type,
                .comptime_int,
                .comptime_float,
                .noreturn,
                .null,
                .undefined,
                .enum_literal,
                .type_info,
                => false,

                .generic_poison => unreachable,
            },
            .struct_type => {
                const struct_type = ip.loadStructType(ty.toIntern());
                if (struct_type.assumeRuntimeBitsIfFieldTypesWip(ip)) {
                    // In this case, we guess that hasRuntimeBits() for this type is true,
                    // and then later if our guess was incorrect, we emit a compile error.
                    return true;
                }
                switch (strat) {
                    .sema => try ty.resolveFields(pt),
                    .eager => assert(struct_type.haveFieldTypes(ip)),
                    .lazy => if (!struct_type.haveFieldTypes(ip)) return error.NeedLazy,
                }
                for (0..struct_type.field_types.len) |i| {
                    if (struct_type.comptime_bits.getBit(ip, i)) continue;
                    const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[i]);
                    if (try field_ty.hasRuntimeBitsAdvanced(pt, ignore_comptime_only, strat))
                        return true;
                } else {
                    return false;
                }
            },
            .anon_struct_type => |tuple| {
                for (tuple.types.get(ip), tuple.values.get(ip)) |field_ty, val| {
                    if (val != .none) continue; // comptime field
                    if (try Type.fromInterned(field_ty).hasRuntimeBitsAdvanced(pt, ignore_comptime_only, strat)) return true;
                }
                return false;
            },

            .union_type => {
                const union_type = ip.loadUnionType(ty.toIntern());
                const union_flags = union_type.flagsUnordered(ip);
                switch (union_flags.runtime_tag) {
                    .none => {
                        // In this case, we guess that hasRuntimeBits() for this type is true,
                        // and then later if our guess was incorrect, we emit a compile error.
                        if (union_type.assumeRuntimeBitsIfFieldTypesWip(ip)) return true;
                    },
                    .safety, .tagged => {
                        const tag_ty = union_type.tagTypeUnordered(ip);
                        // tag_ty will be `none` if this union's tag type is not resolved yet,
                        // in which case we want control flow to continue down below.
                        if (tag_ty != .none and
                            try Type.fromInterned(tag_ty).hasRuntimeBitsAdvanced(pt, ignore_comptime_only, strat))
                        {
                            return true;
                        }
                    },
                }
                switch (strat) {
                    .sema => try ty.resolveFields(pt),
                    .eager => assert(union_flags.status.haveFieldTypes()),
                    .lazy => if (!union_flags.status.haveFieldTypes())
                        return error.NeedLazy,
                }
                for (0..union_type.field_types.len) |field_index| {
                    const field_ty = Type.fromInterned(union_type.field_types.get(ip)[field_index]);
                    if (try field_ty.hasRuntimeBitsAdvanced(pt, ignore_comptime_only, strat))
                        return true;
                } else {
                    return false;
                }
            },

            .opaque_type => true,
            .enum_type => Type.fromInterned(ip.loadEnumType(ty.toIntern()).tag_ty).hasRuntimeBitsAdvanced(pt, ignore_comptime_only, strat),

            // values, not types
            .undef,
            .simple_value,
            .variable,
            .extern_func,
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
            // memoization, not types
            .memoized_call,
            => unreachable,
        },
    };
}

/// true if and only if the type has a well-defined memory layout
/// readFrom/writeToMemory are supported only for types with a well-
/// defined memory layout
pub fn hasWellDefinedLayout(ty: Type, mod: *Module) bool {
    const ip = &mod.intern_pool;
    return switch (ip.indexToKey(ty.toIntern())) {
        .int_type,
        .vector_type,
        => true,

        .error_union_type,
        .error_set_type,
        .inferred_error_set_type,
        .anon_struct_type,
        .opaque_type,
        .anyframe_type,
        // These are function bodies, not function pointers.
        .func_type,
        => false,

        .array_type => |array_type| Type.fromInterned(array_type.child).hasWellDefinedLayout(mod),
        .opt_type => ty.isPtrLikeOptional(mod),
        .ptr_type => |ptr_type| ptr_type.flags.size != .Slice,

        .simple_type => |t| switch (t) {
            .f16,
            .f32,
            .f64,
            .f80,
            .f128,
            .usize,
            .isize,
            .c_char,
            .c_short,
            .c_ushort,
            .c_int,
            .c_uint,
            .c_long,
            .c_ulong,
            .c_longlong,
            .c_ulonglong,
            .c_longdouble,
            .bool,
            .void,
            => true,

            .anyerror,
            .adhoc_inferred_error_set,
            .anyopaque,
            .atomic_order,
            .atomic_rmw_op,
            .calling_convention,
            .address_space,
            .float_mode,
            .reduce_op,
            .call_modifier,
            .prefetch_options,
            .export_options,
            .extern_options,
            .type,
            .comptime_int,
            .comptime_float,
            .noreturn,
            .null,
            .undefined,
            .enum_literal,
            .type_info,
            .generic_poison,
            => false,
        },
        .struct_type => {
            const struct_type = ip.loadStructType(ty.toIntern());
            // Struct with no fields have a well-defined layout of no bits.
            return struct_type.layout != .auto or struct_type.field_types.len == 0;
        },
        .union_type => {
            const union_type = ip.loadUnionType(ty.toIntern());
            return switch (union_type.flagsUnordered(ip).runtime_tag) {
                .none, .safety => union_type.flagsUnordered(ip).layout != .auto,
                .tagged => false,
            };
        },
        .enum_type => switch (ip.loadEnumType(ty.toIntern()).tag_mode) {
            .auto => false,
            .explicit, .nonexhaustive => true,
        },

        // values, not types
        .undef,
        .simple_value,
        .variable,
        .extern_func,
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
        // memoization, not types
        .memoized_call,
        => unreachable,
    };
}

pub fn hasRuntimeBits(ty: Type, pt: Zcu.PerThread) bool {
    return hasRuntimeBitsAdvanced(ty, pt, false, .eager) catch unreachable;
}

pub fn hasRuntimeBitsIgnoreComptime(ty: Type, pt: Zcu.PerThread) bool {
    return hasRuntimeBitsAdvanced(ty, pt, true, .eager) catch unreachable;
}

pub fn fnHasRuntimeBits(ty: Type, pt: Zcu.PerThread) bool {
    return ty.fnHasRuntimeBitsAdvanced(pt, .normal) catch unreachable;
}

/// Determines whether a function type has runtime bits, i.e. whether a
/// function with this type can exist at runtime.
/// Asserts that `ty` is a function type.
pub fn fnHasRuntimeBitsAdvanced(ty: Type, pt: Zcu.PerThread, comptime strat: ResolveStrat) SemaError!bool {
    const fn_info = pt.zcu.typeToFunc(ty).?;
    if (fn_info.is_generic) return false;
    if (fn_info.is_var_args) return true;
    if (fn_info.cc == .Inline) return false;
    return !try Type.fromInterned(fn_info.return_type).comptimeOnlyAdvanced(pt, strat);
}

pub fn isFnOrHasRuntimeBits(ty: Type, pt: Zcu.PerThread) bool {
    switch (ty.zigTypeTag(pt.zcu)) {
        .Fn => return ty.fnHasRuntimeBits(pt),
        else => return ty.hasRuntimeBits(pt),
    }
}

/// Same as `isFnOrHasRuntimeBits` but comptime-only types may return a false positive.
pub fn isFnOrHasRuntimeBitsIgnoreComptime(ty: Type, pt: Zcu.PerThread) bool {
    return switch (ty.zigTypeTag(pt.zcu)) {
        .Fn => true,
        else => return ty.hasRuntimeBitsIgnoreComptime(pt),
    };
}

pub fn isNoReturn(ty: Type, mod: *Module) bool {
    return mod.intern_pool.isNoReturn(ty.toIntern());
}

/// Returns `none` if the pointer is naturally aligned and the element type is 0-bit.
pub fn ptrAlignment(ty: Type, pt: Zcu.PerThread) Alignment {
    return ptrAlignmentAdvanced(ty, pt, .normal) catch unreachable;
}

pub fn ptrAlignmentAdvanced(ty: Type, pt: Zcu.PerThread, comptime strat: ResolveStrat) !Alignment {
    return switch (pt.zcu.intern_pool.indexToKey(ty.toIntern())) {
        .ptr_type => |ptr_type| {
            if (ptr_type.flags.alignment != .none)
                return ptr_type.flags.alignment;

            if (strat == .sema) {
                const res = try Type.fromInterned(ptr_type.child).abiAlignmentAdvanced(pt, .sema);
                return res.scalar;
            }

            return (Type.fromInterned(ptr_type.child).abiAlignmentAdvanced(pt, .eager) catch unreachable).scalar;
        },
        .opt_type => |child| Type.fromInterned(child).ptrAlignmentAdvanced(pt, strat),
        else => unreachable,
    };
}

pub fn ptrAddressSpace(ty: Type, mod: *const Module) std.builtin.AddressSpace {
    return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
        .ptr_type => |ptr_type| ptr_type.flags.address_space,
        .opt_type => |child| mod.intern_pool.indexToKey(child).ptr_type.flags.address_space,
        else => unreachable,
    };
}

/// Never returns `none`. Asserts that all necessary type resolution is already done.
pub fn abiAlignment(ty: Type, pt: Zcu.PerThread) Alignment {
    return (ty.abiAlignmentAdvanced(pt, .eager) catch unreachable).scalar;
}

/// May capture a reference to `ty`.
/// Returned value has type `comptime_int`.
pub fn lazyAbiAlignment(ty: Type, pt: Zcu.PerThread) !Value {
    switch (try ty.abiAlignmentAdvanced(pt, .lazy)) {
        .val => |val| return val,
        .scalar => |x| return pt.intValue(Type.comptime_int, x.toByteUnits() orelse 0),
    }
}

pub const AbiAlignmentAdvanced = union(enum) {
    scalar: Alignment,
    val: Value,
};

pub const ResolveStratLazy = enum {
    /// Return a `lazy_size` or `lazy_align` value if necessary.
    /// This value can be resolved later using `Value.resolveLazy`.
    lazy,
    /// Return a scalar result, expecting all necessary type resolution to be completed.
    /// Backends should typically use this, since they must not perform type resolution.
    eager,
    /// Return a scalar result, performing type resolution as necessary.
    /// This should typically be used from semantic analysis.
    sema,
};

/// The chosen strategy can be easily optimized away in release builds.
/// However, in debug builds, it helps to avoid acceidentally resolving types in backends.
pub const ResolveStrat = enum {
    /// Assert that all necessary resolution is completed.
    /// Backends should typically use this, since they must not perform type resolution.
    normal,
    /// Perform type resolution as necessary using `Zcu`.
    /// This should typically be used from semantic analysis.
    sema,

    pub inline fn toLazy(strat: ResolveStrat) ResolveStratLazy {
        return switch (strat) {
            .normal => .eager,
            .sema => .sema,
        };
    }
};

/// If you pass `eager` you will get back `scalar` and assert the type is resolved.
/// In this case there will be no error, guaranteed.
/// If you pass `lazy` you may get back `scalar` or `val`.
/// If `val` is returned, a reference to `ty` has been captured.
/// If you pass `sema` you will get back `scalar` and resolve the type if
/// necessary, possibly returning a CompileError.
pub fn abiAlignmentAdvanced(
    ty: Type,
    pt: Zcu.PerThread,
    comptime strat: ResolveStratLazy,
) SemaError!AbiAlignmentAdvanced {
    const mod = pt.zcu;
    const target = mod.getTarget();
    const use_llvm = mod.comp.config.use_llvm;
    const ip = &mod.intern_pool;

    switch (ty.toIntern()) {
        .empty_struct_type => return .{ .scalar = .@"1" },
        else => switch (ip.indexToKey(ty.toIntern())) {
            .int_type => |int_type| {
                if (int_type.bits == 0) return .{ .scalar = .@"1" };
                return .{ .scalar = intAbiAlignment(int_type.bits, target, use_llvm) };
            },
            .ptr_type, .anyframe_type => {
                return .{ .scalar = ptrAbiAlignment(target) };
            },
            .array_type => |array_type| {
                return Type.fromInterned(array_type.child).abiAlignmentAdvanced(pt, strat);
            },
            .vector_type => |vector_type| {
                if (vector_type.len == 0) return .{ .scalar = .@"1" };
                switch (mod.comp.getZigBackend()) {
                    else => {
                        // This is fine because the child type of a vector always has a bit-size known
                        // without needing any type resolution.
                        const elem_bits: u32 = @intCast(Type.fromInterned(vector_type.child).bitSize(pt));
                        if (elem_bits == 0) return .{ .scalar = .@"1" };
                        const bytes = ((elem_bits * vector_type.len) + 7) / 8;
                        const alignment = std.math.ceilPowerOfTwoAssert(u32, bytes);
                        return .{ .scalar = Alignment.fromByteUnits(alignment) };
                    },
                    .stage2_c => {
                        return Type.fromInterned(vector_type.child).abiAlignmentAdvanced(pt, strat);
                    },
                    .stage2_x86_64 => {
                        if (vector_type.child == .bool_type) {
                            if (vector_type.len > 256 and std.Target.x86.featureSetHas(target.cpu.features, .avx512f)) return .{ .scalar = .@"64" };
                            if (vector_type.len > 128 and std.Target.x86.featureSetHas(target.cpu.features, .avx2)) return .{ .scalar = .@"32" };
                            if (vector_type.len > 64) return .{ .scalar = .@"16" };
                            const bytes = std.math.divCeil(u32, vector_type.len, 8) catch unreachable;
                            const alignment = std.math.ceilPowerOfTwoAssert(u32, bytes);
                            return .{ .scalar = Alignment.fromByteUnits(alignment) };
                        }
                        const elem_bytes: u32 = @intCast((try Type.fromInterned(vector_type.child).abiSizeAdvanced(pt, strat)).scalar);
                        if (elem_bytes == 0) return .{ .scalar = .@"1" };
                        const bytes = elem_bytes * vector_type.len;
                        if (bytes > 32 and std.Target.x86.featureSetHas(target.cpu.features, .avx512f)) return .{ .scalar = .@"64" };
                        if (bytes > 16 and std.Target.x86.featureSetHas(target.cpu.features, .avx)) return .{ .scalar = .@"32" };
                        return .{ .scalar = .@"16" };
                    },
                }
            },

            .opt_type => return ty.abiAlignmentAdvancedOptional(pt, strat),
            .error_union_type => |info| return ty.abiAlignmentAdvancedErrorUnion(pt, strat, Type.fromInterned(info.payload_type)),

            .error_set_type, .inferred_error_set_type => {
                const bits = mod.errorSetBits();
                if (bits == 0) return .{ .scalar = .@"1" };
                return .{ .scalar = intAbiAlignment(bits, target, use_llvm) };
            },

            // represents machine code; not a pointer
            .func_type => return .{ .scalar = target_util.defaultFunctionAlignment(target) },

            .simple_type => |t| switch (t) {
                .bool,
                .atomic_order,
                .atomic_rmw_op,
                .calling_convention,
                .address_space,
                .float_mode,
                .reduce_op,
                .call_modifier,
                .prefetch_options,
                .anyopaque,
                => return .{ .scalar = .@"1" },

                .usize,
                .isize,
                => return .{ .scalar = intAbiAlignment(target.ptrBitWidth(), target, use_llvm) },

                .export_options,
                .extern_options,
                .type_info,
                => return .{ .scalar = ptrAbiAlignment(target) },

                .c_char => return .{ .scalar = cTypeAlign(target, .char) },
                .c_short => return .{ .scalar = cTypeAlign(target, .short) },
                .c_ushort => return .{ .scalar = cTypeAlign(target, .ushort) },
                .c_int => return .{ .scalar = cTypeAlign(target, .int) },
                .c_uint => return .{ .scalar = cTypeAlign(target, .uint) },
                .c_long => return .{ .scalar = cTypeAlign(target, .long) },
                .c_ulong => return .{ .scalar = cTypeAlign(target, .ulong) },
                .c_longlong => return .{ .scalar = cTypeAlign(target, .longlong) },
                .c_ulonglong => return .{ .scalar = cTypeAlign(target, .ulonglong) },
                .c_longdouble => return .{ .scalar = cTypeAlign(target, .longdouble) },

                .f16 => return .{ .scalar = .@"2" },
                .f32 => return .{ .scalar = cTypeAlign(target, .float) },
                .f64 => switch (target.c_type_bit_size(.double)) {
                    64 => return .{ .scalar = cTypeAlign(target, .double) },
                    else => return .{ .scalar = .@"8" },
                },
                .f80 => switch (target.c_type_bit_size(.longdouble)) {
                    80 => return .{ .scalar = cTypeAlign(target, .longdouble) },
                    else => return .{ .scalar = Type.u80.abiAlignment(pt) },
                },
                .f128 => switch (target.c_type_bit_size(.longdouble)) {
                    128 => return .{ .scalar = cTypeAlign(target, .longdouble) },
                    else => return .{ .scalar = .@"16" },
                },

                .anyerror, .adhoc_inferred_error_set => {
                    const bits = mod.errorSetBits();
                    if (bits == 0) return .{ .scalar = .@"1" };
                    return .{ .scalar = intAbiAlignment(bits, target, use_llvm) };
                },

                .void,
                .type,
                .comptime_int,
                .comptime_float,
                .null,
                .undefined,
                .enum_literal,
                => return .{ .scalar = .@"1" },

                .noreturn => unreachable,
                .generic_poison => unreachable,
            },
            .struct_type => {
                const struct_type = ip.loadStructType(ty.toIntern());
                if (struct_type.layout == .@"packed") {
                    switch (strat) {
                        .sema => try ty.resolveLayout(pt),
                        .lazy => if (struct_type.backingIntTypeUnordered(ip) == .none) return .{
                            .val = Value.fromInterned(try pt.intern(.{ .int = .{
                                .ty = .comptime_int_type,
                                .storage = .{ .lazy_align = ty.toIntern() },
                            } })),
                        },
                        .eager => {},
                    }
                    return .{ .scalar = Type.fromInterned(struct_type.backingIntTypeUnordered(ip)).abiAlignment(pt) };
                }

                if (struct_type.flagsUnordered(ip).alignment == .none) switch (strat) {
                    .eager => unreachable, // struct alignment not resolved
                    .sema => try ty.resolveStructAlignment(pt),
                    .lazy => return .{ .val = Value.fromInterned(try pt.intern(.{ .int = .{
                        .ty = .comptime_int_type,
                        .storage = .{ .lazy_align = ty.toIntern() },
                    } })) },
                };

                return .{ .scalar = struct_type.flagsUnordered(ip).alignment };
            },
            .anon_struct_type => |tuple| {
                var big_align: Alignment = .@"1";
                for (tuple.types.get(ip), tuple.values.get(ip)) |field_ty, val| {
                    if (val != .none) continue; // comptime field
                    switch (try Type.fromInterned(field_ty).abiAlignmentAdvanced(pt, strat)) {
                        .scalar => |field_align| big_align = big_align.max(field_align),
                        .val => switch (strat) {
                            .eager => unreachable, // field type alignment not resolved
                            .sema => unreachable, // passed to abiAlignmentAdvanced above
                            .lazy => return .{ .val = Value.fromInterned(try pt.intern(.{ .int = .{
                                .ty = .comptime_int_type,
                                .storage = .{ .lazy_align = ty.toIntern() },
                            } })) },
                        },
                    }
                }
                return .{ .scalar = big_align };
            },
            .union_type => {
                const union_type = ip.loadUnionType(ty.toIntern());

                if (union_type.flagsUnordered(ip).alignment == .none) switch (strat) {
                    .eager => unreachable, // union layout not resolved
                    .sema => try ty.resolveUnionAlignment(pt),
                    .lazy => return .{ .val = Value.fromInterned(try pt.intern(.{ .int = .{
                        .ty = .comptime_int_type,
                        .storage = .{ .lazy_align = ty.toIntern() },
                    } })) },
                };

                return .{ .scalar = union_type.flagsUnordered(ip).alignment };
            },
            .opaque_type => return .{ .scalar = .@"1" },
            .enum_type => return .{
                .scalar = Type.fromInterned(ip.loadEnumType(ty.toIntern()).tag_ty).abiAlignment(pt),
            },

            // values, not types
            .undef,
            .simple_value,
            .variable,
            .extern_func,
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
            // memoization, not types
            .memoized_call,
            => unreachable,
        },
    }
}

fn abiAlignmentAdvancedErrorUnion(
    ty: Type,
    pt: Zcu.PerThread,
    comptime strat: ResolveStratLazy,
    payload_ty: Type,
) SemaError!AbiAlignmentAdvanced {
    // This code needs to be kept in sync with the equivalent switch prong
    // in abiSizeAdvanced.
    const code_align = Type.anyerror.abiAlignment(pt);
    switch (strat) {
        .eager, .sema => {
            if (!(payload_ty.hasRuntimeBitsAdvanced(pt, false, strat) catch |err| switch (err) {
                error.NeedLazy => return .{ .val = Value.fromInterned(try pt.intern(.{ .int = .{
                    .ty = .comptime_int_type,
                    .storage = .{ .lazy_align = ty.toIntern() },
                } })) },
                else => |e| return e,
            })) {
                return .{ .scalar = code_align };
            }
            return .{ .scalar = code_align.max(
                (try payload_ty.abiAlignmentAdvanced(pt, strat)).scalar,
            ) };
        },
        .lazy => {
            switch (try payload_ty.abiAlignmentAdvanced(pt, strat)) {
                .scalar => |payload_align| return .{ .scalar = code_align.max(payload_align) },
                .val => {},
            }
            return .{ .val = Value.fromInterned(try pt.intern(.{ .int = .{
                .ty = .comptime_int_type,
                .storage = .{ .lazy_align = ty.toIntern() },
            } })) };
        },
    }
}

fn abiAlignmentAdvancedOptional(
    ty: Type,
    pt: Zcu.PerThread,
    comptime strat: ResolveStratLazy,
) SemaError!AbiAlignmentAdvanced {
    const mod = pt.zcu;
    const target = mod.getTarget();
    const child_type = ty.optionalChild(mod);

    switch (child_type.zigTypeTag(mod)) {
        .Pointer => return .{ .scalar = ptrAbiAlignment(target) },
        .ErrorSet => return Type.anyerror.abiAlignmentAdvanced(pt, strat),
        .NoReturn => return .{ .scalar = .@"1" },
        else => {},
    }

    switch (strat) {
        .eager, .sema => {
            if (!(child_type.hasRuntimeBitsAdvanced(pt, false, strat) catch |err| switch (err) {
                error.NeedLazy => return .{ .val = Value.fromInterned(try pt.intern(.{ .int = .{
                    .ty = .comptime_int_type,
                    .storage = .{ .lazy_align = ty.toIntern() },
                } })) },
                else => |e| return e,
            })) {
                return .{ .scalar = .@"1" };
            }
            return child_type.abiAlignmentAdvanced(pt, strat);
        },
        .lazy => switch (try child_type.abiAlignmentAdvanced(pt, strat)) {
            .scalar => |x| return .{ .scalar = x.max(.@"1") },
            .val => return .{ .val = Value.fromInterned(try pt.intern(.{ .int = .{
                .ty = .comptime_int_type,
                .storage = .{ .lazy_align = ty.toIntern() },
            } })) },
        },
    }
}

/// May capture a reference to `ty`.
pub fn lazyAbiSize(ty: Type, pt: Zcu.PerThread) !Value {
    switch (try ty.abiSizeAdvanced(pt, .lazy)) {
        .val => |val| return val,
        .scalar => |x| return pt.intValue(Type.comptime_int, x),
    }
}

/// Asserts the type has the ABI size already resolved.
/// Types that return false for hasRuntimeBits() return 0.
pub fn abiSize(ty: Type, pt: Zcu.PerThread) u64 {
    return (abiSizeAdvanced(ty, pt, .eager) catch unreachable).scalar;
}

const AbiSizeAdvanced = union(enum) {
    scalar: u64,
    val: Value,
};

/// If you pass `eager` you will get back `scalar` and assert the type is resolved.
/// In this case there will be no error, guaranteed.
/// If you pass `lazy` you may get back `scalar` or `val`.
/// If `val` is returned, a reference to `ty` has been captured.
/// If you pass `sema` you will get back `scalar` and resolve the type if
/// necessary, possibly returning a CompileError.
pub fn abiSizeAdvanced(
    ty: Type,
    pt: Zcu.PerThread,
    comptime strat: ResolveStratLazy,
) SemaError!AbiSizeAdvanced {
    const mod = pt.zcu;
    const target = mod.getTarget();
    const use_llvm = mod.comp.config.use_llvm;
    const ip = &mod.intern_pool;

    switch (ty.toIntern()) {
        .empty_struct_type => return .{ .scalar = 0 },

        else => switch (ip.indexToKey(ty.toIntern())) {
            .int_type => |int_type| {
                if (int_type.bits == 0) return .{ .scalar = 0 };
                return .{ .scalar = intAbiSize(int_type.bits, target, use_llvm) };
            },
            .ptr_type => |ptr_type| switch (ptr_type.flags.size) {
                .Slice => return .{ .scalar = @divExact(target.ptrBitWidth(), 8) * 2 },
                else => return .{ .scalar = @divExact(target.ptrBitWidth(), 8) },
            },
            .anyframe_type => return .{ .scalar = @divExact(target.ptrBitWidth(), 8) },

            .array_type => |array_type| {
                const len = array_type.lenIncludingSentinel();
                if (len == 0) return .{ .scalar = 0 };
                switch (try Type.fromInterned(array_type.child).abiSizeAdvanced(pt, strat)) {
                    .scalar => |elem_size| return .{ .scalar = len * elem_size },
                    .val => switch (strat) {
                        .sema, .eager => unreachable,
                        .lazy => return .{ .val = Value.fromInterned(try pt.intern(.{ .int = .{
                            .ty = .comptime_int_type,
                            .storage = .{ .lazy_size = ty.toIntern() },
                        } })) },
                    },
                }
            },
            .vector_type => |vector_type| {
                const sub_strat: ResolveStrat = switch (strat) {
                    .sema => .sema,
                    .eager => .normal,
                    .lazy => return .{ .val = Value.fromInterned(try pt.intern(.{ .int = .{
                        .ty = .comptime_int_type,
                        .storage = .{ .lazy_size = ty.toIntern() },
                    } })) },
                };
                const alignment = switch (try ty.abiAlignmentAdvanced(pt, strat)) {
                    .scalar => |x| x,
                    .val => return .{ .val = Value.fromInterned(try pt.intern(.{ .int = .{
                        .ty = .comptime_int_type,
                        .storage = .{ .lazy_size = ty.toIntern() },
                    } })) },
                };
                const total_bytes = switch (mod.comp.getZigBackend()) {
                    else => total_bytes: {
                        const elem_bits = try Type.fromInterned(vector_type.child).bitSizeAdvanced(pt, sub_strat);
                        const total_bits = elem_bits * vector_type.len;
                        break :total_bytes (total_bits + 7) / 8;
                    },
                    .stage2_c => total_bytes: {
                        const elem_bytes: u32 = @intCast((try Type.fromInterned(vector_type.child).abiSizeAdvanced(pt, strat)).scalar);
                        break :total_bytes elem_bytes * vector_type.len;
                    },
                    .stage2_x86_64 => total_bytes: {
                        if (vector_type.child == .bool_type) break :total_bytes std.math.divCeil(u32, vector_type.len, 8) catch unreachable;
                        const elem_bytes: u32 = @intCast((try Type.fromInterned(vector_type.child).abiSizeAdvanced(pt, strat)).scalar);
                        break :total_bytes elem_bytes * vector_type.len;
                    },
                };
                return .{ .scalar = alignment.forward(total_bytes) };
            },

            .opt_type => return ty.abiSizeAdvancedOptional(pt, strat),

            .error_set_type, .inferred_error_set_type => {
                const bits = mod.errorSetBits();
                if (bits == 0) return .{ .scalar = 0 };
                return .{ .scalar = intAbiSize(bits, target, use_llvm) };
            },

            .error_union_type => |error_union_type| {
                const payload_ty = Type.fromInterned(error_union_type.payload_type);
                // This code needs to be kept in sync with the equivalent switch prong
                // in abiAlignmentAdvanced.
                const code_size = Type.anyerror.abiSize(pt);
                if (!(payload_ty.hasRuntimeBitsAdvanced(pt, false, strat) catch |err| switch (err) {
                    error.NeedLazy => return .{ .val = Value.fromInterned(try pt.intern(.{ .int = .{
                        .ty = .comptime_int_type,
                        .storage = .{ .lazy_size = ty.toIntern() },
                    } })) },
                    else => |e| return e,
                })) {
                    // Same as anyerror.
                    return .{ .scalar = code_size };
                }
                const code_align = Type.anyerror.abiAlignment(pt);
                const payload_align = payload_ty.abiAlignment(pt);
                const payload_size = switch (try payload_ty.abiSizeAdvanced(pt, strat)) {
                    .scalar => |elem_size| elem_size,
                    .val => switch (strat) {
                        .sema => unreachable,
                        .eager => unreachable,
                        .lazy => return .{ .val = Value.fromInterned(try pt.intern(.{ .int = .{
                            .ty = .comptime_int_type,
                            .storage = .{ .lazy_size = ty.toIntern() },
                        } })) },
                    },
                };

                var size: u64 = 0;
                if (code_align.compare(.gt, payload_align)) {
                    size += code_size;
                    size = payload_align.forward(size);
                    size += payload_size;
                    size = code_align.forward(size);
                } else {
                    size += payload_size;
                    size = code_align.forward(size);
                    size += code_size;
                    size = payload_align.forward(size);
                }
                return .{ .scalar = size };
            },
            .func_type => unreachable, // represents machine code; not a pointer
            .simple_type => |t| switch (t) {
                .bool,
                .atomic_order,
                .atomic_rmw_op,
                .calling_convention,
                .address_space,
                .float_mode,
                .reduce_op,
                .call_modifier,
                => return .{ .scalar = 1 },

                .f16 => return .{ .scalar = 2 },
                .f32 => return .{ .scalar = 4 },
                .f64 => return .{ .scalar = 8 },
                .f128 => return .{ .scalar = 16 },
                .f80 => switch (target.c_type_bit_size(.longdouble)) {
                    80 => return .{ .scalar = target.c_type_byte_size(.longdouble) },
                    else => return .{ .scalar = Type.u80.abiSize(pt) },
                },

                .usize,
                .isize,
                => return .{ .scalar = @divExact(target.ptrBitWidth(), 8) },

                .c_char => return .{ .scalar = target.c_type_byte_size(.char) },
                .c_short => return .{ .scalar = target.c_type_byte_size(.short) },
                .c_ushort => return .{ .scalar = target.c_type_byte_size(.ushort) },
                .c_int => return .{ .scalar = target.c_type_byte_size(.int) },
                .c_uint => return .{ .scalar = target.c_type_byte_size(.uint) },
                .c_long => return .{ .scalar = target.c_type_byte_size(.long) },
                .c_ulong => return .{ .scalar = target.c_type_byte_size(.ulong) },
                .c_longlong => return .{ .scalar = target.c_type_byte_size(.longlong) },
                .c_ulonglong => return .{ .scalar = target.c_type_byte_size(.ulonglong) },
                .c_longdouble => return .{ .scalar = target.c_type_byte_size(.longdouble) },

                .anyopaque,
                .void,
                .type,
                .comptime_int,
                .comptime_float,
                .null,
                .undefined,
                .enum_literal,
                => return .{ .scalar = 0 },

                .anyerror, .adhoc_inferred_error_set => {
                    const bits = mod.errorSetBits();
                    if (bits == 0) return .{ .scalar = 0 };
                    return .{ .scalar = intAbiSize(bits, target, use_llvm) };
                },

                .prefetch_options => unreachable, // missing call to resolveTypeFields
                .export_options => unreachable, // missing call to resolveTypeFields
                .extern_options => unreachable, // missing call to resolveTypeFields

                .type_info => unreachable,
                .noreturn => unreachable,
                .generic_poison => unreachable,
            },
            .struct_type => {
                const struct_type = ip.loadStructType(ty.toIntern());
                switch (strat) {
                    .sema => try ty.resolveLayout(pt),
                    .lazy => switch (struct_type.layout) {
                        .@"packed" => {
                            if (struct_type.backingIntTypeUnordered(ip) == .none) return .{
                                .val = Value.fromInterned(try pt.intern(.{ .int = .{
                                    .ty = .comptime_int_type,
                                    .storage = .{ .lazy_size = ty.toIntern() },
                                } })),
                            };
                        },
                        .auto, .@"extern" => {
                            if (!struct_type.haveLayout(ip)) return .{
                                .val = Value.fromInterned(try pt.intern(.{ .int = .{
                                    .ty = .comptime_int_type,
                                    .storage = .{ .lazy_size = ty.toIntern() },
                                } })),
                            };
                        },
                    },
                    .eager => {},
                }
                switch (struct_type.layout) {
                    .@"packed" => return .{
                        .scalar = Type.fromInterned(struct_type.backingIntTypeUnordered(ip)).abiSize(pt),
                    },
                    .auto, .@"extern" => {
                        assert(struct_type.haveLayout(ip));
                        return .{ .scalar = struct_type.sizeUnordered(ip) };
                    },
                }
            },
            .anon_struct_type => |tuple| {
                switch (strat) {
                    .sema => try ty.resolveLayout(pt),
                    .lazy, .eager => {},
                }
                const field_count = tuple.types.len;
                if (field_count == 0) {
                    return .{ .scalar = 0 };
                }
                return .{ .scalar = ty.structFieldOffset(field_count, pt) };
            },

            .union_type => {
                const union_type = ip.loadUnionType(ty.toIntern());
                switch (strat) {
                    .sema => try ty.resolveLayout(pt),
                    .lazy => if (!union_type.flagsUnordered(ip).status.haveLayout()) return .{
                        .val = Value.fromInterned(try pt.intern(.{ .int = .{
                            .ty = .comptime_int_type,
                            .storage = .{ .lazy_size = ty.toIntern() },
                        } })),
                    },
                    .eager => {},
                }

                assert(union_type.haveLayout(ip));
                return .{ .scalar = union_type.sizeUnordered(ip) };
            },
            .opaque_type => unreachable, // no size available
            .enum_type => return .{ .scalar = Type.fromInterned(ip.loadEnumType(ty.toIntern()).tag_ty).abiSize(pt) },

            // values, not types
            .undef,
            .simple_value,
            .variable,
            .extern_func,
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
            // memoization, not types
            .memoized_call,
            => unreachable,
        },
    }
}

fn abiSizeAdvancedOptional(
    ty: Type,
    pt: Zcu.PerThread,
    comptime strat: ResolveStratLazy,
) SemaError!AbiSizeAdvanced {
    const mod = pt.zcu;
    const child_ty = ty.optionalChild(mod);

    if (child_ty.isNoReturn(mod)) {
        return .{ .scalar = 0 };
    }

    if (!(child_ty.hasRuntimeBitsAdvanced(pt, false, strat) catch |err| switch (err) {
        error.NeedLazy => return .{ .val = Value.fromInterned(try pt.intern(.{ .int = .{
            .ty = .comptime_int_type,
            .storage = .{ .lazy_size = ty.toIntern() },
        } })) },
        else => |e| return e,
    })) return .{ .scalar = 1 };

    if (ty.optionalReprIsPayload(mod)) {
        return child_ty.abiSizeAdvanced(pt, strat);
    }

    const payload_size = switch (try child_ty.abiSizeAdvanced(pt, strat)) {
        .scalar => |elem_size| elem_size,
        .val => switch (strat) {
            .sema => unreachable,
            .eager => unreachable,
            .lazy => return .{ .val = Value.fromInterned(try pt.intern(.{ .int = .{
                .ty = .comptime_int_type,
                .storage = .{ .lazy_size = ty.toIntern() },
            } })) },
        },
    };

    // Optional types are represented as a struct with the child type as the first
    // field and a boolean as the second. Since the child type's abi alignment is
    // guaranteed to be >= that of bool's (1 byte) the added size is exactly equal
    // to the child type's ABI alignment.
    return .{
        .scalar = (child_ty.abiAlignment(pt).toByteUnits() orelse 0) + payload_size,
    };
}

pub fn ptrAbiAlignment(target: Target) Alignment {
    return Alignment.fromNonzeroByteUnits(@divExact(target.ptrBitWidth(), 8));
}

pub fn intAbiSize(bits: u16, target: Target, use_llvm: bool) u64 {
    return intAbiAlignment(bits, target, use_llvm).forward(@as(u16, @intCast((@as(u17, bits) + 7) / 8)));
}

pub fn intAbiAlignment(bits: u16, target: Target, use_llvm: bool) Alignment {
    return switch (target.cpu.arch) {
        .x86 => switch (bits) {
            0 => .none,
            1...8 => .@"1",
            9...16 => .@"2",
            17...64 => .@"4",
            else => .@"16",
        },
        .x86_64 => switch (bits) {
            0 => .none,
            1...8 => .@"1",
            9...16 => .@"2",
            17...32 => .@"4",
            33...64 => .@"8",
            else => switch (target_util.zigBackend(target, use_llvm)) {
                .stage2_x86_64 => .@"8",
                else => .@"16",
            },
        },
        else => return Alignment.fromByteUnits(@min(
            std.math.ceilPowerOfTwoPromote(u16, @as(u16, @intCast((@as(u17, bits) + 7) / 8))),
            maxIntAlignment(target, use_llvm),
        )),
    };
}

pub fn maxIntAlignment(target: std.Target, use_llvm: bool) u16 {
    return switch (target.cpu.arch) {
        .avr => 1,
        .msp430 => 2,
        .xcore => 4,

        .arm,
        .armeb,
        .thumb,
        .thumbeb,
        .hexagon,
        .mips,
        .mipsel,
        .powerpc,
        .powerpcle,
        .amdgcn,
        .riscv32,
        .sparc,
        .sparcel,
        .s390x,
        .lanai,
        .wasm32,
        .wasm64,
        => 8,

        // For these, LLVMABIAlignmentOfType(i128) reports 8. Note that 16
        // is a relevant number in three cases:
        // 1. Different machine code instruction when loading into SIMD register.
        // 2. The C ABI wants 16 for extern structs.
        // 3. 16-byte cmpxchg needs 16-byte alignment.
        // Same logic for powerpc64, mips64, sparc64.
        .powerpc64,
        .powerpc64le,
        .mips64,
        .mips64el,
        .sparc64,
        => switch (target.ofmt) {
            .c => 16,
            else => 8,
        },

        .x86_64 => switch (target_util.zigBackend(target, use_llvm)) {
            .stage2_x86_64 => 8,
            else => 16,
        },

        // Even LLVMABIAlignmentOfType(i128) agrees on these targets.
        .x86,
        .aarch64,
        .aarch64_be,
        .aarch64_32,
        .riscv64,
        .bpfel,
        .bpfeb,
        .nvptx,
        .nvptx64,
        => 16,

        // Below this comment are unverified but based on the fact that C requires
        // int128_t to be 16 bytes aligned, it's a safe default.
        .spu_2,
        .csky,
        .arc,
        .m68k,
        .tce,
        .tcele,
        .spir,
        .kalimba,
        .spirv,
        .spirv32,
        .shave,
        .spir64,
        .ve,
        .spirv64,
        .dxil,
        .loongarch32,
        .loongarch64,
        .xtensa,
        => 16,
    };
}

pub fn bitSize(ty: Type, pt: Zcu.PerThread) u64 {
    return bitSizeAdvanced(ty, pt, .normal) catch unreachable;
}

pub fn bitSizeAdvanced(
    ty: Type,
    pt: Zcu.PerThread,
    comptime strat: ResolveStrat,
) SemaError!u64 {
    const mod = pt.zcu;
    const target = mod.getTarget();
    const ip = &mod.intern_pool;

    const strat_lazy: ResolveStratLazy = strat.toLazy();

    switch (ip.indexToKey(ty.toIntern())) {
        .int_type => |int_type| return int_type.bits,
        .ptr_type => |ptr_type| switch (ptr_type.flags.size) {
            .Slice => return target.ptrBitWidth() * 2,
            else => return target.ptrBitWidth(),
        },
        .anyframe_type => return target.ptrBitWidth(),

        .array_type => |array_type| {
            const len = array_type.lenIncludingSentinel();
            if (len == 0) return 0;
            const elem_ty = Type.fromInterned(array_type.child);
            const elem_size = @max(
                (try elem_ty.abiAlignmentAdvanced(pt, strat_lazy)).scalar.toByteUnits() orelse 0,
                (try elem_ty.abiSizeAdvanced(pt, strat_lazy)).scalar,
            );
            if (elem_size == 0) return 0;
            const elem_bit_size = try elem_ty.bitSizeAdvanced(pt, strat);
            return (len - 1) * 8 * elem_size + elem_bit_size;
        },
        .vector_type => |vector_type| {
            const child_ty = Type.fromInterned(vector_type.child);
            const elem_bit_size = try child_ty.bitSizeAdvanced(pt, strat);
            return elem_bit_size * vector_type.len;
        },
        .opt_type => {
            // Optionals and error unions are not packed so their bitsize
            // includes padding bits.
            return (try ty.abiSizeAdvanced(pt, strat_lazy)).scalar * 8;
        },

        .error_set_type, .inferred_error_set_type => return mod.errorSetBits(),

        .error_union_type => {
            // Optionals and error unions are not packed so their bitsize
            // includes padding bits.
            return (try ty.abiSizeAdvanced(pt, strat_lazy)).scalar * 8;
        },
        .func_type => unreachable, // represents machine code; not a pointer
        .simple_type => |t| switch (t) {
            .f16 => return 16,
            .f32 => return 32,
            .f64 => return 64,
            .f80 => return 80,
            .f128 => return 128,

            .usize,
            .isize,
            => return target.ptrBitWidth(),

            .c_char => return target.c_type_bit_size(.char),
            .c_short => return target.c_type_bit_size(.short),
            .c_ushort => return target.c_type_bit_size(.ushort),
            .c_int => return target.c_type_bit_size(.int),
            .c_uint => return target.c_type_bit_size(.uint),
            .c_long => return target.c_type_bit_size(.long),
            .c_ulong => return target.c_type_bit_size(.ulong),
            .c_longlong => return target.c_type_bit_size(.longlong),
            .c_ulonglong => return target.c_type_bit_size(.ulonglong),
            .c_longdouble => return target.c_type_bit_size(.longdouble),

            .bool => return 1,
            .void => return 0,

            .anyerror,
            .adhoc_inferred_error_set,
            => return mod.errorSetBits(),

            .anyopaque => unreachable,
            .type => unreachable,
            .comptime_int => unreachable,
            .comptime_float => unreachable,
            .noreturn => unreachable,
            .null => unreachable,
            .undefined => unreachable,
            .enum_literal => unreachable,
            .generic_poison => unreachable,

            .atomic_order => unreachable,
            .atomic_rmw_op => unreachable,
            .calling_convention => unreachable,
            .address_space => unreachable,
            .float_mode => unreachable,
            .reduce_op => unreachable,
            .call_modifier => unreachable,
            .prefetch_options => unreachable,
            .export_options => unreachable,
            .extern_options => unreachable,
            .type_info => unreachable,
        },
        .struct_type => {
            const struct_type = ip.loadStructType(ty.toIntern());
            const is_packed = struct_type.layout == .@"packed";
            if (strat == .sema) {
                try ty.resolveFields(pt);
                if (is_packed) try ty.resolveLayout(pt);
            }
            if (is_packed) {
                return try Type.fromInterned(struct_type.backingIntTypeUnordered(ip)).bitSizeAdvanced(pt, strat);
            }
            return (try ty.abiSizeAdvanced(pt, strat_lazy)).scalar * 8;
        },

        .anon_struct_type => {
            if (strat == .sema) try ty.resolveFields(pt);
            return (try ty.abiSizeAdvanced(pt, strat_lazy)).scalar * 8;
        },

        .union_type => {
            const union_type = ip.loadUnionType(ty.toIntern());
            const is_packed = ty.containerLayout(mod) == .@"packed";
            if (strat == .sema) {
                try ty.resolveFields(pt);
                if (is_packed) try ty.resolveLayout(pt);
            }
            if (!is_packed) {
                return (try ty.abiSizeAdvanced(pt, strat_lazy)).scalar * 8;
            }
            assert(union_type.flagsUnordered(ip).status.haveFieldTypes());

            var size: u64 = 0;
            for (0..union_type.field_types.len) |field_index| {
                const field_ty = union_type.field_types.get(ip)[field_index];
                size = @max(size, try Type.fromInterned(field_ty).bitSizeAdvanced(pt, strat));
            }

            return size;
        },
        .opaque_type => unreachable,
        .enum_type => return Type.fromInterned(ip.loadEnumType(ty.toIntern()).tag_ty).bitSizeAdvanced(pt, strat),

        // values, not types
        .undef,
        .simple_value,
        .variable,
        .extern_func,
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
        // memoization, not types
        .memoized_call,
        => unreachable,
    }
}

/// Returns true if the type's layout is already resolved and it is safe
/// to use `abiSize`, `abiAlignment` and `bitSize` on it.
pub fn layoutIsResolved(ty: Type, mod: *Module) bool {
    const ip = &mod.intern_pool;
    return switch (ip.indexToKey(ty.toIntern())) {
        .struct_type => ip.loadStructType(ty.toIntern()).haveLayout(ip),
        .union_type => ip.loadUnionType(ty.toIntern()).haveLayout(ip),
        .array_type => |array_type| {
            if (array_type.lenIncludingSentinel() == 0) return true;
            return Type.fromInterned(array_type.child).layoutIsResolved(mod);
        },
        .opt_type => |child| Type.fromInterned(child).layoutIsResolved(mod),
        .error_union_type => |k| Type.fromInterned(k.payload_type).layoutIsResolved(mod),
        else => true,
    };
}

pub fn isSinglePointer(ty: Type, mod: *const Module) bool {
    return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
        .ptr_type => |ptr_info| ptr_info.flags.size == .One,
        else => false,
    };
}

/// Asserts `ty` is a pointer.
pub fn ptrSize(ty: Type, mod: *const Module) std.builtin.Type.Pointer.Size {
    return ty.ptrSizeOrNull(mod).?;
}

/// Returns `null` if `ty` is not a pointer.
pub fn ptrSizeOrNull(ty: Type, mod: *const Module) ?std.builtin.Type.Pointer.Size {
    return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
        .ptr_type => |ptr_info| ptr_info.flags.size,
        else => null,
    };
}

pub fn isSlice(ty: Type, mod: *const Module) bool {
    return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
        .ptr_type => |ptr_type| ptr_type.flags.size == .Slice,
        else => false,
    };
}

pub fn slicePtrFieldType(ty: Type, mod: *const Module) Type {
    return Type.fromInterned(mod.intern_pool.slicePtrType(ty.toIntern()));
}

pub fn isConstPtr(ty: Type, mod: *const Module) bool {
    return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
        .ptr_type => |ptr_type| ptr_type.flags.is_const,
        else => false,
    };
}

pub fn isVolatilePtr(ty: Type, mod: *const Module) bool {
    return isVolatilePtrIp(ty, &mod.intern_pool);
}

pub fn isVolatilePtrIp(ty: Type, ip: *const InternPool) bool {
    return switch (ip.indexToKey(ty.toIntern())) {
        .ptr_type => |ptr_type| ptr_type.flags.is_volatile,
        else => false,
    };
}

pub fn isAllowzeroPtr(ty: Type, mod: *const Module) bool {
    return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
        .ptr_type => |ptr_type| ptr_type.flags.is_allowzero,
        .opt_type => true,
        else => false,
    };
}

pub fn isCPtr(ty: Type, mod: *const Module) bool {
    return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
        .ptr_type => |ptr_type| ptr_type.flags.size == .C,
        else => false,
    };
}

pub fn isPtrAtRuntime(ty: Type, mod: *const Module) bool {
    return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
        .ptr_type => |ptr_type| switch (ptr_type.flags.size) {
            .Slice => false,
            .One, .Many, .C => true,
        },
        .opt_type => |child| switch (mod.intern_pool.indexToKey(child)) {
            .ptr_type => |p| switch (p.flags.size) {
                .Slice, .C => false,
                .Many, .One => !p.flags.is_allowzero,
            },
            else => false,
        },
        else => false,
    };
}

/// For pointer-like optionals, returns true, otherwise returns the allowzero property
/// of pointers.
pub fn ptrAllowsZero(ty: Type, mod: *const Module) bool {
    if (ty.isPtrLikeOptional(mod)) {
        return true;
    }
    return ty.ptrInfo(mod).flags.is_allowzero;
}

/// See also `isPtrLikeOptional`.
pub fn optionalReprIsPayload(ty: Type, mod: *const Module) bool {
    return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
        .opt_type => |child_type| child_type == .anyerror_type or switch (mod.intern_pool.indexToKey(child_type)) {
            .ptr_type => |ptr_type| ptr_type.flags.size != .C and !ptr_type.flags.is_allowzero,
            .error_set_type, .inferred_error_set_type => true,
            else => false,
        },
        .ptr_type => |ptr_type| ptr_type.flags.size == .C,
        else => false,
    };
}

/// Returns true if the type is optional and would be lowered to a single pointer
/// address value, using 0 for null. Note that this returns true for C pointers.
/// This function must be kept in sync with `Sema.typePtrOrOptionalPtrTy`.
pub fn isPtrLikeOptional(ty: Type, mod: *const Module) bool {
    return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
        .ptr_type => |ptr_type| ptr_type.flags.size == .C,
        .opt_type => |child| switch (mod.intern_pool.indexToKey(child)) {
            .ptr_type => |ptr_type| switch (ptr_type.flags.size) {
                .Slice, .C => false,
                .Many, .One => !ptr_type.flags.is_allowzero,
            },
            else => false,
        },
        else => false,
    };
}

/// For *[N]T,  returns [N]T.
/// For *T,     returns T.
/// For [*]T,   returns T.
pub fn childType(ty: Type, mod: *const Module) Type {
    return childTypeIp(ty, &mod.intern_pool);
}

pub fn childTypeIp(ty: Type, ip: *const InternPool) Type {
    return Type.fromInterned(ip.childType(ty.toIntern()));
}

/// For *[N]T,       returns T.
/// For ?*T,         returns T.
/// For ?*[N]T,      returns T.
/// For ?[*]T,       returns T.
/// For *T,          returns T.
/// For [*]T,        returns T.
/// For [N]T,        returns T.
/// For []T,         returns T.
/// For anyframe->T, returns T.
pub fn elemType2(ty: Type, mod: *const Module) Type {
    return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
        .ptr_type => |ptr_type| switch (ptr_type.flags.size) {
            .One => Type.fromInterned(ptr_type.child).shallowElemType(mod),
            .Many, .C, .Slice => Type.fromInterned(ptr_type.child),
        },
        .anyframe_type => |child| {
            assert(child != .none);
            return Type.fromInterned(child);
        },
        .vector_type => |vector_type| Type.fromInterned(vector_type.child),
        .array_type => |array_type| Type.fromInterned(array_type.child),
        .opt_type => |child| Type.fromInterned(mod.intern_pool.childType(child)),
        else => unreachable,
    };
}

fn shallowElemType(child_ty: Type, mod: *const Module) Type {
    return switch (child_ty.zigTypeTag(mod)) {
        .Array, .Vector => child_ty.childType(mod),
        else => child_ty,
    };
}

/// For vectors, returns the element type. Otherwise returns self.
pub fn scalarType(ty: Type, mod: *Module) Type {
    return switch (ty.zigTypeTag(mod)) {
        .Vector => ty.childType(mod),
        else => ty,
    };
}

/// Asserts that the type is an optional.
/// Note that for C pointers this returns the type unmodified.
pub fn optionalChild(ty: Type, mod: *const Module) Type {
    return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
        .opt_type => |child| Type.fromInterned(child),
        .ptr_type => |ptr_type| b: {
            assert(ptr_type.flags.size == .C);
            break :b ty;
        },
        else => unreachable,
    };
}

/// Returns the tag type of a union, if the type is a union and it has a tag type.
/// Otherwise, returns `null`.
pub fn unionTagType(ty: Type, mod: *Module) ?Type {
    const ip = &mod.intern_pool;
    switch (ip.indexToKey(ty.toIntern())) {
        .union_type => {},
        else => return null,
    }
    const union_type = ip.loadUnionType(ty.toIntern());
    const union_flags = union_type.flagsUnordered(ip);
    switch (union_flags.runtime_tag) {
        .tagged => {
            assert(union_flags.status.haveFieldTypes());
            return Type.fromInterned(union_type.enum_tag_ty);
        },
        else => return null,
    }
}

/// Same as `unionTagType` but includes safety tag.
/// Codegen should use this version.
pub fn unionTagTypeSafety(ty: Type, mod: *Module) ?Type {
    const ip = &mod.intern_pool;
    return switch (ip.indexToKey(ty.toIntern())) {
        .union_type => {
            const union_type = ip.loadUnionType(ty.toIntern());
            if (!union_type.hasTag(ip)) return null;
            assert(union_type.haveFieldTypes(ip));
            return Type.fromInterned(union_type.enum_tag_ty);
        },
        else => null,
    };
}

/// Asserts the type is a union; returns the tag type, even if the tag will
/// not be stored at runtime.
pub fn unionTagTypeHypothetical(ty: Type, mod: *Module) Type {
    const union_obj = mod.typeToUnion(ty).?;
    return Type.fromInterned(union_obj.enum_tag_ty);
}

pub fn unionFieldType(ty: Type, enum_tag: Value, mod: *Module) ?Type {
    const ip = &mod.intern_pool;
    const union_obj = mod.typeToUnion(ty).?;
    const union_fields = union_obj.field_types.get(ip);
    const index = mod.unionTagFieldIndex(union_obj, enum_tag) orelse return null;
    return Type.fromInterned(union_fields[index]);
}

pub fn unionFieldTypeByIndex(ty: Type, index: usize, mod: *Module) Type {
    const ip = &mod.intern_pool;
    const union_obj = mod.typeToUnion(ty).?;
    return Type.fromInterned(union_obj.field_types.get(ip)[index]);
}

pub fn unionTagFieldIndex(ty: Type, enum_tag: Value, mod: *Module) ?u32 {
    const union_obj = mod.typeToUnion(ty).?;
    return mod.unionTagFieldIndex(union_obj, enum_tag);
}

pub fn unionHasAllZeroBitFieldTypes(ty: Type, pt: Zcu.PerThread) bool {
    const ip = &pt.zcu.intern_pool;
    const union_obj = pt.zcu.typeToUnion(ty).?;
    for (union_obj.field_types.get(ip)) |field_ty| {
        if (Type.fromInterned(field_ty).hasRuntimeBits(pt)) return false;
    }
    return true;
}

/// Returns the type used for backing storage of this union during comptime operations.
/// Asserts the type is either an extern or packed union.
pub fn unionBackingType(ty: Type, pt: Zcu.PerThread) !Type {
    return switch (ty.containerLayout(pt.zcu)) {
        .@"extern" => try pt.arrayType(.{ .len = ty.abiSize(pt), .child = .u8_type }),
        .@"packed" => try pt.intType(.unsigned, @intCast(ty.bitSize(pt))),
        .auto => unreachable,
    };
}

pub fn unionGetLayout(ty: Type, pt: Zcu.PerThread) Module.UnionLayout {
    const union_obj = pt.zcu.intern_pool.loadUnionType(ty.toIntern());
    return pt.getUnionLayout(union_obj);
}

pub fn containerLayout(ty: Type, mod: *Module) std.builtin.Type.ContainerLayout {
    const ip = &mod.intern_pool;
    return switch (ip.indexToKey(ty.toIntern())) {
        .struct_type => ip.loadStructType(ty.toIntern()).layout,
        .anon_struct_type => .auto,
        .union_type => ip.loadUnionType(ty.toIntern()).flagsUnordered(ip).layout,
        else => unreachable,
    };
}

/// Asserts that the type is an error union.
pub fn errorUnionPayload(ty: Type, mod: *Module) Type {
    return Type.fromInterned(mod.intern_pool.indexToKey(ty.toIntern()).error_union_type.payload_type);
}

/// Asserts that the type is an error union.
pub fn errorUnionSet(ty: Type, mod: *Module) Type {
    return Type.fromInterned(mod.intern_pool.errorUnionSet(ty.toIntern()));
}

/// Returns false for unresolved inferred error sets.
pub fn errorSetIsEmpty(ty: Type, mod: *Module) bool {
    const ip = &mod.intern_pool;
    return switch (ty.toIntern()) {
        .anyerror_type, .adhoc_inferred_error_set_type => false,
        else => switch (ip.indexToKey(ty.toIntern())) {
            .error_set_type => |error_set_type| error_set_type.names.len == 0,
            .inferred_error_set_type => |i| switch (ip.funcIesResolvedUnordered(i)) {
                .none, .anyerror_type => false,
                else => |t| ip.indexToKey(t).error_set_type.names.len == 0,
            },
            else => unreachable,
        },
    };
}

/// Returns true if it is an error set that includes anyerror, false otherwise.
/// Note that the result may be a false negative if the type did not get error set
/// resolution prior to this call.
pub fn isAnyError(ty: Type, mod: *Module) bool {
    const ip = &mod.intern_pool;
    return switch (ty.toIntern()) {
        .anyerror_type => true,
        .adhoc_inferred_error_set_type => false,
        else => switch (mod.intern_pool.indexToKey(ty.toIntern())) {
            .inferred_error_set_type => |i| ip.funcIesResolvedUnordered(i) == .anyerror_type,
            else => false,
        },
    };
}

pub fn isError(ty: Type, mod: *const Module) bool {
    return switch (ty.zigTypeTag(mod)) {
        .ErrorUnion, .ErrorSet => true,
        else => false,
    };
}

/// Returns whether ty, which must be an error set, includes an error `name`.
/// Might return a false negative if `ty` is an inferred error set and not fully
/// resolved yet.
pub fn errorSetHasFieldIp(
    ip: *const InternPool,
    ty: InternPool.Index,
    name: InternPool.NullTerminatedString,
) bool {
    return switch (ty) {
        .anyerror_type => true,
        else => switch (ip.indexToKey(ty)) {
            .error_set_type => |error_set_type| error_set_type.nameIndex(ip, name) != null,
            .inferred_error_set_type => |i| switch (ip.funcIesResolvedUnordered(i)) {
                .anyerror_type => true,
                .none => false,
                else => |t| ip.indexToKey(t).error_set_type.nameIndex(ip, name) != null,
            },
            else => unreachable,
        },
    };
}

/// Returns whether ty, which must be an error set, includes an error `name`.
/// Might return a false negative if `ty` is an inferred error set and not fully
/// resolved yet.
pub fn errorSetHasField(ty: Type, name: []const u8, mod: *Module) bool {
    const ip = &mod.intern_pool;
    return switch (ty.toIntern()) {
        .anyerror_type => true,
        else => switch (ip.indexToKey(ty.toIntern())) {
            .error_set_type => |error_set_type| {
                // If the string is not interned, then the field certainly is not present.
                const field_name_interned = ip.getString(name).unwrap() orelse return false;
                return error_set_type.nameIndex(ip, field_name_interned) != null;
            },
            .inferred_error_set_type => |i| switch (ip.funcIesResolved(i).*) {
                .anyerror_type => true,
                .none => false,
                else => |t| {
                    // If the string is not interned, then the field certainly is not present.
                    const field_name_interned = ip.getString(name).unwrap() orelse return false;
                    return ip.indexToKey(t).error_set_type.nameIndex(ip, field_name_interned) != null;
                },
            },
            else => unreachable,
        },
    };
}

/// Asserts the type is an array or vector or struct.
pub fn arrayLen(ty: Type, mod: *const Module) u64 {
    return ty.arrayLenIp(&mod.intern_pool);
}

pub fn arrayLenIp(ty: Type, ip: *const InternPool) u64 {
    return ip.aggregateTypeLen(ty.toIntern());
}

pub fn arrayLenIncludingSentinel(ty: Type, mod: *const Module) u64 {
    return mod.intern_pool.aggregateTypeLenIncludingSentinel(ty.toIntern());
}

pub fn vectorLen(ty: Type, mod: *const Module) u32 {
    return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
        .vector_type => |vector_type| vector_type.len,
        .anon_struct_type => |tuple| @intCast(tuple.types.len),
        else => unreachable,
    };
}

/// Asserts the type is an array, pointer or vector.
pub fn sentinel(ty: Type, mod: *const Module) ?Value {
    return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
        .vector_type,
        .struct_type,
        .anon_struct_type,
        => null,

        .array_type => |t| if (t.sentinel != .none) Value.fromInterned(t.sentinel) else null,
        .ptr_type => |t| if (t.sentinel != .none) Value.fromInterned(t.sentinel) else null,

        else => unreachable,
    };
}

/// Returns true if and only if the type is a fixed-width integer.
pub fn isInt(self: Type, mod: *const Module) bool {
    return self.toIntern() != .comptime_int_type and
        mod.intern_pool.isIntegerType(self.toIntern());
}

/// Returns true if and only if the type is a fixed-width, signed integer.
pub fn isSignedInt(ty: Type, mod: *const Module) bool {
    return switch (ty.toIntern()) {
        .c_char_type => mod.getTarget().charSignedness() == .signed,
        .isize_type, .c_short_type, .c_int_type, .c_long_type, .c_longlong_type => true,
        else => switch (mod.intern_pool.indexToKey(ty.toIntern())) {
            .int_type => |int_type| int_type.signedness == .signed,
            else => false,
        },
    };
}

/// Returns true if and only if the type is a fixed-width, unsigned integer.
pub fn isUnsignedInt(ty: Type, mod: *const Module) bool {
    return switch (ty.toIntern()) {
        .c_char_type => mod.getTarget().charSignedness() == .unsigned,
        .usize_type, .c_ushort_type, .c_uint_type, .c_ulong_type, .c_ulonglong_type => true,
        else => switch (mod.intern_pool.indexToKey(ty.toIntern())) {
            .int_type => |int_type| int_type.signedness == .unsigned,
            else => false,
        },
    };
}

/// Returns true for integers, enums, error sets, and packed structs.
/// If this function returns true, then intInfo() can be called on the type.
pub fn isAbiInt(ty: Type, mod: *Module) bool {
    return switch (ty.zigTypeTag(mod)) {
        .Int, .Enum, .ErrorSet => true,
        .Struct => ty.containerLayout(mod) == .@"packed",
        else => false,
    };
}

/// Asserts the type is an integer, enum, error set, or vector of one of them.
pub fn intInfo(starting_ty: Type, mod: *Module) InternPool.Key.IntType {
    const ip = &mod.intern_pool;
    const target = mod.getTarget();
    var ty = starting_ty;

    while (true) switch (ty.toIntern()) {
        .anyerror_type, .adhoc_inferred_error_set_type => {
            return .{ .signedness = .unsigned, .bits = mod.errorSetBits() };
        },
        .usize_type => return .{ .signedness = .unsigned, .bits = target.ptrBitWidth() },
        .isize_type => return .{ .signedness = .signed, .bits = target.ptrBitWidth() },
        .c_char_type => return .{ .signedness = mod.getTarget().charSignedness(), .bits = target.c_type_bit_size(.char) },
        .c_short_type => return .{ .signedness = .signed, .bits = target.c_type_bit_size(.short) },
        .c_ushort_type => return .{ .signedness = .unsigned, .bits = target.c_type_bit_size(.ushort) },
        .c_int_type => return .{ .signedness = .signed, .bits = target.c_type_bit_size(.int) },
        .c_uint_type => return .{ .signedness = .unsigned, .bits = target.c_type_bit_size(.uint) },
        .c_long_type => return .{ .signedness = .signed, .bits = target.c_type_bit_size(.long) },
        .c_ulong_type => return .{ .signedness = .unsigned, .bits = target.c_type_bit_size(.ulong) },
        .c_longlong_type => return .{ .signedness = .signed, .bits = target.c_type_bit_size(.longlong) },
        .c_ulonglong_type => return .{ .signedness = .unsigned, .bits = target.c_type_bit_size(.ulonglong) },
        else => switch (ip.indexToKey(ty.toIntern())) {
            .int_type => |int_type| return int_type,
            .struct_type => ty = Type.fromInterned(ip.loadStructType(ty.toIntern()).backingIntTypeUnordered(ip)),
            .enum_type => ty = Type.fromInterned(ip.loadEnumType(ty.toIntern()).tag_ty),
            .vector_type => |vector_type| ty = Type.fromInterned(vector_type.child),

            .error_set_type, .inferred_error_set_type => {
                return .{ .signedness = .unsigned, .bits = mod.errorSetBits() };
            },

            .anon_struct_type => unreachable,

            .ptr_type => unreachable,
            .anyframe_type => unreachable,
            .array_type => unreachable,

            .opt_type => unreachable,
            .error_union_type => unreachable,
            .func_type => unreachable,
            .simple_type => unreachable, // handled via Index enum tag above

            .union_type => unreachable,
            .opaque_type => unreachable,

            // values, not types
            .undef,
            .simple_value,
            .variable,
            .extern_func,
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
            // memoization, not types
            .memoized_call,
            => unreachable,
        },
    };
}

pub fn isNamedInt(ty: Type) bool {
    return switch (ty.toIntern()) {
        .usize_type,
        .isize_type,
        .c_char_type,
        .c_short_type,
        .c_ushort_type,
        .c_int_type,
        .c_uint_type,
        .c_long_type,
        .c_ulong_type,
        .c_longlong_type,
        .c_ulonglong_type,
        => true,

        else => false,
    };
}

/// Returns `false` for `comptime_float`.
pub fn isRuntimeFloat(ty: Type) bool {
    return switch (ty.toIntern()) {
        .f16_type,
        .f32_type,
        .f64_type,
        .f80_type,
        .f128_type,
        .c_longdouble_type,
        => true,

        else => false,
    };
}

/// Returns `true` for `comptime_float`.
pub fn isAnyFloat(ty: Type) bool {
    return switch (ty.toIntern()) {
        .f16_type,
        .f32_type,
        .f64_type,
        .f80_type,
        .f128_type,
        .c_longdouble_type,
        .comptime_float_type,
        => true,

        else => false,
    };
}

/// Asserts the type is a fixed-size float or comptime_float.
/// Returns 128 for comptime_float types.
pub fn floatBits(ty: Type, target: Target) u16 {
    return switch (ty.toIntern()) {
        .f16_type => 16,
        .f32_type => 32,
        .f64_type => 64,
        .f80_type => 80,
        .f128_type, .comptime_float_type => 128,
        .c_longdouble_type => target.c_type_bit_size(.longdouble),

        else => unreachable,
    };
}

/// Asserts the type is a function or a function pointer.
pub fn fnReturnType(ty: Type, mod: *Module) Type {
    return Type.fromInterned(mod.intern_pool.funcTypeReturnType(ty.toIntern()));
}

/// Asserts the type is a function.
pub fn fnCallingConvention(ty: Type, mod: *Module) std.builtin.CallingConvention {
    return mod.intern_pool.indexToKey(ty.toIntern()).func_type.cc;
}

pub fn isValidParamType(self: Type, mod: *const Module) bool {
    return switch (self.zigTypeTagOrPoison(mod) catch return true) {
        .Opaque, .NoReturn => false,
        else => true,
    };
}

pub fn isValidReturnType(self: Type, mod: *const Module) bool {
    return switch (self.zigTypeTagOrPoison(mod) catch return true) {
        .Opaque => false,
        else => true,
    };
}

/// Asserts the type is a function.
pub fn fnIsVarArgs(ty: Type, mod: *Module) bool {
    return mod.intern_pool.indexToKey(ty.toIntern()).func_type.is_var_args;
}

pub fn isNumeric(ty: Type, mod: *const Module) bool {
    return switch (ty.toIntern()) {
        .f16_type,
        .f32_type,
        .f64_type,
        .f80_type,
        .f128_type,
        .c_longdouble_type,
        .comptime_int_type,
        .comptime_float_type,
        .usize_type,
        .isize_type,
        .c_char_type,
        .c_short_type,
        .c_ushort_type,
        .c_int_type,
        .c_uint_type,
        .c_long_type,
        .c_ulong_type,
        .c_longlong_type,
        .c_ulonglong_type,
        => true,

        else => switch (mod.intern_pool.indexToKey(ty.toIntern())) {
            .int_type => true,
            else => false,
        },
    };
}

/// During semantic analysis, instead call `Sema.typeHasOnePossibleValue` which
/// resolves field types rather than asserting they are already resolved.
pub fn onePossibleValue(starting_type: Type, pt: Zcu.PerThread) !?Value {
    const mod = pt.zcu;
    var ty = starting_type;
    const ip = &mod.intern_pool;
    while (true) switch (ty.toIntern()) {
        .empty_struct_type => return Value.empty_struct,

        else => switch (ip.indexToKey(ty.toIntern())) {
            .int_type => |int_type| {
                if (int_type.bits == 0) {
                    return try pt.intValue(ty, 0);
                } else {
                    return null;
                }
            },

            .ptr_type,
            .error_union_type,
            .func_type,
            .anyframe_type,
            .error_set_type,
            .inferred_error_set_type,
            => return null,

            inline .array_type, .vector_type => |seq_type, seq_tag| {
                const has_sentinel = seq_tag == .array_type and seq_type.sentinel != .none;
                if (seq_type.len + @intFromBool(has_sentinel) == 0) return Value.fromInterned(try pt.intern(.{ .aggregate = .{
                    .ty = ty.toIntern(),
                    .storage = .{ .elems = &.{} },
                } }));
                if (try Type.fromInterned(seq_type.child).onePossibleValue(pt)) |opv| {
                    return Value.fromInterned(try pt.intern(.{ .aggregate = .{
                        .ty = ty.toIntern(),
                        .storage = .{ .repeated_elem = opv.toIntern() },
                    } }));
                }
                return null;
            },
            .opt_type => |child| {
                if (child == .noreturn_type) {
                    return try pt.nullValue(ty);
                } else {
                    return null;
                }
            },

            .simple_type => |t| switch (t) {
                .f16,
                .f32,
                .f64,
                .f80,
                .f128,
                .usize,
                .isize,
                .c_char,
                .c_short,
                .c_ushort,
                .c_int,
                .c_uint,
                .c_long,
                .c_ulong,
                .c_longlong,
                .c_ulonglong,
                .c_longdouble,
                .anyopaque,
                .bool,
                .type,
                .anyerror,
                .comptime_int,
                .comptime_float,
                .enum_literal,
                .atomic_order,
                .atomic_rmw_op,
                .calling_convention,
                .address_space,
                .float_mode,
                .reduce_op,
                .call_modifier,
                .prefetch_options,
                .export_options,
                .extern_options,
                .type_info,
                .adhoc_inferred_error_set,
                => return null,

                .void => return Value.void,
                .noreturn => return Value.@"unreachable",
                .null => return Value.null,
                .undefined => return Value.undef,

                .generic_poison => unreachable,
            },
            .struct_type => {
                const struct_type = ip.loadStructType(ty.toIntern());
                assert(struct_type.haveFieldTypes(ip));
                if (struct_type.knownNonOpv(ip))
                    return null;
                const field_vals = try mod.gpa.alloc(InternPool.Index, struct_type.field_types.len);
                defer mod.gpa.free(field_vals);
                for (field_vals, 0..) |*field_val, i_usize| {
                    const i: u32 = @intCast(i_usize);
                    if (struct_type.fieldIsComptime(ip, i)) {
                        assert(struct_type.haveFieldInits(ip));
                        field_val.* = struct_type.field_inits.get(ip)[i];
                        continue;
                    }
                    const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[i]);
                    if (try field_ty.onePossibleValue(pt)) |field_opv| {
                        field_val.* = field_opv.toIntern();
                    } else return null;
                }

                // In this case the struct has no runtime-known fields and
                // therefore has one possible value.
                return Value.fromInterned(try pt.intern(.{ .aggregate = .{
                    .ty = ty.toIntern(),
                    .storage = .{ .elems = field_vals },
                } }));
            },

            .anon_struct_type => |tuple| {
                for (tuple.values.get(ip)) |val| {
                    if (val == .none) return null;
                }
                // In this case the struct has all comptime-known fields and
                // therefore has one possible value.
                // TODO: write something like getCoercedInts to avoid needing to dupe
                const duped_values = try mod.gpa.dupe(InternPool.Index, tuple.values.get(ip));
                defer mod.gpa.free(duped_values);
                return Value.fromInterned(try pt.intern(.{ .aggregate = .{
                    .ty = ty.toIntern(),
                    .storage = .{ .elems = duped_values },
                } }));
            },

            .union_type => {
                const union_obj = ip.loadUnionType(ty.toIntern());
                const tag_val = (try Type.fromInterned(union_obj.enum_tag_ty).onePossibleValue(pt)) orelse
                    return null;
                if (union_obj.field_types.len == 0) {
                    const only = try pt.intern(.{ .empty_enum_value = ty.toIntern() });
                    return Value.fromInterned(only);
                }
                const only_field_ty = union_obj.field_types.get(ip)[0];
                const val_val = (try Type.fromInterned(only_field_ty).onePossibleValue(pt)) orelse
                    return null;
                const only = try pt.intern(.{ .un = .{
                    .ty = ty.toIntern(),
                    .tag = tag_val.toIntern(),
                    .val = val_val.toIntern(),
                } });
                return Value.fromInterned(only);
            },
            .opaque_type => return null,
            .enum_type => {
                const enum_type = ip.loadEnumType(ty.toIntern());
                switch (enum_type.tag_mode) {
                    .nonexhaustive => {
                        if (enum_type.tag_ty == .comptime_int_type) return null;

                        if (try Type.fromInterned(enum_type.tag_ty).onePossibleValue(pt)) |int_opv| {
                            const only = try pt.intern(.{ .enum_tag = .{
                                .ty = ty.toIntern(),
                                .int = int_opv.toIntern(),
                            } });
                            return Value.fromInterned(only);
                        }

                        return null;
                    },
                    .auto, .explicit => {
                        if (Type.fromInterned(enum_type.tag_ty).hasRuntimeBits(pt)) return null;

                        switch (enum_type.names.len) {
                            0 => {
                                const only = try pt.intern(.{ .empty_enum_value = ty.toIntern() });
                                return Value.fromInterned(only);
                            },
                            1 => {
                                if (enum_type.values.len == 0) {
                                    const only = try pt.intern(.{ .enum_tag = .{
                                        .ty = ty.toIntern(),
                                        .int = try pt.intern(.{ .int = .{
                                            .ty = enum_type.tag_ty,
                                            .storage = .{ .u64 = 0 },
                                        } }),
                                    } });
                                    return Value.fromInterned(only);
                                } else {
                                    return Value.fromInterned(enum_type.values.get(ip)[0]);
                                }
                            },
                            else => return null,
                        }
                    },
                }
            },

            // values, not types
            .undef,
            .simple_value,
            .variable,
            .extern_func,
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
            // memoization, not types
            .memoized_call,
            => unreachable,
        },
    };
}

/// During semantic analysis, instead call `Sema.typeRequiresComptime` which
/// resolves field types rather than asserting they are already resolved.
pub fn comptimeOnly(ty: Type, pt: Zcu.PerThread) bool {
    return ty.comptimeOnlyAdvanced(pt, .normal) catch unreachable;
}

/// `generic_poison` will return false.
/// May return false negatives when structs and unions are having their field types resolved.
pub fn comptimeOnlyAdvanced(ty: Type, pt: Zcu.PerThread, comptime strat: ResolveStrat) SemaError!bool {
    const mod = pt.zcu;
    const ip = &mod.intern_pool;
    return switch (ty.toIntern()) {
        .empty_struct_type => false,

        else => switch (ip.indexToKey(ty.toIntern())) {
            .int_type => false,
            .ptr_type => |ptr_type| {
                const child_ty = Type.fromInterned(ptr_type.child);
                switch (child_ty.zigTypeTag(mod)) {
                    .Fn => return !try child_ty.fnHasRuntimeBitsAdvanced(pt, strat),
                    .Opaque => return false,
                    else => return child_ty.comptimeOnlyAdvanced(pt, strat),
                }
            },
            .anyframe_type => |child| {
                if (child == .none) return false;
                return Type.fromInterned(child).comptimeOnlyAdvanced(pt, strat);
            },
            .array_type => |array_type| return Type.fromInterned(array_type.child).comptimeOnlyAdvanced(pt, strat),
            .vector_type => |vector_type| return Type.fromInterned(vector_type.child).comptimeOnlyAdvanced(pt, strat),
            .opt_type => |child| return Type.fromInterned(child).comptimeOnlyAdvanced(pt, strat),
            .error_union_type => |error_union_type| return Type.fromInterned(error_union_type.payload_type).comptimeOnlyAdvanced(pt, strat),

            .error_set_type,
            .inferred_error_set_type,
            => false,

            // These are function bodies, not function pointers.
            .func_type => true,

            .simple_type => |t| switch (t) {
                .f16,
                .f32,
                .f64,
                .f80,
                .f128,
                .usize,
                .isize,
                .c_char,
                .c_short,
                .c_ushort,
                .c_int,
                .c_uint,
                .c_long,
                .c_ulong,
                .c_longlong,
                .c_ulonglong,
                .c_longdouble,
                .anyopaque,
                .bool,
                .void,
                .anyerror,
                .adhoc_inferred_error_set,
                .noreturn,
                .generic_poison,
                .atomic_order,
                .atomic_rmw_op,
                .calling_convention,
                .address_space,
                .float_mode,
                .reduce_op,
                .call_modifier,
                .prefetch_options,
                .export_options,
                .extern_options,
                => false,

                .type,
                .comptime_int,
                .comptime_float,
                .null,
                .undefined,
                .enum_literal,
                .type_info,
                => true,
            },
            .struct_type => {
                const struct_type = ip.loadStructType(ty.toIntern());
                // packed structs cannot be comptime-only because they have a well-defined
                // memory layout and every field has a well-defined bit pattern.
                if (struct_type.layout == .@"packed")
                    return false;

                // A struct with no fields is not comptime-only.
                return switch (struct_type.setRequiresComptimeWip(ip)) {
                    .no, .wip => false,
                    .yes => true,
                    .unknown => {
                        // Inlined `assert` so that the resolution calls below are not statically reachable.
                        if (strat != .sema) unreachable;

                        if (struct_type.flagsUnordered(ip).field_types_wip) {
                            struct_type.setRequiresComptime(ip, .unknown);
                            return false;
                        }

                        errdefer struct_type.setRequiresComptime(ip, .unknown);

                        try ty.resolveFields(pt);

                        for (0..struct_type.field_types.len) |i_usize| {
                            const i: u32 = @intCast(i_usize);
                            if (struct_type.fieldIsComptime(ip, i)) continue;
                            const field_ty = struct_type.field_types.get(ip)[i];
                            if (try Type.fromInterned(field_ty).comptimeOnlyAdvanced(pt, strat)) {
                                // Note that this does not cause the layout to
                                // be considered resolved. Comptime-only types
                                // still maintain a layout of their
                                // runtime-known fields.
                                struct_type.setRequiresComptime(ip, .yes);
                                return true;
                            }
                        }

                        struct_type.setRequiresComptime(ip, .no);
                        return false;
                    },
                };
            },

            .anon_struct_type => |tuple| {
                for (tuple.types.get(ip), tuple.values.get(ip)) |field_ty, val| {
                    const have_comptime_val = val != .none;
                    if (!have_comptime_val and try Type.fromInterned(field_ty).comptimeOnlyAdvanced(pt, strat)) return true;
                }
                return false;
            },

            .union_type => {
                const union_type = ip.loadUnionType(ty.toIntern());
                switch (union_type.setRequiresComptimeWip(ip)) {
                    .no, .wip => return false,
                    .yes => return true,
                    .unknown => {
                        // Inlined `assert` so that the resolution calls below are not statically reachable.
                        if (strat != .sema) unreachable;

                        if (union_type.flagsUnordered(ip).status == .field_types_wip) {
                            union_type.setRequiresComptime(ip, .unknown);
                            return false;
                        }

                        errdefer union_type.setRequiresComptime(ip, .unknown);

                        try ty.resolveFields(pt);

                        for (0..union_type.field_types.len) |field_idx| {
                            const field_ty = union_type.field_types.get(ip)[field_idx];
                            if (try Type.fromInterned(field_ty).comptimeOnlyAdvanced(pt, strat)) {
                                union_type.setRequiresComptime(ip, .yes);
                                return true;
                            }
                        }

                        union_type.setRequiresComptime(ip, .no);
                        return false;
                    },
                }
            },

            .opaque_type => false,

            .enum_type => return Type.fromInterned(ip.loadEnumType(ty.toIntern()).tag_ty).comptimeOnlyAdvanced(pt, strat),

            // values, not types
            .undef,
            .simple_value,
            .variable,
            .extern_func,
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
            // memoization, not types
            .memoized_call,
            => unreachable,
        },
    };
}

pub fn isVector(ty: Type, mod: *const Module) bool {
    return ty.zigTypeTag(mod) == .Vector;
}

/// Returns 0 if not a vector, otherwise returns @bitSizeOf(Element) * vector_len.
pub fn totalVectorBits(ty: Type, pt: Zcu.PerThread) u64 {
    if (!ty.isVector(pt.zcu)) return 0;
    const v = pt.zcu.intern_pool.indexToKey(ty.toIntern()).vector_type;
    return v.len * Type.fromInterned(v.child).bitSize(pt);
}

pub fn isArrayOrVector(ty: Type, mod: *const Module) bool {
    return switch (ty.zigTypeTag(mod)) {
        .Array, .Vector => true,
        else => false,
    };
}

pub fn isIndexable(ty: Type, mod: *Module) bool {
    return switch (ty.zigTypeTag(mod)) {
        .Array, .Vector => true,
        .Pointer => switch (ty.ptrSize(mod)) {
            .Slice, .Many, .C => true,
            .One => switch (ty.childType(mod).zigTypeTag(mod)) {
                .Array, .Vector => true,
                .Struct => ty.childType(mod).isTuple(mod),
                else => false,
            },
        },
        .Struct => ty.isTuple(mod),
        else => false,
    };
}

pub fn indexableHasLen(ty: Type, mod: *Module) bool {
    return switch (ty.zigTypeTag(mod)) {
        .Array, .Vector => true,
        .Pointer => switch (ty.ptrSize(mod)) {
            .Many, .C => false,
            .Slice => true,
            .One => switch (ty.childType(mod).zigTypeTag(mod)) {
                .Array, .Vector => true,
                .Struct => ty.childType(mod).isTuple(mod),
                else => false,
            },
        },
        .Struct => ty.isTuple(mod),
        else => false,
    };
}

/// Asserts that the type can have a namespace.
pub fn getNamespaceIndex(ty: Type, zcu: *Zcu) InternPool.OptionalNamespaceIndex {
    return ty.getNamespace(zcu).?;
}

/// Returns null if the type has no namespace.
pub fn getNamespace(ty: Type, zcu: *Zcu) ?InternPool.OptionalNamespaceIndex {
    const ip = &zcu.intern_pool;
    return switch (ip.indexToKey(ty.toIntern())) {
        .opaque_type => ip.loadOpaqueType(ty.toIntern()).namespace,
        .struct_type => ip.loadStructType(ty.toIntern()).namespace,
        .union_type => ip.loadUnionType(ty.toIntern()).namespace,
        .enum_type => ip.loadEnumType(ty.toIntern()).namespace,

        .anon_struct_type => .none,
        .simple_type => |s| switch (s) {
            .anyopaque,
            .atomic_order,
            .atomic_rmw_op,
            .calling_convention,
            .address_space,
            .float_mode,
            .reduce_op,
            .call_modifier,
            .prefetch_options,
            .export_options,
            .extern_options,
            .type_info,
            => .none,
            else => null,
        },

        else => null,
    };
}

// Works for vectors and vectors of integers.
pub fn minInt(ty: Type, pt: Zcu.PerThread, dest_ty: Type) !Value {
    const mod = pt.zcu;
    const scalar = try minIntScalar(ty.scalarType(mod), pt, dest_ty.scalarType(mod));
    return if (ty.zigTypeTag(mod) == .Vector) Value.fromInterned(try pt.intern(.{ .aggregate = .{
        .ty = dest_ty.toIntern(),
        .storage = .{ .repeated_elem = scalar.toIntern() },
    } })) else scalar;
}

/// Asserts that the type is an integer.
pub fn minIntScalar(ty: Type, pt: Zcu.PerThread, dest_ty: Type) !Value {
    const mod = pt.zcu;
    const info = ty.intInfo(mod);
    if (info.signedness == .unsigned) return pt.intValue(dest_ty, 0);
    if (info.bits == 0) return pt.intValue(dest_ty, -1);

    if (std.math.cast(u6, info.bits - 1)) |shift| {
        const n = @as(i64, std.math.minInt(i64)) >> (63 - shift);
        return pt.intValue(dest_ty, n);
    }

    var res = try std.math.big.int.Managed.init(mod.gpa);
    defer res.deinit();

    try res.setTwosCompIntLimit(.min, info.signedness, info.bits);

    return pt.intValue_big(dest_ty, res.toConst());
}

// Works for vectors and vectors of integers.
/// The returned Value will have type dest_ty.
pub fn maxInt(ty: Type, pt: Zcu.PerThread, dest_ty: Type) !Value {
    const mod = pt.zcu;
    const scalar = try maxIntScalar(ty.scalarType(mod), pt, dest_ty.scalarType(mod));
    return if (ty.zigTypeTag(mod) == .Vector) Value.fromInterned(try pt.intern(.{ .aggregate = .{
        .ty = dest_ty.toIntern(),
        .storage = .{ .repeated_elem = scalar.toIntern() },
    } })) else scalar;
}

/// The returned Value will have type dest_ty.
pub fn maxIntScalar(ty: Type, pt: Zcu.PerThread, dest_ty: Type) !Value {
    const info = ty.intInfo(pt.zcu);

    switch (info.bits) {
        0 => return switch (info.signedness) {
            .signed => try pt.intValue(dest_ty, -1),
            .unsigned => try pt.intValue(dest_ty, 0),
        },
        1 => return switch (info.signedness) {
            .signed => try pt.intValue(dest_ty, 0),
            .unsigned => try pt.intValue(dest_ty, 1),
        },
        else => {},
    }

    if (std.math.cast(u6, info.bits - 1)) |shift| switch (info.signedness) {
        .signed => {
            const n = @as(i64, std.math.maxInt(i64)) >> (63 - shift);
            return pt.intValue(dest_ty, n);
        },
        .unsigned => {
            const n = @as(u64, std.math.maxInt(u64)) >> (63 - shift);
            return pt.intValue(dest_ty, n);
        },
    };

    var res = try std.math.big.int.Managed.init(pt.zcu.gpa);
    defer res.deinit();

    try res.setTwosCompIntLimit(.max, info.signedness, info.bits);

    return pt.intValue_big(dest_ty, res.toConst());
}

/// Asserts the type is an enum or a union.
pub fn intTagType(ty: Type, mod: *Module) Type {
    const ip = &mod.intern_pool;
    return switch (ip.indexToKey(ty.toIntern())) {
        .union_type => Type.fromInterned(ip.loadUnionType(ty.toIntern()).enum_tag_ty).intTagType(mod),
        .enum_type => Type.fromInterned(ip.loadEnumType(ty.toIntern()).tag_ty),
        else => unreachable,
    };
}

pub fn isNonexhaustiveEnum(ty: Type, mod: *Module) bool {
    const ip = &mod.intern_pool;
    return switch (ip.indexToKey(ty.toIntern())) {
        .enum_type => switch (ip.loadEnumType(ty.toIntern()).tag_mode) {
            .nonexhaustive => true,
            .auto, .explicit => false,
        },
        else => false,
    };
}

// Asserts that `ty` is an error set and not `anyerror`.
// Asserts that `ty` is resolved if it is an inferred error set.
pub fn errorSetNames(ty: Type, mod: *Module) InternPool.NullTerminatedString.Slice {
    const ip = &mod.intern_pool;
    return switch (ip.indexToKey(ty.toIntern())) {
        .error_set_type => |x| x.names,
        .inferred_error_set_type => |i| switch (ip.funcIesResolvedUnordered(i)) {
            .none => unreachable, // unresolved inferred error set
            .anyerror_type => unreachable,
            else => |t| ip.indexToKey(t).error_set_type.names,
        },
        else => unreachable,
    };
}

pub fn enumFields(ty: Type, mod: *Module) InternPool.NullTerminatedString.Slice {
    return mod.intern_pool.loadEnumType(ty.toIntern()).names;
}

pub fn enumFieldCount(ty: Type, mod: *Module) usize {
    return mod.intern_pool.loadEnumType(ty.toIntern()).names.len;
}

pub fn enumFieldName(ty: Type, field_index: usize, mod: *Module) InternPool.NullTerminatedString {
    const ip = &mod.intern_pool;
    return ip.loadEnumType(ty.toIntern()).names.get(ip)[field_index];
}

pub fn enumFieldIndex(ty: Type, field_name: InternPool.NullTerminatedString, mod: *Module) ?u32 {
    const ip = &mod.intern_pool;
    const enum_type = ip.loadEnumType(ty.toIntern());
    return enum_type.nameIndex(ip, field_name);
}

/// Asserts `ty` is an enum. `enum_tag` can either be `enum_field_index` or
/// an integer which represents the enum value. Returns the field index in
/// declaration order, or `null` if `enum_tag` does not match any field.
pub fn enumTagFieldIndex(ty: Type, enum_tag: Value, mod: *Module) ?u32 {
    const ip = &mod.intern_pool;
    const enum_type = ip.loadEnumType(ty.toIntern());
    const int_tag = switch (ip.indexToKey(enum_tag.toIntern())) {
        .int => enum_tag.toIntern(),
        .enum_tag => |info| info.int,
        else => unreachable,
    };
    assert(ip.typeOf(int_tag) == enum_type.tag_ty);
    return enum_type.tagValueIndex(ip, int_tag);
}

/// Returns none in the case of a tuple which uses the integer index as the field name.
pub fn structFieldName(ty: Type, index: usize, mod: *Module) InternPool.OptionalNullTerminatedString {
    const ip = &mod.intern_pool;
    return switch (ip.indexToKey(ty.toIntern())) {
        .struct_type => ip.loadStructType(ty.toIntern()).fieldName(ip, index),
        .anon_struct_type => |anon_struct| anon_struct.fieldName(ip, index),
        else => unreachable,
    };
}

pub fn structFieldCount(ty: Type, mod: *Module) u32 {
    const ip = &mod.intern_pool;
    return switch (ip.indexToKey(ty.toIntern())) {
        .struct_type => ip.loadStructType(ty.toIntern()).field_types.len,
        .anon_struct_type => |anon_struct| anon_struct.types.len,
        else => unreachable,
    };
}

/// Supports structs and unions.
pub fn structFieldType(ty: Type, index: usize, mod: *Module) Type {
    const ip = &mod.intern_pool;
    return switch (ip.indexToKey(ty.toIntern())) {
        .struct_type => Type.fromInterned(ip.loadStructType(ty.toIntern()).field_types.get(ip)[index]),
        .union_type => {
            const union_obj = ip.loadUnionType(ty.toIntern());
            return Type.fromInterned(union_obj.field_types.get(ip)[index]);
        },
        .anon_struct_type => |anon_struct| Type.fromInterned(anon_struct.types.get(ip)[index]),
        else => unreachable,
    };
}

pub fn structFieldAlign(ty: Type, index: usize, pt: Zcu.PerThread) Alignment {
    return ty.structFieldAlignAdvanced(index, pt, .normal) catch unreachable;
}

pub fn structFieldAlignAdvanced(ty: Type, index: usize, pt: Zcu.PerThread, comptime strat: ResolveStrat) !Alignment {
    const ip = &pt.zcu.intern_pool;
    switch (ip.indexToKey(ty.toIntern())) {
        .struct_type => {
            const struct_type = ip.loadStructType(ty.toIntern());
            assert(struct_type.layout != .@"packed");
            const explicit_align = struct_type.fieldAlign(ip, index);
            const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[index]);
            return pt.structFieldAlignmentAdvanced(explicit_align, field_ty, struct_type.layout, strat);
        },
        .anon_struct_type => |anon_struct| {
            return (try Type.fromInterned(anon_struct.types.get(ip)[index]).abiAlignmentAdvanced(pt, strat.toLazy())).scalar;
        },
        .union_type => {
            const union_obj = ip.loadUnionType(ty.toIntern());
            return pt.unionFieldNormalAlignmentAdvanced(union_obj, @intCast(index), strat);
        },
        else => unreachable,
    }
}

pub fn structFieldDefaultValue(ty: Type, index: usize, mod: *Module) Value {
    const ip = &mod.intern_pool;
    switch (ip.indexToKey(ty.toIntern())) {
        .struct_type => {
            const struct_type = ip.loadStructType(ty.toIntern());
            const val = struct_type.fieldInit(ip, index);
            // TODO: avoid using `unreachable` to indicate this.
            if (val == .none) return Value.@"unreachable";
            return Value.fromInterned(val);
        },
        .anon_struct_type => |anon_struct| {
            const val = anon_struct.values.get(ip)[index];
            // TODO: avoid using `unreachable` to indicate this.
            if (val == .none) return Value.@"unreachable";
            return Value.fromInterned(val);
        },
        else => unreachable,
    }
}

pub fn structFieldValueComptime(ty: Type, pt: Zcu.PerThread, index: usize) !?Value {
    const mod = pt.zcu;
    const ip = &mod.intern_pool;
    switch (ip.indexToKey(ty.toIntern())) {
        .struct_type => {
            const struct_type = ip.loadStructType(ty.toIntern());
            if (struct_type.fieldIsComptime(ip, index)) {
                assert(struct_type.haveFieldInits(ip));
                return Value.fromInterned(struct_type.field_inits.get(ip)[index]);
            } else {
                return Type.fromInterned(struct_type.field_types.get(ip)[index]).onePossibleValue(pt);
            }
        },
        .anon_struct_type => |tuple| {
            const val = tuple.values.get(ip)[index];
            if (val == .none) {
                return Type.fromInterned(tuple.types.get(ip)[index]).onePossibleValue(pt);
            } else {
                return Value.fromInterned(val);
            }
        },
        else => unreachable,
    }
}

pub fn structFieldIsComptime(ty: Type, index: usize, mod: *Module) bool {
    const ip = &mod.intern_pool;
    return switch (ip.indexToKey(ty.toIntern())) {
        .struct_type => ip.loadStructType(ty.toIntern()).fieldIsComptime(ip, index),
        .anon_struct_type => |anon_struct| anon_struct.values.get(ip)[index] != .none,
        else => unreachable,
    };
}

pub const FieldOffset = struct {
    field: usize,
    offset: u64,
};

/// Supports structs and unions.
pub fn structFieldOffset(ty: Type, index: usize, pt: Zcu.PerThread) u64 {
    const mod = pt.zcu;
    const ip = &mod.intern_pool;
    switch (ip.indexToKey(ty.toIntern())) {
        .struct_type => {
            const struct_type = ip.loadStructType(ty.toIntern());
            assert(struct_type.haveLayout(ip));
            assert(struct_type.layout != .@"packed");
            return struct_type.offsets.get(ip)[index];
        },

        .anon_struct_type => |tuple| {
            var offset: u64 = 0;
            var big_align: Alignment = .none;

            for (tuple.types.get(ip), tuple.values.get(ip), 0..) |field_ty, field_val, i| {
                if (field_val != .none or !Type.fromInterned(field_ty).hasRuntimeBits(pt)) {
                    // comptime field
                    if (i == index) return offset;
                    continue;
                }

                const field_align = Type.fromInterned(field_ty).abiAlignment(pt);
                big_align = big_align.max(field_align);
                offset = field_align.forward(offset);
                if (i == index) return offset;
                offset += Type.fromInterned(field_ty).abiSize(pt);
            }
            offset = big_align.max(.@"1").forward(offset);
            return offset;
        },

        .union_type => {
            const union_type = ip.loadUnionType(ty.toIntern());
            if (!union_type.hasTag(ip))
                return 0;
            const layout = pt.getUnionLayout(union_type);
            if (layout.tag_align.compare(.gte, layout.payload_align)) {
                // {Tag, Payload}
                return layout.payload_align.forward(layout.tag_size);
            } else {
                // {Payload, Tag}
                return 0;
            }
        },

        else => unreachable,
    }
}

pub fn getOwnerDecl(ty: Type, mod: *Module) InternPool.DeclIndex {
    return ty.getOwnerDeclOrNull(mod) orelse unreachable;
}

pub fn getOwnerDeclOrNull(ty: Type, mod: *Module) ?InternPool.DeclIndex {
    const ip = &mod.intern_pool;
    return switch (ip.indexToKey(ty.toIntern())) {
        .struct_type => ip.loadStructType(ty.toIntern()).decl.unwrap(),
        .union_type => ip.loadUnionType(ty.toIntern()).decl,
        .opaque_type => ip.loadOpaqueType(ty.toIntern()).decl,
        .enum_type => ip.loadEnumType(ty.toIntern()).decl,
        else => null,
    };
}

pub fn srcLocOrNull(ty: Type, zcu: *Zcu) ?Module.LazySrcLoc {
    const ip = &zcu.intern_pool;
    return .{
        .base_node_inst = switch (ip.indexToKey(ty.toIntern())) {
            .struct_type, .union_type, .opaque_type, .enum_type => |info| switch (info) {
                .declared => |d| d.zir_index,
                .reified => |r| r.zir_index,
                .generated_tag => |gt| ip.loadUnionType(gt.union_type).zir_index,
                .empty_struct => return null,
            },
            else => return null,
        },
        .offset = Module.LazySrcLoc.Offset.nodeOffset(0),
    };
}

pub fn srcLoc(ty: Type, zcu: *Zcu) Module.LazySrcLoc {
    return ty.srcLocOrNull(zcu).?;
}

pub fn isGenericPoison(ty: Type) bool {
    return ty.toIntern() == .generic_poison_type;
}

pub fn isTuple(ty: Type, mod: *Module) bool {
    const ip = &mod.intern_pool;
    return switch (ip.indexToKey(ty.toIntern())) {
        .struct_type => {
            const struct_type = ip.loadStructType(ty.toIntern());
            if (struct_type.layout == .@"packed") return false;
            if (struct_type.decl == .none) return false;
            return struct_type.flagsUnordered(ip).is_tuple;
        },
        .anon_struct_type => |anon_struct| anon_struct.names.len == 0,
        else => false,
    };
}

pub fn isAnonStruct(ty: Type, mod: *Module) bool {
    if (ty.toIntern() == .empty_struct_type) return true;
    return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
        .anon_struct_type => |anon_struct_type| anon_struct_type.names.len > 0,
        else => false,
    };
}

pub fn isTupleOrAnonStruct(ty: Type, mod: *Module) bool {
    const ip = &mod.intern_pool;
    return switch (ip.indexToKey(ty.toIntern())) {
        .struct_type => {
            const struct_type = ip.loadStructType(ty.toIntern());
            if (struct_type.layout == .@"packed") return false;
            if (struct_type.decl == .none) return false;
            return struct_type.flagsUnordered(ip).is_tuple;
        },
        .anon_struct_type => true,
        else => false,
    };
}

pub fn isSimpleTuple(ty: Type, mod: *Module) bool {
    return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
        .anon_struct_type => |anon_struct_type| anon_struct_type.names.len == 0,
        else => false,
    };
}

pub fn isSimpleTupleOrAnonStruct(ty: Type, mod: *Module) bool {
    return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
        .anon_struct_type => true,
        else => false,
    };
}

/// Traverses optional child types and error union payloads until the type
/// is not a pointer. For `E!?u32`, returns `u32`; for `*u8`, returns `*u8`.
pub fn optEuBaseType(ty: Type, mod: *Module) Type {
    var cur = ty;
    while (true) switch (cur.zigTypeTag(mod)) {
        .Optional => cur = cur.optionalChild(mod),
        .ErrorUnion => cur = cur.errorUnionPayload(mod),
        else => return cur,
    };
}

pub fn toUnsigned(ty: Type, pt: Zcu.PerThread) !Type {
    const mod = pt.zcu;
    return switch (ty.zigTypeTag(mod)) {
        .Int => pt.intType(.unsigned, ty.intInfo(mod).bits),
        .Vector => try pt.vectorType(.{
            .len = ty.vectorLen(mod),
            .child = (try ty.childType(mod).toUnsigned(pt)).toIntern(),
        }),
        else => unreachable,
    };
}

pub fn typeDeclInst(ty: Type, zcu: *const Zcu) ?InternPool.TrackedInst.Index {
    const ip = &zcu.intern_pool;
    return switch (ip.indexToKey(ty.toIntern())) {
        .struct_type => ip.loadStructType(ty.toIntern()).zir_index.unwrap(),
        .union_type => ip.loadUnionType(ty.toIntern()).zir_index,
        .enum_type => ip.loadEnumType(ty.toIntern()).zir_index.unwrap(),
        .opaque_type => ip.loadOpaqueType(ty.toIntern()).zir_index,
        else => null,
    };
}

pub fn typeDeclSrcLine(ty: Type, zcu: *Zcu) ?u32 {
    const ip = &zcu.intern_pool;
    const tracked = switch (ip.indexToKey(ty.toIntern())) {
        .struct_type, .union_type, .opaque_type, .enum_type => |info| switch (info) {
            .declared => |d| d.zir_index,
            .reified => |r| r.zir_index,
            .generated_tag => |gt| ip.loadUnionType(gt.union_type).zir_index,
            .empty_struct => return null,
        },
        else => return null,
    };
    const info = tracked.resolveFull(&zcu.intern_pool);
    const file = zcu.fileByIndex(info.file);
    assert(file.zir_loaded);
    const zir = file.zir;
    const inst = zir.instructions.get(@intFromEnum(info.inst));
    assert(inst.tag == .extended);
    return switch (inst.data.extended.opcode) {
        .struct_decl => zir.extraData(Zir.Inst.StructDecl, inst.data.extended.operand).data.src_line,
        .union_decl => zir.extraData(Zir.Inst.UnionDecl, inst.data.extended.operand).data.src_line,
        .enum_decl => zir.extraData(Zir.Inst.EnumDecl, inst.data.extended.operand).data.src_line,
        .opaque_decl => zir.extraData(Zir.Inst.OpaqueDecl, inst.data.extended.operand).data.src_line,
        .reify => zir.extraData(Zir.Inst.Reify, inst.data.extended.operand).data.src_line,
        else => unreachable,
    };
}

/// Given a namespace type, returns its list of caotured values.
pub fn getCaptures(ty: Type, zcu: *const Zcu) InternPool.CaptureValue.Slice {
    const ip = &zcu.intern_pool;
    return switch (ip.indexToKey(ty.toIntern())) {
        .struct_type => ip.loadStructType(ty.toIntern()).captures,
        .union_type => ip.loadUnionType(ty.toIntern()).captures,
        .enum_type => ip.loadEnumType(ty.toIntern()).captures,
        .opaque_type => ip.loadOpaqueType(ty.toIntern()).captures,
        else => unreachable,
    };
}

pub fn arrayBase(ty: Type, zcu: *const Zcu) struct { Type, u64 } {
    var cur_ty: Type = ty;
    var cur_len: u64 = 1;
    while (cur_ty.zigTypeTag(zcu) == .Array) {
        cur_len *= cur_ty.arrayLenIncludingSentinel(zcu);
        cur_ty = cur_ty.childType(zcu);
    }
    return .{ cur_ty, cur_len };
}

pub fn packedStructFieldPtrInfo(struct_ty: Type, parent_ptr_ty: Type, field_idx: u32, pt: Zcu.PerThread) union(enum) {
    /// The result is a bit-pointer with the same value and a new packed offset.
    bit_ptr: InternPool.Key.PtrType.PackedOffset,
    /// The result is a standard pointer.
    byte_ptr: struct {
        /// The byte offset of the field pointer from the parent pointer value.
        offset: u64,
        /// The alignment of the field pointer type.
        alignment: InternPool.Alignment,
    },
} {
    comptime assert(Type.packed_struct_layout_version == 2);

    const zcu = pt.zcu;
    const parent_ptr_info = parent_ptr_ty.ptrInfo(zcu);
    const field_ty = struct_ty.structFieldType(field_idx, zcu);

    var bit_offset: u16 = 0;
    var running_bits: u16 = 0;
    for (0..struct_ty.structFieldCount(zcu)) |i| {
        const f_ty = struct_ty.structFieldType(i, zcu);
        if (i == field_idx) {
            bit_offset = running_bits;
        }
        running_bits += @intCast(f_ty.bitSize(pt));
    }

    const res_host_size: u16, const res_bit_offset: u16 = if (parent_ptr_info.packed_offset.host_size != 0)
        .{ parent_ptr_info.packed_offset.host_size, parent_ptr_info.packed_offset.bit_offset + bit_offset }
    else
        .{ (running_bits + 7) / 8, bit_offset };

    // If the field happens to be byte-aligned, simplify the pointer type.
    // We can only do this if the pointee's bit size matches its ABI byte size,
    // so that loads and stores do not interfere with surrounding packed bits.
    //
    // TODO: we do not attempt this with big-endian targets yet because of nested
    // structs and floats. I need to double-check the desired behavior for big endian
    // targets before adding the necessary complications to this code. This will not
    // cause miscompilations; it only means the field pointer uses bit masking when it
    // might not be strictly necessary.
    if (res_bit_offset % 8 == 0 and field_ty.bitSize(pt) == field_ty.abiSize(pt) * 8 and zcu.getTarget().cpu.arch.endian() == .little) {
        const byte_offset = res_bit_offset / 8;
        const new_align = Alignment.fromLog2Units(@ctz(byte_offset | parent_ptr_ty.ptrAlignment(pt).toByteUnits().?));
        return .{ .byte_ptr = .{
            .offset = byte_offset,
            .alignment = new_align,
        } };
    }

    return .{ .bit_ptr = .{
        .host_size = res_host_size,
        .bit_offset = res_bit_offset,
    } };
}

pub fn resolveLayout(ty: Type, pt: Zcu.PerThread) SemaError!void {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    switch (ip.indexToKey(ty.toIntern())) {
        .simple_type => |simple_type| return resolveSimpleType(simple_type, pt),
        else => {},
    }
    switch (ty.zigTypeTag(zcu)) {
        .Struct => switch (ip.indexToKey(ty.toIntern())) {
            .anon_struct_type => |anon_struct_type| for (0..anon_struct_type.types.len) |i| {
                const field_ty = Type.fromInterned(anon_struct_type.types.get(ip)[i]);
                try field_ty.resolveLayout(pt);
            },
            .struct_type => return ty.resolveStructInner(pt, .layout),
            else => unreachable,
        },
        .Union => return ty.resolveUnionInner(pt, .layout),
        .Array => {
            if (ty.arrayLenIncludingSentinel(zcu) == 0) return;
            const elem_ty = ty.childType(zcu);
            return elem_ty.resolveLayout(pt);
        },
        .Optional => {
            const payload_ty = ty.optionalChild(zcu);
            return payload_ty.resolveLayout(pt);
        },
        .ErrorUnion => {
            const payload_ty = ty.errorUnionPayload(zcu);
            return payload_ty.resolveLayout(pt);
        },
        .Fn => {
            const info = zcu.typeToFunc(ty).?;
            if (info.is_generic) {
                // Resolving of generic function types is deferred to when
                // the function is instantiated.
                return;
            }
            for (0..info.param_types.len) |i| {
                const param_ty = info.param_types.get(ip)[i];
                try Type.fromInterned(param_ty).resolveLayout(pt);
            }
            try Type.fromInterned(info.return_type).resolveLayout(pt);
        },
        else => {},
    }
}

pub fn resolveFields(ty: Type, pt: Zcu.PerThread) SemaError!void {
    const ip = &pt.zcu.intern_pool;
    const ty_ip = ty.toIntern();

    switch (ty_ip) {
        .none => unreachable,

        .u0_type,
        .i0_type,
        .u1_type,
        .u8_type,
        .i8_type,
        .u16_type,
        .i16_type,
        .u29_type,
        .u32_type,
        .i32_type,
        .u64_type,
        .i64_type,
        .u80_type,
        .u128_type,
        .i128_type,
        .usize_type,
        .isize_type,
        .c_char_type,
        .c_short_type,
        .c_ushort_type,
        .c_int_type,
        .c_uint_type,
        .c_long_type,
        .c_ulong_type,
        .c_longlong_type,
        .c_ulonglong_type,
        .c_longdouble_type,
        .f16_type,
        .f32_type,
        .f64_type,
        .f80_type,
        .f128_type,
        .anyopaque_type,
        .bool_type,
        .void_type,
        .type_type,
        .anyerror_type,
        .adhoc_inferred_error_set_type,
        .comptime_int_type,
        .comptime_float_type,
        .noreturn_type,
        .anyframe_type,
        .null_type,
        .undefined_type,
        .enum_literal_type,
        .manyptr_u8_type,
        .manyptr_const_u8_type,
        .manyptr_const_u8_sentinel_0_type,
        .single_const_pointer_to_comptime_int_type,
        .slice_const_u8_type,
        .slice_const_u8_sentinel_0_type,
        .optional_noreturn_type,
        .anyerror_void_error_union_type,
        .generic_poison_type,
        .empty_struct_type,
        => {},

        .undef => unreachable,
        .zero => unreachable,
        .zero_usize => unreachable,
        .zero_u8 => unreachable,
        .one => unreachable,
        .one_usize => unreachable,
        .one_u8 => unreachable,
        .four_u8 => unreachable,
        .negative_one => unreachable,
        .calling_convention_c => unreachable,
        .calling_convention_inline => unreachable,
        .void_value => unreachable,
        .unreachable_value => unreachable,
        .null_value => unreachable,
        .bool_true => unreachable,
        .bool_false => unreachable,
        .empty_struct => unreachable,
        .generic_poison => unreachable,

        else => switch (ty_ip.unwrap(ip).getTag(ip)) {
            .type_struct,
            .type_struct_packed,
            .type_struct_packed_inits,
            => return ty.resolveStructInner(pt, .fields),

            .type_union => return ty.resolveUnionInner(pt, .fields),

            .simple_type => return resolveSimpleType(ip.indexToKey(ty_ip).simple_type, pt),

            else => {},
        },
    }
}

pub fn resolveFully(ty: Type, pt: Zcu.PerThread) SemaError!void {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;

    switch (ip.indexToKey(ty.toIntern())) {
        .simple_type => |simple_type| return resolveSimpleType(simple_type, pt),
        else => {},
    }

    switch (ty.zigTypeTag(zcu)) {
        .Type,
        .Void,
        .Bool,
        .NoReturn,
        .Int,
        .Float,
        .ComptimeFloat,
        .ComptimeInt,
        .Undefined,
        .Null,
        .ErrorSet,
        .Enum,
        .Opaque,
        .Frame,
        .AnyFrame,
        .Vector,
        .EnumLiteral,
        => {},

        .Pointer => return ty.childType(zcu).resolveFully(pt),
        .Array => return ty.childType(zcu).resolveFully(pt),
        .Optional => return ty.optionalChild(zcu).resolveFully(pt),
        .ErrorUnion => return ty.errorUnionPayload(zcu).resolveFully(pt),
        .Fn => {
            const info = zcu.typeToFunc(ty).?;
            if (info.is_generic) return;
            for (0..info.param_types.len) |i| {
                const param_ty = info.param_types.get(ip)[i];
                try Type.fromInterned(param_ty).resolveFully(pt);
            }
            try Type.fromInterned(info.return_type).resolveFully(pt);
        },

        .Struct => switch (ip.indexToKey(ty.toIntern())) {
            .anon_struct_type => |anon_struct_type| for (0..anon_struct_type.types.len) |i| {
                const field_ty = Type.fromInterned(anon_struct_type.types.get(ip)[i]);
                try field_ty.resolveFully(pt);
            },
            .struct_type => return ty.resolveStructInner(pt, .full),
            else => unreachable,
        },
        .Union => return ty.resolveUnionInner(pt, .full),
    }
}

pub fn resolveStructFieldInits(ty: Type, pt: Zcu.PerThread) SemaError!void {
    // TODO: stop calling this for tuples!
    _ = pt.zcu.typeToStruct(ty) orelse return;
    return ty.resolveStructInner(pt, .inits);
}

pub fn resolveStructAlignment(ty: Type, pt: Zcu.PerThread) SemaError!void {
    return ty.resolveStructInner(pt, .alignment);
}

pub fn resolveUnionAlignment(ty: Type, pt: Zcu.PerThread) SemaError!void {
    return ty.resolveUnionInner(pt, .alignment);
}

/// `ty` must be a struct.
fn resolveStructInner(
    ty: Type,
    pt: Zcu.PerThread,
    resolution: enum { fields, inits, alignment, layout, full },
) SemaError!void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    const struct_obj = zcu.typeToStruct(ty).?;
    const owner_decl_index = struct_obj.decl.unwrap() orelse return;

    var analysis_arena = std.heap.ArenaAllocator.init(gpa);
    defer analysis_arena.deinit();

    var comptime_err_ret_trace = std.ArrayList(Zcu.LazySrcLoc).init(gpa);
    defer comptime_err_ret_trace.deinit();

    var sema: Sema = .{
        .pt = pt,
        .gpa = gpa,
        .arena = analysis_arena.allocator(),
        .code = undefined, // This ZIR will not be used.
        .owner_decl = zcu.declPtr(owner_decl_index),
        .owner_decl_index = owner_decl_index,
        .func_index = .none,
        .func_is_naked = false,
        .fn_ret_ty = Type.void,
        .fn_ret_ty_ies = null,
        .owner_func_index = .none,
        .comptime_err_ret_trace = &comptime_err_ret_trace,
    };
    defer sema.deinit();

    switch (resolution) {
        .fields => return sema.resolveTypeFieldsStruct(ty.toIntern(), struct_obj),
        .inits => return sema.resolveStructFieldInits(ty),
        .alignment => return sema.resolveStructAlignment(ty.toIntern(), struct_obj),
        .layout => return sema.resolveStructLayout(ty),
        .full => return sema.resolveStructFully(ty),
    }
}

/// `ty` must be a union.
fn resolveUnionInner(
    ty: Type,
    pt: Zcu.PerThread,
    resolution: enum { fields, alignment, layout, full },
) SemaError!void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    const union_obj = zcu.typeToUnion(ty).?;
    const owner_decl_index = union_obj.decl;

    var analysis_arena = std.heap.ArenaAllocator.init(gpa);
    defer analysis_arena.deinit();

    var comptime_err_ret_trace = std.ArrayList(Zcu.LazySrcLoc).init(gpa);
    defer comptime_err_ret_trace.deinit();

    var sema: Sema = .{
        .pt = pt,
        .gpa = gpa,
        .arena = analysis_arena.allocator(),
        .code = undefined, // This ZIR will not be used.
        .owner_decl = zcu.declPtr(owner_decl_index),
        .owner_decl_index = owner_decl_index,
        .func_index = .none,
        .func_is_naked = false,
        .fn_ret_ty = Type.void,
        .fn_ret_ty_ies = null,
        .owner_func_index = .none,
        .comptime_err_ret_trace = &comptime_err_ret_trace,
    };
    defer sema.deinit();

    switch (resolution) {
        .fields => return sema.resolveTypeFieldsUnion(ty, union_obj),
        .alignment => return sema.resolveUnionAlignment(ty, union_obj),
        .layout => return sema.resolveUnionLayout(ty),
        .full => return sema.resolveUnionFully(ty),
    }
}

/// Fully resolves a simple type. This is usually a nop, but for builtin types with
/// special InternPool indices (such as std.builtin.Type) it will analyze and fully
/// resolve the type.
fn resolveSimpleType(simple_type: InternPool.SimpleType, pt: Zcu.PerThread) Allocator.Error!void {
    const builtin_type_name: []const u8 = switch (simple_type) {
        .atomic_order => "AtomicOrder",
        .atomic_rmw_op => "AtomicRmwOp",
        .calling_convention => "CallingConvention",
        .address_space => "AddressSpace",
        .float_mode => "FloatMode",
        .reduce_op => "ReduceOp",
        .call_modifier => "CallModifer",
        .prefetch_options => "PrefetchOptions",
        .export_options => "ExportOptions",
        .extern_options => "ExternOptions",
        .type_info => "Type",
        else => return,
    };
    // This will fully resolve the type.
    _ = try pt.getBuiltinType(builtin_type_name);
}

/// Returns the type of a pointer to an element.
/// Asserts that the type is a pointer, and that the element type is indexable.
/// If the element index is comptime-known, it must be passed in `offset`.
/// For *@Vector(n, T), return *align(a:b:h:v) T
/// For *[N]T, return *T
/// For [*]T, returns *T
/// For []T, returns *T
/// Handles const-ness and address spaces in particular.
/// This code is duplicated in `Sema.analyzePtrArithmetic`.
/// May perform type resolution and return a transitive `error.AnalysisFail`.
pub fn elemPtrType(ptr_ty: Type, offset: ?usize, pt: Zcu.PerThread) !Type {
    const zcu = pt.zcu;
    const ptr_info = ptr_ty.ptrInfo(zcu);
    const elem_ty = ptr_ty.elemType2(zcu);
    const is_allowzero = ptr_info.flags.is_allowzero and (offset orelse 0) == 0;
    const parent_ty = ptr_ty.childType(zcu);

    const VI = InternPool.Key.PtrType.VectorIndex;

    const vector_info: struct {
        host_size: u16 = 0,
        alignment: Alignment = .none,
        vector_index: VI = .none,
    } = if (parent_ty.isVector(zcu) and ptr_info.flags.size == .One) blk: {
        const elem_bits = elem_ty.bitSize(pt);
        if (elem_bits == 0) break :blk .{};
        const is_packed = elem_bits < 8 or !std.math.isPowerOfTwo(elem_bits);
        if (!is_packed) break :blk .{};

        break :blk .{
            .host_size = @intCast(parent_ty.arrayLen(zcu)),
            .alignment = parent_ty.abiAlignment(pt),
            .vector_index = if (offset) |some| @enumFromInt(some) else .runtime,
        };
    } else .{};

    const alignment: Alignment = a: {
        // Calculate the new pointer alignment.
        if (ptr_info.flags.alignment == .none) {
            // In case of an ABI-aligned pointer, any pointer arithmetic
            // maintains the same ABI-alignedness.
            break :a vector_info.alignment;
        }
        // If the addend is not a comptime-known value we can still count on
        // it being a multiple of the type size.
        const elem_size = (try elem_ty.abiSizeAdvanced(pt, .sema)).scalar;
        const addend = if (offset) |off| elem_size * off else elem_size;

        // The resulting pointer is aligned to the lcd between the offset (an
        // arbitrary number) and the alignment factor (always a power of two,
        // non zero).
        const new_align: Alignment = @enumFromInt(@min(
            @ctz(addend),
            ptr_info.flags.alignment.toLog2Units(),
        ));
        assert(new_align != .none);
        break :a new_align;
    };
    return pt.ptrTypeSema(.{
        .child = elem_ty.toIntern(),
        .flags = .{
            .alignment = alignment,
            .is_const = ptr_info.flags.is_const,
            .is_volatile = ptr_info.flags.is_volatile,
            .is_allowzero = is_allowzero,
            .address_space = ptr_info.flags.address_space,
            .vector_index = vector_info.vector_index,
        },
        .packed_offset = .{
            .host_size = vector_info.host_size,
            .bit_offset = 0,
        },
    });
}

pub const @"u1": Type = .{ .ip_index = .u1_type };
pub const @"u8": Type = .{ .ip_index = .u8_type };
pub const @"u16": Type = .{ .ip_index = .u16_type };
pub const @"u29": Type = .{ .ip_index = .u29_type };
pub const @"u32": Type = .{ .ip_index = .u32_type };
pub const @"u64": Type = .{ .ip_index = .u64_type };
pub const @"u80": Type = .{ .ip_index = .u80_type };
pub const @"u128": Type = .{ .ip_index = .u128_type };

pub const @"i8": Type = .{ .ip_index = .i8_type };
pub const @"i16": Type = .{ .ip_index = .i16_type };
pub const @"i32": Type = .{ .ip_index = .i32_type };
pub const @"i64": Type = .{ .ip_index = .i64_type };
pub const @"i128": Type = .{ .ip_index = .i128_type };

pub const @"f16": Type = .{ .ip_index = .f16_type };
pub const @"f32": Type = .{ .ip_index = .f32_type };
pub const @"f64": Type = .{ .ip_index = .f64_type };
pub const @"f80": Type = .{ .ip_index = .f80_type };
pub const @"f128": Type = .{ .ip_index = .f128_type };

pub const @"bool": Type = .{ .ip_index = .bool_type };
pub const @"usize": Type = .{ .ip_index = .usize_type };
pub const @"isize": Type = .{ .ip_index = .isize_type };
pub const @"comptime_int": Type = .{ .ip_index = .comptime_int_type };
pub const @"comptime_float": Type = .{ .ip_index = .comptime_float_type };
pub const @"void": Type = .{ .ip_index = .void_type };
pub const @"type": Type = .{ .ip_index = .type_type };
pub const @"anyerror": Type = .{ .ip_index = .anyerror_type };
pub const @"anyopaque": Type = .{ .ip_index = .anyopaque_type };
pub const @"anyframe": Type = .{ .ip_index = .anyframe_type };
pub const @"null": Type = .{ .ip_index = .null_type };
pub const @"undefined": Type = .{ .ip_index = .undefined_type };
pub const @"noreturn": Type = .{ .ip_index = .noreturn_type };

pub const @"c_char": Type = .{ .ip_index = .c_char_type };
pub const @"c_short": Type = .{ .ip_index = .c_short_type };
pub const @"c_ushort": Type = .{ .ip_index = .c_ushort_type };
pub const @"c_int": Type = .{ .ip_index = .c_int_type };
pub const @"c_uint": Type = .{ .ip_index = .c_uint_type };
pub const @"c_long": Type = .{ .ip_index = .c_long_type };
pub const @"c_ulong": Type = .{ .ip_index = .c_ulong_type };
pub const @"c_longlong": Type = .{ .ip_index = .c_longlong_type };
pub const @"c_ulonglong": Type = .{ .ip_index = .c_ulonglong_type };
pub const @"c_longdouble": Type = .{ .ip_index = .c_longdouble_type };

pub const slice_const_u8: Type = .{ .ip_index = .slice_const_u8_type };
pub const manyptr_u8: Type = .{ .ip_index = .manyptr_u8_type };
pub const single_const_pointer_to_comptime_int: Type = .{
    .ip_index = .single_const_pointer_to_comptime_int_type,
};
pub const slice_const_u8_sentinel_0: Type = .{ .ip_index = .slice_const_u8_sentinel_0_type };
pub const empty_struct_literal: Type = .{ .ip_index = .empty_struct_type };

pub const generic_poison: Type = .{ .ip_index = .generic_poison_type };

pub fn smallestUnsignedBits(max: u64) u16 {
    if (max == 0) return 0;
    const base = std.math.log2(max);
    const upper = (@as(u64, 1) << @as(u6, @intCast(base))) - 1;
    return @as(u16, @intCast(base + @intFromBool(upper < max)));
}

/// This is only used for comptime asserts. Bump this number when you make a change
/// to packed struct layout to find out all the places in the codebase you need to edit!
pub const packed_struct_layout_version = 2;

fn cTypeAlign(target: Target, c_type: Target.CType) Alignment {
    return Alignment.fromByteUnits(target.c_type_alignment(c_type));
}
