const std = @import("std");
const builtin = @import("builtin");
const Value = @import("value.zig").Value;
const assert = std.debug.assert;
const Target = std.Target;
const Zcu = @import("Module.zig");
const log = std.log.scoped(.Type);
const target_util = @import("target.zig");
const TypedValue = @import("TypedValue.zig");
const Sema = @import("Sema.zig");
const InternPool = @import("InternPool.zig");
const Alignment = InternPool.Alignment;

/// Both types and values are canonically represented by a single 32-bit integer
/// which is an index into an `InternPool` data structure.
/// This struct abstracts around this storage by providing methods only
/// applicable to types rather than values in general.
pub const Type = struct {
    ip_index: InternPool.Index,

    pub fn zigTypeTag(ty: Type, zcu: *const Zcu) std.builtin.TypeId {
        return ty.zigTypeTagOrPoison(zcu) catch unreachable;
    }

    pub fn zigTypeTagOrPoison(ty: Type, zcu: *const Zcu) error{GenericPoison}!std.builtin.TypeId {
        return zcu.intern_pool.zigTypeTagOrPoison(ty.toIntern());
    }

    pub fn baseZigTypeTag(self: Type, zcu: *Zcu) std.builtin.TypeId {
        return switch (self.zigTypeTag(zcu)) {
            .ErrorUnion => self.errorUnionPayload(zcu).baseZigTypeTag(zcu),
            .Optional => {
                return self.optionalChild(zcu).baseZigTypeTag(zcu);
            },
            else => |t| t,
        };
    }

    pub fn isSelfComparable(ty: Type, zcu: *const Zcu, is_equality_cmp: bool) bool {
        return switch (ty.zigTypeTag(zcu)) {
            .Int,
            .Float,
            .ComptimeFloat,
            .ComptimeInt,
            => true,

            .Vector => ty.elemType2(zcu).isSelfComparable(zcu, is_equality_cmp),

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

            .Pointer => !ty.isSlice(zcu) and (is_equality_cmp or ty.isCPtr(zcu)),
            .Optional => {
                if (!is_equality_cmp) return false;
                return ty.optionalChild(zcu).isSelfComparable(zcu, is_equality_cmp);
            },
        };
    }

    /// If it is a function pointer, returns the function type. Otherwise returns null.
    pub fn castPtrToFn(ty: Type, zcu: *const Zcu) ?Type {
        if (ty.zigTypeTag(zcu) != .Pointer) return null;
        const elem_ty = ty.childType(zcu);
        if (elem_ty.zigTypeTag(zcu) != .Fn) return null;
        return elem_ty;
    }

    /// Asserts the type is a pointer.
    pub fn ptrIsMutable(ty: Type, zcu: *const Zcu) bool {
        return !zcu.intern_pool.indexToKey(ty.toIntern()).ptr_type.flags.is_const;
    }

    pub const ArrayInfo = struct {
        elem_type: Type,
        sentinel: ?Value = null,
        len: u64,
    };

    pub fn arrayInfo(self: Type, zcu: *const Zcu) ArrayInfo {
        return .{
            .len = self.arrayLen(zcu),
            .sentinel = self.sentinel(zcu),
            .elem_type = self.childType(zcu),
        };
    }

    pub fn ptrInfo(ty: Type, zcu: *const Zcu) InternPool.Key.PtrType {
        return switch (zcu.intern_pool.indexToKey(ty.toIntern())) {
            .ptr_type => |p| p,
            .opt_type => |child| switch (zcu.intern_pool.indexToKey(child)) {
                .ptr_type => |p| p,
                else => unreachable,
            },
            else => unreachable,
        };
    }

    pub fn eql(a: Type, b: Type, zcu: *const Zcu) bool {
        _ = zcu; // TODO: remove this parameter
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

    pub fn fmt(ty: Type, zcu: *Zcu) std.fmt.Formatter(format2) {
        return .{ .data = .{
            .ty = ty,
            .zcu = zcu,
        } };
    }

    const FormatContext = struct {
        ty: Type,
        zcu: *Zcu,
    };

    fn format2(
        ctx: FormatContext,
        comptime unused_format_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        comptime assert(unused_format_string.len == 0);
        _ = options;
        return print(ctx.ty, writer, ctx.zcu);
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
    pub fn print(ty: Type, writer: anytype, zcu: *Zcu) @TypeOf(writer).Error!void {
        const ip = &zcu.intern_pool;
        switch (ip.indexToKey(ty.toIntern())) {
            .int_type => |int_type| {
                const sign_char: u8 = switch (int_type.signedness) {
                    .signed => 'i',
                    .unsigned => 'u',
                };
                return writer.print("{c}{d}", .{ sign_char, int_type.bits });
            },
            .ptr_type => {
                const info = ty.ptrInfo(zcu);

                if (info.sentinel != .none) switch (info.flags.size) {
                    .One, .C => unreachable,
                    .Many => try writer.print("[*:{}]", .{Value.fromInterned(info.sentinel).fmtValue(Type.fromInterned(info.child), zcu)}),
                    .Slice => try writer.print("[:{}]", .{Value.fromInterned(info.sentinel).fmtValue(Type.fromInterned(info.child), zcu)}),
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
                        Type.fromInterned(info.child).abiAlignment(zcu);
                    try writer.print("align({d}", .{alignment.toByteUnits(0)});

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

                try print(Type.fromInterned(info.child), writer, zcu);
                return;
            },
            .array_type => |array_type| {
                if (array_type.sentinel == .none) {
                    try writer.print("[{d}]", .{array_type.len});
                    try print(Type.fromInterned(array_type.child), writer, zcu);
                } else {
                    try writer.print("[{d}:{}]", .{
                        array_type.len,
                        Value.fromInterned(array_type.sentinel).fmtValue(Type.fromInterned(array_type.child), zcu),
                    });
                    try print(Type.fromInterned(array_type.child), writer, zcu);
                }
                return;
            },
            .vector_type => |vector_type| {
                try writer.print("@Vector({d}, ", .{vector_type.len});
                try print(Type.fromInterned(vector_type.child), writer, zcu);
                try writer.writeAll(")");
                return;
            },
            .opt_type => |child| {
                try writer.writeByte('?');
                return print(Type.fromInterned(child), writer, zcu);
            },
            .error_union_type => |error_union_type| {
                try print(Type.fromInterned(error_union_type.error_set_type), writer, zcu);
                try writer.writeByte('!');
                try print(Type.fromInterned(error_union_type.payload_type), writer, zcu);
                return;
            },
            .inferred_error_set_type => |func_index| {
                try writer.writeAll("@typeInfo(@typeInfo(@TypeOf(");
                const owner_decl = zcu.funcOwnerDeclPtr(func_index);
                try owner_decl.renderFullyQualifiedName(zcu, writer);
                try writer.writeAll(")).Fn.return_type.?).ErrorUnion.error_set");
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
            .struct_type => |struct_type| {
                if (struct_type.decl.unwrap()) |decl_index| {
                    const decl = zcu.declPtr(decl_index);
                    try decl.renderFullyQualifiedName(zcu, writer);
                } else if (struct_type.namespace.unwrap()) |namespace_index| {
                    const namespace = zcu.namespacePtr(namespace_index);
                    try namespace.renderFullyQualifiedName(zcu, .empty, writer);
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
                        try writer.print("{}: ", .{anon_struct.names.get(ip)[i].fmt(&zcu.intern_pool)});
                    }

                    try print(Type.fromInterned(field_ty), writer, zcu);

                    if (val != .none) {
                        try writer.print(" = {}", .{Value.fromInterned(val).fmtValue(Type.fromInterned(field_ty), zcu)});
                    }
                }
                try writer.writeAll("}");
            },

            .union_type => |union_type| {
                const decl = zcu.declPtr(union_type.decl);
                try decl.renderFullyQualifiedName(zcu, writer);
            },
            .opaque_type => |opaque_type| {
                const decl = zcu.declPtr(opaque_type.decl);
                try decl.renderFullyQualifiedName(zcu, writer);
            },
            .enum_type => |enum_type| {
                const decl = zcu.declPtr(enum_type.decl);
                try decl.renderFullyQualifiedName(zcu, writer);
            },
            .func_type => |fn_info| {
                if (fn_info.is_noinline) {
                    try writer.writeAll("noinline ");
                }
                try writer.writeAll("fn (");
                const param_types = fn_info.param_types.get(&zcu.intern_pool);
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
                        try print(Type.fromInterned(param_ty), writer, zcu);
                    }
                }
                if (fn_info.is_var_args) {
                    if (param_types.len != 0) {
                        try writer.writeAll(", ");
                    }
                    try writer.writeAll("...");
                }
                try writer.writeAll(") ");
                if (fn_info.alignment.toByteUnitsOptional()) |a| {
                    try writer.print("align({d}) ", .{a});
                }
                if (fn_info.cc != .Unspecified) {
                    try writer.writeAll("callconv(.");
                    try writer.writeAll(@tagName(fn_info.cc));
                    try writer.writeAll(") ");
                }
                if (fn_info.return_type == .generic_poison_type) {
                    try writer.writeAll("anytype");
                } else {
                    try print(Type.fromInterned(fn_info.return_type), writer, zcu);
                }
            },
            .anyframe_type => |child| {
                if (child == .none) return writer.writeAll("anyframe");
                try writer.writeAll("anyframe->");
                return print(Type.fromInterned(child), writer, zcu);
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

    const RuntimeBitsError = Zcu.CompileError || error{NeedLazy};

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
        zcu: *Zcu,
        ignore_comptime_only: bool,
        strat: AbiAlignmentAdvancedStrat,
    ) RuntimeBitsError!bool {
        const ip = &zcu.intern_pool;
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
                        .sema => |sema| !(try sema.typeRequiresComptime(ty)),
                        .eager => !comptimeOnly(ty, zcu),
                        .lazy => error.NeedLazy,
                    };
                },
                .anyframe_type => true,
                .array_type => |array_type| {
                    if (array_type.sentinel != .none) {
                        return Type.fromInterned(array_type.child).hasRuntimeBitsAdvanced(zcu, ignore_comptime_only, strat);
                    } else {
                        return array_type.len > 0 and
                            try Type.fromInterned(array_type.child).hasRuntimeBitsAdvanced(zcu, ignore_comptime_only, strat);
                    }
                },
                .vector_type => |vector_type| {
                    return vector_type.len > 0 and
                        try Type.fromInterned(vector_type.child).hasRuntimeBitsAdvanced(zcu, ignore_comptime_only, strat);
                },
                .opt_type => |child| {
                    const child_ty = Type.fromInterned(child);
                    if (child_ty.isNoReturn(zcu)) {
                        // Then the optional is comptime-known to be null.
                        return false;
                    }
                    if (ignore_comptime_only) return true;
                    return switch (strat) {
                        .sema => |sema| !(try sema.typeRequiresComptime(child_ty)),
                        .eager => !comptimeOnly(child_ty, zcu),
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
                .struct_type => |struct_type| {
                    if (struct_type.assumeRuntimeBitsIfFieldTypesWip(ip)) {
                        // In this case, we guess that hasRuntimeBits() for this type is true,
                        // and then later if our guess was incorrect, we emit a compile error.
                        return true;
                    }
                    switch (strat) {
                        .sema => |sema| _ = try sema.resolveTypeFields(ty),
                        .eager => assert(struct_type.haveFieldTypes(ip)),
                        .lazy => if (!struct_type.haveFieldTypes(ip)) return error.NeedLazy,
                    }
                    for (0..struct_type.field_types.len) |i| {
                        if (struct_type.comptime_bits.getBit(ip, i)) continue;
                        const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[i]);
                        if (try field_ty.hasRuntimeBitsAdvanced(zcu, ignore_comptime_only, strat))
                            return true;
                    } else {
                        return false;
                    }
                },
                .anon_struct_type => |tuple| {
                    for (tuple.types.get(ip), tuple.values.get(ip)) |field_ty, val| {
                        if (val != .none) continue; // comptime field
                        if (try Type.fromInterned(field_ty).hasRuntimeBitsAdvanced(zcu, ignore_comptime_only, strat)) return true;
                    }
                    return false;
                },

                .union_type => |union_type| {
                    switch (union_type.flagsPtr(ip).runtime_tag) {
                        .none => {
                            if (union_type.flagsPtr(ip).status == .field_types_wip) {
                                // In this case, we guess that hasRuntimeBits() for this type is true,
                                // and then later if our guess was incorrect, we emit a compile error.
                                union_type.flagsPtr(ip).assumed_runtime_bits = true;
                                return true;
                            }
                        },
                        .safety, .tagged => {
                            const tag_ty = union_type.tagTypePtr(ip).*;
                            // tag_ty will be `none` if this union's tag type is not resolved yet,
                            // in which case we want control flow to continue down below.
                            if (tag_ty != .none and
                                try Type.fromInterned(tag_ty).hasRuntimeBitsAdvanced(zcu, ignore_comptime_only, strat))
                            {
                                return true;
                            }
                        },
                    }
                    switch (strat) {
                        .sema => |sema| _ = try sema.resolveTypeFields(ty),
                        .eager => assert(union_type.flagsPtr(ip).status.haveFieldTypes()),
                        .lazy => if (!union_type.flagsPtr(ip).status.haveFieldTypes())
                            return error.NeedLazy,
                    }
                    const union_obj = ip.loadUnionType(union_type);
                    for (0..union_obj.field_types.len) |field_index| {
                        const field_ty = Type.fromInterned(union_obj.field_types.get(ip)[field_index]);
                        if (try field_ty.hasRuntimeBitsAdvanced(zcu, ignore_comptime_only, strat))
                            return true;
                    } else {
                        return false;
                    }
                },

                .opaque_type => true,
                .enum_type => |enum_type| Type.fromInterned(enum_type.tag_ty).hasRuntimeBitsAdvanced(zcu, ignore_comptime_only, strat),

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
    pub fn hasWellDefinedLayout(ty: Type, zcu: *Zcu) bool {
        const ip = &zcu.intern_pool;
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

            .array_type => |array_type| Type.fromInterned(array_type.child).hasWellDefinedLayout(zcu),
            .opt_type => ty.isPtrLikeOptional(zcu),
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
            .struct_type => |struct_type| {
                // Struct with no fields have a well-defined layout of no bits.
                return struct_type.layout != .Auto or struct_type.field_types.len == 0;
            },
            .union_type => |union_type| switch (union_type.flagsPtr(ip).runtime_tag) {
                .none, .safety => union_type.flagsPtr(ip).layout != .Auto,
                .tagged => false,
            },
            .enum_type => |enum_type| switch (enum_type.tag_mode) {
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
            .opt,
            .aggregate,
            .un,
            // memoization, not types
            .memoized_call,
            => unreachable,
        };
    }

    pub fn hasRuntimeBits(ty: Type, zcu: *Zcu) bool {
        return hasRuntimeBitsAdvanced(ty, zcu, false, .eager) catch unreachable;
    }

    pub fn hasRuntimeBitsIgnoreComptime(ty: Type, zcu: *Zcu) bool {
        return hasRuntimeBitsAdvanced(ty, zcu, true, .eager) catch unreachable;
    }

    pub fn fnHasRuntimeBits(ty: Type, zcu: *Zcu) bool {
        return ty.fnHasRuntimeBitsAdvanced(zcu, null) catch unreachable;
    }

    /// Determines whether a function type has runtime bits, i.e. whether a
    /// function with this type can exist at runtime.
    /// Asserts that `ty` is a function type.
    /// If `opt_sema` is not provided, asserts that the return type is sufficiently resolved.
    pub fn fnHasRuntimeBitsAdvanced(ty: Type, zcu: *Zcu, opt_sema: ?*Sema) Zcu.CompileError!bool {
        const fn_info = zcu.typeToFunc(ty).?;
        if (fn_info.is_generic) return false;
        if (fn_info.is_var_args) return true;
        if (fn_info.cc == .Inline) return false;
        return !try Type.fromInterned(fn_info.return_type).comptimeOnlyAdvanced(zcu, opt_sema);
    }

    pub fn isFnOrHasRuntimeBits(ty: Type, zcu: *Zcu) bool {
        switch (ty.zigTypeTag(zcu)) {
            .Fn => return ty.fnHasRuntimeBits(zcu),
            else => return ty.hasRuntimeBits(zcu),
        }
    }

    /// Same as `isFnOrHasRuntimeBits` but comptime-only types may return a false positive.
    pub fn isFnOrHasRuntimeBitsIgnoreComptime(ty: Type, zcu: *Zcu) bool {
        return switch (ty.zigTypeTag(zcu)) {
            .Fn => true,
            else => return ty.hasRuntimeBitsIgnoreComptime(zcu),
        };
    }

    pub fn isNoReturn(ty: Type, zcu: *Zcu) bool {
        return zcu.intern_pool.isNoReturn(ty.toIntern());
    }

    /// Returns `none` if the pointer is naturally aligned and the element type is 0-bit.
    pub fn ptrAlignment(ty: Type, zcu: *Zcu) Alignment {
        return ptrAlignmentAdvanced(ty, zcu, null) catch unreachable;
    }

    pub fn ptrAlignmentAdvanced(ty: Type, zcu: *Zcu, opt_sema: ?*Sema) !Alignment {
        return switch (zcu.intern_pool.indexToKey(ty.toIntern())) {
            .ptr_type => |ptr_type| {
                if (ptr_type.flags.alignment != .none)
                    return ptr_type.flags.alignment;

                if (opt_sema) |sema| {
                    const res = try Type.fromInterned(ptr_type.child).abiAlignmentAdvanced(zcu, .{ .sema = sema });
                    return res.scalar;
                }

                return (Type.fromInterned(ptr_type.child).abiAlignmentAdvanced(zcu, .eager) catch unreachable).scalar;
            },
            .opt_type => |child| Type.fromInterned(child).ptrAlignmentAdvanced(zcu, opt_sema),
            else => unreachable,
        };
    }

    pub fn ptrAddressSpace(ty: Type, zcu: *const Zcu) std.builtin.AddressSpace {
        return switch (zcu.intern_pool.indexToKey(ty.toIntern())) {
            .ptr_type => |ptr_type| ptr_type.flags.address_space,
            .opt_type => |child| zcu.intern_pool.indexToKey(child).ptr_type.flags.address_space,
            else => unreachable,
        };
    }

    /// Never returns `none`. Asserts that all necessary type resolution is already done.
    pub fn abiAlignment(ty: Type, zcu: *Zcu) Alignment {
        return (ty.abiAlignmentAdvanced(zcu, .eager) catch unreachable).scalar;
    }

    /// May capture a reference to `ty`.
    /// Returned value has type `comptime_int`.
    pub fn lazyAbiAlignment(ty: Type, zcu: *Zcu) !Value {
        switch (try ty.abiAlignmentAdvanced(zcu, .lazy)) {
            .val => |val| return val,
            .scalar => |x| return zcu.intValue(Type.comptime_int, x.toByteUnits(0)),
        }
    }

    pub const AbiAlignmentAdvanced = union(enum) {
        scalar: Alignment,
        val: Value,
    };

    pub const AbiAlignmentAdvancedStrat = union(enum) {
        eager,
        lazy,
        sema: *Sema,
    };

    /// If you pass `eager` you will get back `scalar` and assert the type is resolved.
    /// In this case there will be no error, guaranteed.
    /// If you pass `lazy` you may get back `scalar` or `val`.
    /// If `val` is returned, a reference to `ty` has been captured.
    /// If you pass `sema` you will get back `scalar` and resolve the type if
    /// necessary, possibly returning a CompileError.
    pub fn abiAlignmentAdvanced(
        ty: Type,
        zcu: *Zcu,
        strat: AbiAlignmentAdvancedStrat,
    ) Zcu.CompileError!AbiAlignmentAdvanced {
        const target = zcu.getTarget();
        const ip = &zcu.intern_pool;

        const opt_sema = switch (strat) {
            .sema => |sema| sema,
            else => null,
        };

        switch (ty.toIntern()) {
            .empty_struct_type => return AbiAlignmentAdvanced{ .scalar = .@"1" },
            else => switch (ip.indexToKey(ty.toIntern())) {
                .int_type => |int_type| {
                    if (int_type.bits == 0) return AbiAlignmentAdvanced{ .scalar = .@"1" };
                    return .{ .scalar = intAbiAlignment(int_type.bits, target) };
                },
                .ptr_type, .anyframe_type => {
                    return .{ .scalar = Alignment.fromByteUnits(@divExact(target.ptrBitWidth(), 8)) };
                },
                .array_type => |array_type| {
                    return Type.fromInterned(array_type.child).abiAlignmentAdvanced(zcu, strat);
                },
                .vector_type => |vector_type| {
                    const bits_u64 = try bitSizeAdvanced(Type.fromInterned(vector_type.child), zcu, opt_sema);
                    const bits: u32 = @intCast(bits_u64);
                    const bytes = ((bits * vector_type.len) + 7) / 8;
                    const alignment = std.math.ceilPowerOfTwoAssert(u32, bytes);
                    return .{ .scalar = Alignment.fromByteUnits(alignment) };
                },

                .opt_type => return abiAlignmentAdvancedOptional(ty, zcu, strat),
                .error_union_type => |info| return abiAlignmentAdvancedErrorUnion(ty, zcu, strat, Type.fromInterned(info.payload_type)),

                .error_set_type, .inferred_error_set_type => {
                    const bits = zcu.errorSetBits();
                    if (bits == 0) return AbiAlignmentAdvanced{ .scalar = .@"1" };
                    return .{ .scalar = intAbiAlignment(bits, target) };
                },

                // represents machine code; not a pointer
                .func_type => |func_type| return .{
                    .scalar = if (func_type.alignment != .none)
                        func_type.alignment
                    else
                        target_util.defaultFunctionAlignment(target),
                },

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
                    .export_options,
                    .extern_options,
                    .type_info,
                    => return .{
                        .scalar = Alignment.fromByteUnits(@divExact(target.ptrBitWidth(), 8)),
                    },

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
                        else => {
                            const u80_ty: Type = .{ .ip_index = .u80_type };
                            return .{ .scalar = abiAlignment(u80_ty, zcu) };
                        },
                    },
                    .f128 => switch (target.c_type_bit_size(.longdouble)) {
                        128 => return .{ .scalar = cTypeAlign(target, .longdouble) },
                        else => return .{ .scalar = .@"16" },
                    },

                    .anyerror, .adhoc_inferred_error_set => {
                        const bits = zcu.errorSetBits();
                        if (bits == 0) return AbiAlignmentAdvanced{ .scalar = .@"1" };
                        return .{ .scalar = intAbiAlignment(bits, target) };
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
                .struct_type => |struct_type| {
                    if (struct_type.layout == .Packed) {
                        switch (strat) {
                            .sema => |sema| try sema.resolveTypeLayout(ty),
                            .lazy => if (struct_type.backingIntType(ip).* == .none) return .{
                                .val = Value.fromInterned((try zcu.intern(.{ .int = .{
                                    .ty = .comptime_int_type,
                                    .storage = .{ .lazy_align = ty.toIntern() },
                                } }))),
                            },
                            .eager => {},
                        }
                        return .{ .scalar = Type.fromInterned(struct_type.backingIntType(ip).*).abiAlignment(zcu) };
                    }

                    const flags = struct_type.flagsPtr(ip).*;
                    if (flags.alignment != .none) return .{ .scalar = flags.alignment };

                    return switch (strat) {
                        .eager => unreachable, // struct alignment not resolved
                        .sema => |sema| .{
                            .scalar = try sema.resolveStructAlignment(ty.toIntern(), struct_type),
                        },
                        .lazy => .{ .val = Value.fromInterned((try zcu.intern(.{ .int = .{
                            .ty = .comptime_int_type,
                            .storage = .{ .lazy_align = ty.toIntern() },
                        } }))) },
                    };
                },
                .anon_struct_type => |tuple| {
                    var big_align: Alignment = .@"1";
                    for (tuple.types.get(ip), tuple.values.get(ip)) |field_ty, val| {
                        if (val != .none) continue; // comptime field
                        switch (try Type.fromInterned(field_ty).abiAlignmentAdvanced(zcu, strat)) {
                            .scalar => |field_align| big_align = big_align.max(field_align),
                            .val => switch (strat) {
                                .eager => unreachable, // field type alignment not resolved
                                .sema => unreachable, // passed to abiAlignmentAdvanced above
                                .lazy => return .{ .val = Value.fromInterned((try zcu.intern(.{ .int = .{
                                    .ty = .comptime_int_type,
                                    .storage = .{ .lazy_align = ty.toIntern() },
                                } }))) },
                            },
                        }
                    }
                    return .{ .scalar = big_align };
                },
                .union_type => |union_type| {
                    const flags = union_type.flagsPtr(ip).*;
                    if (flags.alignment != .none) return .{ .scalar = flags.alignment };

                    if (!union_type.haveLayout(ip)) switch (strat) {
                        .eager => unreachable, // union layout not resolved
                        .sema => |sema| return .{ .scalar = try sema.resolveUnionAlignment(ty, union_type) },
                        .lazy => return .{ .val = Value.fromInterned((try zcu.intern(.{ .int = .{
                            .ty = .comptime_int_type,
                            .storage = .{ .lazy_align = ty.toIntern() },
                        } }))) },
                    };

                    return .{ .scalar = union_type.flagsPtr(ip).alignment };
                },
                .opaque_type => return .{ .scalar = .@"1" },
                .enum_type => |enum_type| return .{
                    .scalar = Type.fromInterned(enum_type.tag_ty).abiAlignment(zcu),
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
        zcu: *Zcu,
        strat: AbiAlignmentAdvancedStrat,
        payload_ty: Type,
    ) Zcu.CompileError!AbiAlignmentAdvanced {
        // This code needs to be kept in sync with the equivalent switch prong
        // in abiSizeAdvanced.
        const code_align = abiAlignment(Type.anyerror, zcu);
        switch (strat) {
            .eager, .sema => {
                if (!(payload_ty.hasRuntimeBitsAdvanced(zcu, false, strat) catch |err| switch (err) {
                    error.NeedLazy => return .{ .val = Value.fromInterned((try zcu.intern(.{ .int = .{
                        .ty = .comptime_int_type,
                        .storage = .{ .lazy_align = ty.toIntern() },
                    } }))) },
                    else => |e| return e,
                })) {
                    return .{ .scalar = code_align };
                }
                return .{ .scalar = code_align.max(
                    (try payload_ty.abiAlignmentAdvanced(zcu, strat)).scalar,
                ) };
            },
            .lazy => {
                switch (try payload_ty.abiAlignmentAdvanced(zcu, strat)) {
                    .scalar => |payload_align| return .{ .scalar = code_align.max(payload_align) },
                    .val => {},
                }
                return .{ .val = Value.fromInterned((try zcu.intern(.{ .int = .{
                    .ty = .comptime_int_type,
                    .storage = .{ .lazy_align = ty.toIntern() },
                } }))) };
            },
        }
    }

    fn abiAlignmentAdvancedOptional(
        ty: Type,
        zcu: *Zcu,
        strat: AbiAlignmentAdvancedStrat,
    ) Zcu.CompileError!AbiAlignmentAdvanced {
        const target = zcu.getTarget();
        const child_type = ty.optionalChild(zcu);

        switch (child_type.zigTypeTag(zcu)) {
            .Pointer => return .{
                .scalar = Alignment.fromByteUnits(@divExact(target.ptrBitWidth(), 8)),
            },
            .ErrorSet => return abiAlignmentAdvanced(Type.anyerror, zcu, strat),
            .NoReturn => return .{ .scalar = .@"1" },
            else => {},
        }

        switch (strat) {
            .eager, .sema => {
                if (!(child_type.hasRuntimeBitsAdvanced(zcu, false, strat) catch |err| switch (err) {
                    error.NeedLazy => return .{ .val = Value.fromInterned((try zcu.intern(.{ .int = .{
                        .ty = .comptime_int_type,
                        .storage = .{ .lazy_align = ty.toIntern() },
                    } }))) },
                    else => |e| return e,
                })) {
                    return .{ .scalar = .@"1" };
                }
                return child_type.abiAlignmentAdvanced(zcu, strat);
            },
            .lazy => switch (try child_type.abiAlignmentAdvanced(zcu, strat)) {
                .scalar => |x| return .{ .scalar = x.max(.@"1") },
                .val => return .{ .val = Value.fromInterned((try zcu.intern(.{ .int = .{
                    .ty = .comptime_int_type,
                    .storage = .{ .lazy_align = ty.toIntern() },
                } }))) },
            },
        }
    }

    /// May capture a reference to `ty`.
    pub fn lazyAbiSize(ty: Type, zcu: *Zcu) !Value {
        switch (try ty.abiSizeAdvanced(zcu, .lazy)) {
            .val => |val| return val,
            .scalar => |x| return zcu.intValue(Type.comptime_int, x),
        }
    }

    /// Asserts the type has the ABI size already resolved.
    /// Types that return false for hasRuntimeBits() return 0.
    pub fn abiSize(ty: Type, zcu: *Zcu) u64 {
        return (abiSizeAdvanced(ty, zcu, .eager) catch unreachable).scalar;
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
        zcu: *Zcu,
        strat: AbiAlignmentAdvancedStrat,
    ) Zcu.CompileError!AbiSizeAdvanced {
        const target = zcu.getTarget();
        const ip = &zcu.intern_pool;

        switch (ty.toIntern()) {
            .empty_struct_type => return AbiSizeAdvanced{ .scalar = 0 },

            else => switch (ip.indexToKey(ty.toIntern())) {
                .int_type => |int_type| {
                    if (int_type.bits == 0) return AbiSizeAdvanced{ .scalar = 0 };
                    return AbiSizeAdvanced{ .scalar = intAbiSize(int_type.bits, target) };
                },
                .ptr_type => |ptr_type| switch (ptr_type.flags.size) {
                    .Slice => return .{ .scalar = @divExact(target.ptrBitWidth(), 8) * 2 },
                    else => return .{ .scalar = @divExact(target.ptrBitWidth(), 8) },
                },
                .anyframe_type => return AbiSizeAdvanced{ .scalar = @divExact(target.ptrBitWidth(), 8) },

                .array_type => |array_type| {
                    const len = array_type.len + @intFromBool(array_type.sentinel != .none);
                    if (len == 0) return .{ .scalar = 0 };
                    switch (try Type.fromInterned(array_type.child).abiSizeAdvanced(zcu, strat)) {
                        .scalar => |elem_size| return .{ .scalar = len * elem_size },
                        .val => switch (strat) {
                            .sema, .eager => unreachable,
                            .lazy => return .{ .val = Value.fromInterned((try zcu.intern(.{ .int = .{
                                .ty = .comptime_int_type,
                                .storage = .{ .lazy_size = ty.toIntern() },
                            } }))) },
                        },
                    }
                },
                .vector_type => |vector_type| {
                    const opt_sema = switch (strat) {
                        .sema => |sema| sema,
                        .eager => null,
                        .lazy => return .{ .val = Value.fromInterned((try zcu.intern(.{ .int = .{
                            .ty = .comptime_int_type,
                            .storage = .{ .lazy_size = ty.toIntern() },
                        } }))) },
                    };
                    const elem_bits = try Type.fromInterned(vector_type.child).bitSizeAdvanced(zcu, opt_sema);
                    const total_bits = elem_bits * vector_type.len;
                    const total_bytes = (total_bits + 7) / 8;
                    const alignment = switch (try ty.abiAlignmentAdvanced(zcu, strat)) {
                        .scalar => |x| x,
                        .val => return .{ .val = Value.fromInterned((try zcu.intern(.{ .int = .{
                            .ty = .comptime_int_type,
                            .storage = .{ .lazy_size = ty.toIntern() },
                        } }))) },
                    };
                    return AbiSizeAdvanced{ .scalar = alignment.forward(total_bytes) };
                },

                .opt_type => return ty.abiSizeAdvancedOptional(zcu, strat),

                .error_set_type, .inferred_error_set_type => {
                    const bits = zcu.errorSetBits();
                    if (bits == 0) return AbiSizeAdvanced{ .scalar = 0 };
                    return AbiSizeAdvanced{ .scalar = intAbiSize(bits, target) };
                },

                .error_union_type => |error_union_type| {
                    const payload_ty = Type.fromInterned(error_union_type.payload_type);
                    // This code needs to be kept in sync with the equivalent switch prong
                    // in abiAlignmentAdvanced.
                    const code_size = abiSize(Type.anyerror, zcu);
                    if (!(payload_ty.hasRuntimeBitsAdvanced(zcu, false, strat) catch |err| switch (err) {
                        error.NeedLazy => return .{ .val = Value.fromInterned((try zcu.intern(.{ .int = .{
                            .ty = .comptime_int_type,
                            .storage = .{ .lazy_size = ty.toIntern() },
                        } }))) },
                        else => |e| return e,
                    })) {
                        // Same as anyerror.
                        return AbiSizeAdvanced{ .scalar = code_size };
                    }
                    const code_align = abiAlignment(Type.anyerror, zcu);
                    const payload_align = abiAlignment(payload_ty, zcu);
                    const payload_size = switch (try payload_ty.abiSizeAdvanced(zcu, strat)) {
                        .scalar => |elem_size| elem_size,
                        .val => switch (strat) {
                            .sema => unreachable,
                            .eager => unreachable,
                            .lazy => return .{ .val = Value.fromInterned((try zcu.intern(.{ .int = .{
                                .ty = .comptime_int_type,
                                .storage = .{ .lazy_size = ty.toIntern() },
                            } }))) },
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
                    return AbiSizeAdvanced{ .scalar = size };
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
                    => return AbiSizeAdvanced{ .scalar = 1 },

                    .f16 => return AbiSizeAdvanced{ .scalar = 2 },
                    .f32 => return AbiSizeAdvanced{ .scalar = 4 },
                    .f64 => return AbiSizeAdvanced{ .scalar = 8 },
                    .f128 => return AbiSizeAdvanced{ .scalar = 16 },
                    .f80 => switch (target.c_type_bit_size(.longdouble)) {
                        80 => return AbiSizeAdvanced{ .scalar = target.c_type_byte_size(.longdouble) },
                        else => {
                            const u80_ty: Type = .{ .ip_index = .u80_type };
                            return AbiSizeAdvanced{ .scalar = abiSize(u80_ty, zcu) };
                        },
                    },

                    .usize,
                    .isize,
                    => return AbiSizeAdvanced{ .scalar = @divExact(target.ptrBitWidth(), 8) },

                    .c_char => return AbiSizeAdvanced{ .scalar = target.c_type_byte_size(.char) },
                    .c_short => return AbiSizeAdvanced{ .scalar = target.c_type_byte_size(.short) },
                    .c_ushort => return AbiSizeAdvanced{ .scalar = target.c_type_byte_size(.ushort) },
                    .c_int => return AbiSizeAdvanced{ .scalar = target.c_type_byte_size(.int) },
                    .c_uint => return AbiSizeAdvanced{ .scalar = target.c_type_byte_size(.uint) },
                    .c_long => return AbiSizeAdvanced{ .scalar = target.c_type_byte_size(.long) },
                    .c_ulong => return AbiSizeAdvanced{ .scalar = target.c_type_byte_size(.ulong) },
                    .c_longlong => return AbiSizeAdvanced{ .scalar = target.c_type_byte_size(.longlong) },
                    .c_ulonglong => return AbiSizeAdvanced{ .scalar = target.c_type_byte_size(.ulonglong) },
                    .c_longdouble => return AbiSizeAdvanced{ .scalar = target.c_type_byte_size(.longdouble) },

                    .anyopaque,
                    .void,
                    .type,
                    .comptime_int,
                    .comptime_float,
                    .null,
                    .undefined,
                    .enum_literal,
                    => return AbiSizeAdvanced{ .scalar = 0 },

                    .anyerror, .adhoc_inferred_error_set => {
                        const bits = zcu.errorSetBits();
                        if (bits == 0) return AbiSizeAdvanced{ .scalar = 0 };
                        return AbiSizeAdvanced{ .scalar = intAbiSize(bits, target) };
                    },

                    .prefetch_options => unreachable, // missing call to resolveTypeFields
                    .export_options => unreachable, // missing call to resolveTypeFields
                    .extern_options => unreachable, // missing call to resolveTypeFields

                    .type_info => unreachable,
                    .noreturn => unreachable,
                    .generic_poison => unreachable,
                },
                .struct_type => |struct_type| {
                    switch (strat) {
                        .sema => |sema| try sema.resolveTypeLayout(ty),
                        .lazy => switch (struct_type.layout) {
                            .Packed => {
                                if (struct_type.backingIntType(ip).* == .none) return .{
                                    .val = Value.fromInterned((try zcu.intern(.{ .int = .{
                                        .ty = .comptime_int_type,
                                        .storage = .{ .lazy_size = ty.toIntern() },
                                    } }))),
                                };
                            },
                            .Auto, .Extern => {
                                if (!struct_type.haveLayout(ip)) return .{
                                    .val = Value.fromInterned((try zcu.intern(.{ .int = .{
                                        .ty = .comptime_int_type,
                                        .storage = .{ .lazy_size = ty.toIntern() },
                                    } }))),
                                };
                            },
                        },
                        .eager => {},
                    }
                    return switch (struct_type.layout) {
                        .Packed => .{
                            .scalar = Type.fromInterned(struct_type.backingIntType(ip).*).abiSize(zcu),
                        },
                        .Auto, .Extern => .{ .scalar = struct_type.size(ip).* },
                    };
                },
                .anon_struct_type => |tuple| {
                    switch (strat) {
                        .sema => |sema| try sema.resolveTypeLayout(ty),
                        .lazy, .eager => {},
                    }
                    const field_count = tuple.types.len;
                    if (field_count == 0) {
                        return AbiSizeAdvanced{ .scalar = 0 };
                    }
                    return AbiSizeAdvanced{ .scalar = ty.structFieldOffset(field_count, zcu) };
                },

                .union_type => |union_type| {
                    switch (strat) {
                        .sema => |sema| try sema.resolveTypeLayout(ty),
                        .lazy => if (!union_type.flagsPtr(ip).status.haveLayout()) return .{
                            .val = Value.fromInterned((try zcu.intern(.{ .int = .{
                                .ty = .comptime_int_type,
                                .storage = .{ .lazy_size = ty.toIntern() },
                            } }))),
                        },
                        .eager => {},
                    }

                    return .{ .scalar = union_type.size(ip).* };
                },
                .opaque_type => unreachable, // no size available
                .enum_type => |enum_type| return AbiSizeAdvanced{ .scalar = Type.fromInterned(enum_type.tag_ty).abiSize(zcu) },

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
        zcu: *Zcu,
        strat: AbiAlignmentAdvancedStrat,
    ) Zcu.CompileError!AbiSizeAdvanced {
        const child_ty = ty.optionalChild(zcu);

        if (child_ty.isNoReturn(zcu)) {
            return AbiSizeAdvanced{ .scalar = 0 };
        }

        if (!(child_ty.hasRuntimeBitsAdvanced(zcu, false, strat) catch |err| switch (err) {
            error.NeedLazy => return .{ .val = Value.fromInterned((try zcu.intern(.{ .int = .{
                .ty = .comptime_int_type,
                .storage = .{ .lazy_size = ty.toIntern() },
            } }))) },
            else => |e| return e,
        })) return AbiSizeAdvanced{ .scalar = 1 };

        if (ty.optionalReprIsPayload(zcu)) {
            return abiSizeAdvanced(child_ty, zcu, strat);
        }

        const payload_size = switch (try child_ty.abiSizeAdvanced(zcu, strat)) {
            .scalar => |elem_size| elem_size,
            .val => switch (strat) {
                .sema => unreachable,
                .eager => unreachable,
                .lazy => return .{ .val = Value.fromInterned((try zcu.intern(.{ .int = .{
                    .ty = .comptime_int_type,
                    .storage = .{ .lazy_size = ty.toIntern() },
                } }))) },
            },
        };

        // Optional types are represented as a struct with the child type as the first
        // field and a boolean as the second. Since the child type's abi alignment is
        // guaranteed to be >= that of bool's (1 byte) the added size is exactly equal
        // to the child type's ABI alignment.
        return AbiSizeAdvanced{
            .scalar = child_ty.abiAlignment(zcu).toByteUnits(0) + payload_size,
        };
    }

    fn intAbiSize(bits: u16, target: Target) u64 {
        return intAbiAlignment(bits, target).forward(@as(u16, @intCast((@as(u17, bits) + 7) / 8)));
    }

    fn intAbiAlignment(bits: u16, target: Target) Alignment {
        return Alignment.fromByteUnits(@min(
            std.math.ceilPowerOfTwoPromote(u16, @as(u16, @intCast((@as(u17, bits) + 7) / 8))),
            target.maxIntAlignment(),
        ));
    }

    pub fn bitSize(ty: Type, zcu: *Zcu) u64 {
        return bitSizeAdvanced(ty, zcu, null) catch unreachable;
    }

    /// If you pass `opt_sema`, any recursive type resolutions will happen if
    /// necessary, possibly returning a CompileError. Passing `null` instead asserts
    /// the type is fully resolved, and there will be no error, guaranteed.
    pub fn bitSizeAdvanced(
        ty: Type,
        zcu: *Zcu,
        opt_sema: ?*Sema,
    ) Zcu.CompileError!u64 {
        const target = zcu.getTarget();
        const ip = &zcu.intern_pool;

        const strat: AbiAlignmentAdvancedStrat = if (opt_sema) |sema| .{ .sema = sema } else .eager;

        switch (ip.indexToKey(ty.toIntern())) {
            .int_type => |int_type| return int_type.bits,
            .ptr_type => |ptr_type| switch (ptr_type.flags.size) {
                .Slice => return target.ptrBitWidth() * 2,
                else => return target.ptrBitWidth(),
            },
            .anyframe_type => return target.ptrBitWidth(),

            .array_type => |array_type| {
                const len = array_type.len + @intFromBool(array_type.sentinel != .none);
                if (len == 0) return 0;
                const elem_ty = Type.fromInterned(array_type.child);
                const elem_size = @max(
                    (try elem_ty.abiAlignmentAdvanced(zcu, strat)).scalar.toByteUnits(0),
                    (try elem_ty.abiSizeAdvanced(zcu, strat)).scalar,
                );
                if (elem_size == 0) return 0;
                const elem_bit_size = try bitSizeAdvanced(elem_ty, zcu, opt_sema);
                return (len - 1) * 8 * elem_size + elem_bit_size;
            },
            .vector_type => |vector_type| {
                const child_ty = Type.fromInterned(vector_type.child);
                const elem_bit_size = try bitSizeAdvanced(child_ty, zcu, opt_sema);
                return elem_bit_size * vector_type.len;
            },
            .opt_type => {
                // Optionals and error unions are not packed so their bitsize
                // includes padding bits.
                return (try abiSizeAdvanced(ty, zcu, strat)).scalar * 8;
            },

            .error_set_type, .inferred_error_set_type => return zcu.errorSetBits(),

            .error_union_type => {
                // Optionals and error unions are not packed so their bitsize
                // includes padding bits.
                return (try abiSizeAdvanced(ty, zcu, strat)).scalar * 8;
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
                => return zcu.errorSetBits(),

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
            .struct_type => |struct_type| {
                if (struct_type.layout == .Packed) {
                    if (opt_sema) |sema| try sema.resolveTypeLayout(ty);
                    return try Type.fromInterned(struct_type.backingIntType(ip).*).bitSizeAdvanced(zcu, opt_sema);
                }
                return (try ty.abiSizeAdvanced(zcu, strat)).scalar * 8;
            },

            .anon_struct_type => {
                if (opt_sema) |sema| try sema.resolveTypeFields(ty);
                return (try ty.abiSizeAdvanced(zcu, strat)).scalar * 8;
            },

            .union_type => |union_type| {
                const is_packed = ty.containerLayout(zcu) == .Packed;
                if (opt_sema) |sema| {
                    try sema.resolveTypeFields(ty);
                    if (is_packed) try sema.resolveTypeLayout(ty);
                }
                if (!is_packed) {
                    return (try ty.abiSizeAdvanced(zcu, strat)).scalar * 8;
                }
                const union_obj = ip.loadUnionType(union_type);
                assert(union_obj.flagsPtr(ip).status.haveFieldTypes());

                var size: u64 = 0;
                for (0..union_obj.field_types.len) |field_index| {
                    const field_ty = union_obj.field_types.get(ip)[field_index];
                    size = @max(size, try bitSizeAdvanced(Type.fromInterned(field_ty), zcu, opt_sema));
                }

                return size;
            },
            .opaque_type => unreachable,
            .enum_type => |enum_type| return bitSizeAdvanced(Type.fromInterned(enum_type.tag_ty), zcu, opt_sema),

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
    pub fn layoutIsResolved(ty: Type, zcu: *Zcu) bool {
        const ip = &zcu.intern_pool;
        return switch (ip.indexToKey(ty.toIntern())) {
            .struct_type => |struct_type| struct_type.haveLayout(ip),
            .union_type => |union_type| union_type.haveLayout(ip),
            .array_type => |array_type| {
                if ((array_type.len + @intFromBool(array_type.sentinel != .none)) == 0) return true;
                return Type.fromInterned(array_type.child).layoutIsResolved(zcu);
            },
            .opt_type => |child| Type.fromInterned(child).layoutIsResolved(zcu),
            .error_union_type => |k| Type.fromInterned(k.payload_type).layoutIsResolved(zcu),
            else => true,
        };
    }

    pub fn isSinglePointer(ty: Type, zcu: *const Zcu) bool {
        return switch (zcu.intern_pool.indexToKey(ty.toIntern())) {
            .ptr_type => |ptr_info| ptr_info.flags.size == .One,
            else => false,
        };
    }

    /// Asserts `ty` is a pointer.
    pub fn ptrSize(ty: Type, zcu: *const Zcu) std.builtin.Type.Pointer.Size {
        return ptrSizeOrNull(ty, zcu).?;
    }

    /// Returns `null` if `ty` is not a pointer.
    pub fn ptrSizeOrNull(ty: Type, zcu: *const Zcu) ?std.builtin.Type.Pointer.Size {
        return switch (zcu.intern_pool.indexToKey(ty.toIntern())) {
            .ptr_type => |ptr_info| ptr_info.flags.size,
            else => null,
        };
    }

    pub fn isSlice(ty: Type, zcu: *const Zcu) bool {
        return switch (zcu.intern_pool.indexToKey(ty.toIntern())) {
            .ptr_type => |ptr_type| ptr_type.flags.size == .Slice,
            else => false,
        };
    }

    pub fn slicePtrFieldType(ty: Type, zcu: *const Zcu) Type {
        return Type.fromInterned(zcu.intern_pool.slicePtrType(ty.toIntern()));
    }

    pub fn isConstPtr(ty: Type, zcu: *const Zcu) bool {
        return switch (zcu.intern_pool.indexToKey(ty.toIntern())) {
            .ptr_type => |ptr_type| ptr_type.flags.is_const,
            else => false,
        };
    }

    pub fn isVolatilePtr(ty: Type, zcu: *const Zcu) bool {
        return isVolatilePtrIp(ty, &zcu.intern_pool);
    }

    pub fn isVolatilePtrIp(ty: Type, ip: *const InternPool) bool {
        return switch (ip.indexToKey(ty.toIntern())) {
            .ptr_type => |ptr_type| ptr_type.flags.is_volatile,
            else => false,
        };
    }

    pub fn isAllowzeroPtr(ty: Type, zcu: *const Zcu) bool {
        return switch (zcu.intern_pool.indexToKey(ty.toIntern())) {
            .ptr_type => |ptr_type| ptr_type.flags.is_allowzero,
            .opt_type => true,
            else => false,
        };
    }

    pub fn isCPtr(ty: Type, zcu: *const Zcu) bool {
        return switch (zcu.intern_pool.indexToKey(ty.toIntern())) {
            .ptr_type => |ptr_type| ptr_type.flags.size == .C,
            else => false,
        };
    }

    pub fn isPtrAtRuntime(ty: Type, zcu: *const Zcu) bool {
        return switch (zcu.intern_pool.indexToKey(ty.toIntern())) {
            .ptr_type => |ptr_type| switch (ptr_type.flags.size) {
                .Slice => false,
                .One, .Many, .C => true,
            },
            .opt_type => |child| switch (zcu.intern_pool.indexToKey(child)) {
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
    pub fn ptrAllowsZero(ty: Type, zcu: *const Zcu) bool {
        if (ty.isPtrLikeOptional(zcu)) {
            return true;
        }
        return ty.ptrInfo(zcu).flags.is_allowzero;
    }

    /// See also `isPtrLikeOptional`.
    pub fn optionalReprIsPayload(ty: Type, zcu: *const Zcu) bool {
        return switch (zcu.intern_pool.indexToKey(ty.toIntern())) {
            .opt_type => |child_type| child_type == .anyerror_type or switch (zcu.intern_pool.indexToKey(child_type)) {
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
    pub fn isPtrLikeOptional(ty: Type, zcu: *const Zcu) bool {
        return switch (zcu.intern_pool.indexToKey(ty.toIntern())) {
            .ptr_type => |ptr_type| ptr_type.flags.size == .C,
            .opt_type => |child| switch (zcu.intern_pool.indexToKey(child)) {
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
    pub fn childType(ty: Type, zcu: *const Zcu) Type {
        return childTypeIp(ty, &zcu.intern_pool);
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
    pub fn elemType2(ty: Type, zcu: *const Zcu) Type {
        return switch (zcu.intern_pool.indexToKey(ty.toIntern())) {
            .ptr_type => |ptr_type| switch (ptr_type.flags.size) {
                .One => Type.fromInterned(ptr_type.child).shallowElemType(zcu),
                .Many, .C, .Slice => Type.fromInterned(ptr_type.child),
            },
            .anyframe_type => |child| {
                assert(child != .none);
                return Type.fromInterned(child);
            },
            .vector_type => |vector_type| Type.fromInterned(vector_type.child),
            .array_type => |array_type| Type.fromInterned(array_type.child),
            .opt_type => |child| Type.fromInterned(zcu.intern_pool.childType(child)),
            else => unreachable,
        };
    }

    fn shallowElemType(child_ty: Type, zcu: *const Zcu) Type {
        return switch (child_ty.zigTypeTag(zcu)) {
            .Array, .Vector => child_ty.childType(zcu),
            else => child_ty,
        };
    }

    /// For vectors, returns the element type. Otherwise returns self.
    pub fn scalarType(ty: Type, zcu: *Zcu) Type {
        return switch (ty.zigTypeTag(zcu)) {
            .Vector => ty.childType(zcu),
            else => ty,
        };
    }

    /// Asserts that the type is an optional.
    /// Note that for C pointers this returns the type unmodified.
    pub fn optionalChild(ty: Type, zcu: *const Zcu) Type {
        return switch (zcu.intern_pool.indexToKey(ty.toIntern())) {
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
    pub fn unionTagType(ty: Type, zcu: *Zcu) ?Type {
        const ip = &zcu.intern_pool;
        return switch (ip.indexToKey(ty.toIntern())) {
            .union_type => |union_type| switch (union_type.flagsPtr(ip).runtime_tag) {
                .tagged => {
                    assert(union_type.flagsPtr(ip).status.haveFieldTypes());
                    return Type.fromInterned(union_type.enum_tag_ty);
                },
                else => null,
            },
            else => null,
        };
    }

    /// Same as `unionTagType` but includes safety tag.
    /// Codegen should use this version.
    pub fn unionTagTypeSafety(ty: Type, zcu: *Zcu) ?Type {
        const ip = &zcu.intern_pool;
        return switch (ip.indexToKey(ty.toIntern())) {
            .union_type => |union_type| {
                if (!union_type.hasTag(ip)) return null;
                assert(union_type.haveFieldTypes(ip));
                return Type.fromInterned(union_type.enum_tag_ty);
            },
            else => null,
        };
    }

    /// Asserts the type is a union; returns the tag type, even if the tag will
    /// not be stored at runtime.
    pub fn unionTagTypeHypothetical(ty: Type, zcu: *Zcu) Type {
        const union_obj = zcu.typeToUnion(ty).?;
        return Type.fromInterned(union_obj.enum_tag_ty);
    }

    pub fn unionFieldType(ty: Type, enum_tag: Value, zcu: *Zcu) ?Type {
        const ip = &zcu.intern_pool;
        const union_obj = zcu.typeToUnion(ty).?;
        const union_fields = union_obj.field_types.get(ip);
        const index = zcu.unionTagFieldIndex(union_obj, enum_tag) orelse return null;
        return Type.fromInterned(union_fields[index]);
    }

    pub fn unionTagFieldIndex(ty: Type, enum_tag: Value, zcu: *Zcu) ?u32 {
        const union_obj = zcu.typeToUnion(ty).?;
        return zcu.unionTagFieldIndex(union_obj, enum_tag);
    }

    pub fn unionHasAllZeroBitFieldTypes(ty: Type, zcu: *Zcu) bool {
        const ip = &zcu.intern_pool;
        const union_obj = zcu.typeToUnion(ty).?;
        for (union_obj.field_types.get(ip)) |field_ty| {
            if (Type.fromInterned(field_ty).hasRuntimeBits(zcu)) return false;
        }
        return true;
    }

    /// Returns the type used for backing storage of this union during comptime operations.
    /// Asserts the type is either an extern or packed union.
    pub fn unionBackingType(ty: Type, zcu: *Zcu) !Type {
        return switch (ty.containerLayout(zcu)) {
            .Extern => try zcu.arrayType(.{ .len = ty.abiSize(zcu), .child = .u8_type }),
            .Packed => try zcu.intType(.unsigned, @intCast(ty.bitSize(zcu))),
            .Auto => unreachable,
        };
    }

    pub fn unionGetLayout(ty: Type, zcu: *Zcu) Zcu.UnionLayout {
        const ip = &zcu.intern_pool;
        const union_type = ip.indexToKey(ty.toIntern()).union_type;
        const union_obj = ip.loadUnionType(union_type);
        return zcu.getUnionLayout(union_obj);
    }

    pub fn containerLayout(ty: Type, zcu: *Zcu) std.builtin.Type.ContainerLayout {
        const ip = &zcu.intern_pool;
        return switch (ip.indexToKey(ty.toIntern())) {
            .struct_type => |struct_type| struct_type.layout,
            .anon_struct_type => .Auto,
            .union_type => |union_type| union_type.flagsPtr(ip).layout,
            else => unreachable,
        };
    }

    /// Asserts that the type is an error union.
    pub fn errorUnionPayload(ty: Type, zcu: *Zcu) Type {
        return Type.fromInterned(zcu.intern_pool.indexToKey(ty.toIntern()).error_union_type.payload_type);
    }

    /// Asserts that the type is an error union.
    pub fn errorUnionSet(ty: Type, zcu: *Zcu) Type {
        return Type.fromInterned(zcu.intern_pool.errorUnionSet(ty.toIntern()));
    }

    /// Returns false for unresolved inferred error sets.
    pub fn errorSetIsEmpty(ty: Type, zcu: *Zcu) bool {
        const ip = &zcu.intern_pool;
        return switch (ty.toIntern()) {
            .anyerror_type, .adhoc_inferred_error_set_type => false,
            else => switch (ip.indexToKey(ty.toIntern())) {
                .error_set_type => |error_set_type| error_set_type.names.len == 0,
                .inferred_error_set_type => |i| switch (ip.funcIesResolved(i).*) {
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
    pub fn isAnyError(ty: Type, zcu: *Zcu) bool {
        const ip = &zcu.intern_pool;
        return switch (ty.toIntern()) {
            .anyerror_type => true,
            .adhoc_inferred_error_set_type => false,
            else => switch (zcu.intern_pool.indexToKey(ty.toIntern())) {
                .inferred_error_set_type => |i| ip.funcIesResolved(i).* == .anyerror_type,
                else => false,
            },
        };
    }

    pub fn isError(ty: Type, zcu: *const Zcu) bool {
        return switch (ty.zigTypeTag(zcu)) {
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
                .inferred_error_set_type => |i| switch (ip.funcIesResolved(i).*) {
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
    pub fn errorSetHasField(ty: Type, name: []const u8, zcu: *Zcu) bool {
        const ip = &zcu.intern_pool;
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
    pub fn arrayLen(ty: Type, zcu: *const Zcu) u64 {
        return arrayLenIp(ty, &zcu.intern_pool);
    }

    pub fn arrayLenIp(ty: Type, ip: *const InternPool) u64 {
        return switch (ip.indexToKey(ty.toIntern())) {
            .vector_type => |vector_type| vector_type.len,
            .array_type => |array_type| array_type.len,
            .struct_type => |struct_type| struct_type.field_types.len,
            .anon_struct_type => |tuple| tuple.types.len,

            else => unreachable,
        };
    }

    pub fn arrayLenIncludingSentinel(ty: Type, zcu: *const Zcu) u64 {
        return ty.arrayLen(zcu) + @intFromBool(ty.sentinel(zcu) != null);
    }

    pub fn vectorLen(ty: Type, zcu: *const Zcu) u32 {
        return switch (zcu.intern_pool.indexToKey(ty.toIntern())) {
            .vector_type => |vector_type| vector_type.len,
            .anon_struct_type => |tuple| @intCast(tuple.types.len),
            else => unreachable,
        };
    }

    /// Asserts the type is an array, pointer or vector.
    pub fn sentinel(ty: Type, zcu: *const Zcu) ?Value {
        return switch (zcu.intern_pool.indexToKey(ty.toIntern())) {
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
    pub fn isInt(self: Type, zcu: *const Zcu) bool {
        return self.isSignedInt(zcu) or self.isUnsignedInt(zcu);
    }

    /// Returns true if and only if the type is a fixed-width, signed integer.
    pub fn isSignedInt(ty: Type, zcu: *const Zcu) bool {
        return switch (ty.toIntern()) {
            .c_char_type => zcu.getTarget().charSignedness() == .signed,
            .isize_type, .c_short_type, .c_int_type, .c_long_type, .c_longlong_type => true,
            else => switch (zcu.intern_pool.indexToKey(ty.toIntern())) {
                .int_type => |int_type| int_type.signedness == .signed,
                else => false,
            },
        };
    }

    /// Returns true if and only if the type is a fixed-width, unsigned integer.
    pub fn isUnsignedInt(ty: Type, zcu: *const Zcu) bool {
        return switch (ty.toIntern()) {
            .c_char_type => zcu.getTarget().charSignedness() == .unsigned,
            .usize_type, .c_ushort_type, .c_uint_type, .c_ulong_type, .c_ulonglong_type => true,
            else => switch (zcu.intern_pool.indexToKey(ty.toIntern())) {
                .int_type => |int_type| int_type.signedness == .unsigned,
                else => false,
            },
        };
    }

    /// Returns true for integers, enums, error sets, and packed structs.
    /// If this function returns true, then intInfo() can be called on the type.
    pub fn isAbiInt(ty: Type, zcu: *Zcu) bool {
        return switch (ty.zigTypeTag(zcu)) {
            .Int, .Enum, .ErrorSet => true,
            .Struct => ty.containerLayout(zcu) == .Packed,
            else => false,
        };
    }

    /// Asserts the type is an integer, enum, error set, or vector of one of them.
    pub fn intInfo(starting_ty: Type, zcu: *Zcu) InternPool.Key.IntType {
        const ip = &zcu.intern_pool;
        const target = zcu.getTarget();
        var ty = starting_ty;

        while (true) switch (ty.toIntern()) {
            .anyerror_type, .adhoc_inferred_error_set_type => {
                return .{ .signedness = .unsigned, .bits = zcu.errorSetBits() };
            },
            .usize_type => return .{ .signedness = .unsigned, .bits = target.ptrBitWidth() },
            .isize_type => return .{ .signedness = .signed, .bits = target.ptrBitWidth() },
            .c_char_type => return .{ .signedness = zcu.getTarget().charSignedness(), .bits = target.c_type_bit_size(.char) },
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
                .struct_type => |t| ty = Type.fromInterned(t.backingIntType(ip).*),
                .enum_type => |enum_type| ty = Type.fromInterned(enum_type.tag_ty),
                .vector_type => |vector_type| ty = Type.fromInterned(vector_type.child),

                .error_set_type, .inferred_error_set_type => {
                    return .{ .signedness = .unsigned, .bits = zcu.errorSetBits() };
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
    pub fn fnReturnType(ty: Type, zcu: *Zcu) Type {
        return Type.fromInterned(zcu.intern_pool.funcTypeReturnType(ty.toIntern()));
    }

    /// Asserts the type is a function.
    pub fn fnCallingConvention(ty: Type, zcu: *Zcu) std.builtin.CallingConvention {
        return zcu.intern_pool.indexToKey(ty.toIntern()).func_type.cc;
    }

    pub fn isValidParamType(self: Type, zcu: *const Zcu) bool {
        return switch (self.zigTypeTagOrPoison(zcu) catch return true) {
            .Opaque, .NoReturn => false,
            else => true,
        };
    }

    pub fn isValidReturnType(self: Type, zcu: *const Zcu) bool {
        return switch (self.zigTypeTagOrPoison(zcu) catch return true) {
            .Opaque => false,
            else => true,
        };
    }

    /// Asserts the type is a function.
    pub fn fnIsVarArgs(ty: Type, zcu: *Zcu) bool {
        return zcu.intern_pool.indexToKey(ty.toIntern()).func_type.is_var_args;
    }

    pub fn isNumeric(ty: Type, zcu: *const Zcu) bool {
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

            else => switch (zcu.intern_pool.indexToKey(ty.toIntern())) {
                .int_type => true,
                else => false,
            },
        };
    }

    /// During semantic analysis, instead call `Sema.typeHasOnePossibleValue` which
    /// resolves field types rather than asserting they are already resolved.
    pub fn onePossibleValue(starting_type: Type, zcu: *Zcu) !?Value {
        var ty = starting_type;
        const ip = &zcu.intern_pool;
        while (true) switch (ty.toIntern()) {
            .empty_struct_type => return Value.empty_struct,

            else => switch (ip.indexToKey(ty.toIntern())) {
                .int_type => |int_type| {
                    if (int_type.bits == 0) {
                        return try zcu.intValue(ty, 0);
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
                    if (seq_type.len + @intFromBool(has_sentinel) == 0) return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                        .ty = ty.toIntern(),
                        .storage = .{ .elems = &.{} },
                    } })));
                    if (try Type.fromInterned(seq_type.child).onePossibleValue(zcu)) |opv| {
                        return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                            .ty = ty.toIntern(),
                            .storage = .{ .repeated_elem = opv.toIntern() },
                        } })));
                    }
                    return null;
                },
                .opt_type => |child| {
                    if (child == .noreturn_type) {
                        return try zcu.nullValue(ty);
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
                .struct_type => |struct_type| {
                    assert(struct_type.haveFieldTypes(ip));
                    if (struct_type.knownNonOpv(ip))
                        return null;
                    const field_vals = try zcu.gpa.alloc(InternPool.Index, struct_type.field_types.len);
                    defer zcu.gpa.free(field_vals);
                    for (field_vals, 0..) |*field_val, i_usize| {
                        const i: u32 = @intCast(i_usize);
                        if (struct_type.fieldIsComptime(ip, i)) {
                            assert(struct_type.haveFieldInits(ip));
                            field_val.* = struct_type.field_inits.get(ip)[i];
                            continue;
                        }
                        const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[i]);
                        if (try field_ty.onePossibleValue(zcu)) |field_opv| {
                            field_val.* = try field_opv.intern(field_ty, zcu);
                        } else return null;
                    }

                    // In this case the struct has no runtime-known fields and
                    // therefore has one possible value.
                    return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                        .ty = ty.toIntern(),
                        .storage = .{ .elems = field_vals },
                    } })));
                },

                .anon_struct_type => |tuple| {
                    for (tuple.values.get(ip)) |val| {
                        if (val == .none) return null;
                    }
                    // In this case the struct has all comptime-known fields and
                    // therefore has one possible value.
                    // TODO: write something like getCoercedInts to avoid needing to dupe
                    const duped_values = try zcu.gpa.dupe(InternPool.Index, tuple.values.get(ip));
                    defer zcu.gpa.free(duped_values);
                    return Value.fromInterned((try zcu.intern(.{ .aggregate = .{
                        .ty = ty.toIntern(),
                        .storage = .{ .elems = duped_values },
                    } })));
                },

                .union_type => |union_type| {
                    const union_obj = ip.loadUnionType(union_type);
                    const tag_val = (try Type.fromInterned(union_obj.enum_tag_ty).onePossibleValue(zcu)) orelse
                        return null;
                    if (union_obj.field_names.len == 0) {
                        const only = try zcu.intern(.{ .empty_enum_value = ty.toIntern() });
                        return Value.fromInterned(only);
                    }
                    const only_field_ty = union_obj.field_types.get(ip)[0];
                    const val_val = (try Type.fromInterned(only_field_ty).onePossibleValue(zcu)) orelse
                        return null;
                    const only = try zcu.intern(.{ .un = .{
                        .ty = ty.toIntern(),
                        .tag = tag_val.toIntern(),
                        .val = val_val.toIntern(),
                    } });
                    return Value.fromInterned(only);
                },
                .opaque_type => return null,
                .enum_type => |enum_type| switch (enum_type.tag_mode) {
                    .nonexhaustive => {
                        if (enum_type.tag_ty == .comptime_int_type) return null;

                        if (try Type.fromInterned(enum_type.tag_ty).onePossibleValue(zcu)) |int_opv| {
                            const only = try zcu.intern(.{ .enum_tag = .{
                                .ty = ty.toIntern(),
                                .int = int_opv.toIntern(),
                            } });
                            return Value.fromInterned(only);
                        }

                        return null;
                    },
                    .auto, .explicit => {
                        if (Type.fromInterned(enum_type.tag_ty).hasRuntimeBits(zcu)) return null;

                        switch (enum_type.names.len) {
                            0 => {
                                const only = try zcu.intern(.{ .empty_enum_value = ty.toIntern() });
                                return Value.fromInterned(only);
                            },
                            1 => {
                                if (enum_type.values.len == 0) {
                                    const only = try zcu.intern(.{ .enum_tag = .{
                                        .ty = ty.toIntern(),
                                        .int = try zcu.intern(.{ .int = .{
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
    pub fn comptimeOnly(ty: Type, zcu: *Zcu) bool {
        return ty.comptimeOnlyAdvanced(zcu, null) catch unreachable;
    }

    /// `generic_poison` will return false.
    /// May return false negatives when structs and unions are having their field types resolved.
    /// If `opt_sema` is not provided, asserts that the type is sufficiently resolved.
    pub fn comptimeOnlyAdvanced(ty: Type, zcu: *Zcu, opt_sema: ?*Sema) Zcu.CompileError!bool {
        const ip = &zcu.intern_pool;
        return switch (ty.toIntern()) {
            .empty_struct_type => false,

            else => switch (ip.indexToKey(ty.toIntern())) {
                .int_type => false,
                .ptr_type => |ptr_type| {
                    const child_ty = Type.fromInterned(ptr_type.child);
                    switch (child_ty.zigTypeTag(zcu)) {
                        .Fn => return !try child_ty.fnHasRuntimeBitsAdvanced(zcu, opt_sema),
                        .Opaque => return false,
                        else => return child_ty.comptimeOnlyAdvanced(zcu, opt_sema),
                    }
                },
                .anyframe_type => |child| {
                    if (child == .none) return false;
                    return Type.fromInterned(child).comptimeOnlyAdvanced(zcu, opt_sema);
                },
                .array_type => |array_type| return Type.fromInterned(array_type.child).comptimeOnlyAdvanced(zcu, opt_sema),
                .vector_type => |vector_type| return Type.fromInterned(vector_type.child).comptimeOnlyAdvanced(zcu, opt_sema),
                .opt_type => |child| return Type.fromInterned(child).comptimeOnlyAdvanced(zcu, opt_sema),
                .error_union_type => |error_union_type| return Type.fromInterned(error_union_type.payload_type).comptimeOnlyAdvanced(zcu, opt_sema),

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
                .struct_type => |struct_type| {
                    // packed structs cannot be comptime-only because they have a well-defined
                    // memory layout and every field has a well-defined bit pattern.
                    if (struct_type.layout == .Packed)
                        return false;

                    // A struct with no fields is not comptime-only.
                    return switch (struct_type.flagsPtr(ip).requires_comptime) {
                        .no, .wip => false,
                        .yes => true,
                        .unknown => {
                            // The type is not resolved; assert that we have a Sema.
                            const sema = opt_sema.?;

                            if (struct_type.flagsPtr(ip).field_types_wip)
                                return false;

                            struct_type.flagsPtr(ip).requires_comptime = .wip;
                            errdefer struct_type.flagsPtr(ip).requires_comptime = .unknown;

                            try sema.resolveTypeFieldsStruct(ty.toIntern(), struct_type);

                            for (0..struct_type.field_types.len) |i_usize| {
                                const i: u32 = @intCast(i_usize);
                                if (struct_type.fieldIsComptime(ip, i)) continue;
                                const field_ty = struct_type.field_types.get(ip)[i];
                                if (try Type.fromInterned(field_ty).comptimeOnlyAdvanced(zcu, opt_sema)) {
                                    // Note that this does not cause the layout to
                                    // be considered resolved. Comptime-only types
                                    // still maintain a layout of their
                                    // runtime-known fields.
                                    struct_type.flagsPtr(ip).requires_comptime = .yes;
                                    return true;
                                }
                            }

                            struct_type.flagsPtr(ip).requires_comptime = .no;
                            return false;
                        },
                    };
                },

                .anon_struct_type => |tuple| {
                    for (tuple.types.get(ip), tuple.values.get(ip)) |field_ty, val| {
                        const have_comptime_val = val != .none;
                        if (!have_comptime_val and try Type.fromInterned(field_ty).comptimeOnlyAdvanced(zcu, opt_sema)) return true;
                    }
                    return false;
                },

                .union_type => |union_type| switch (union_type.flagsPtr(ip).requires_comptime) {
                    .no, .wip => false,
                    .yes => true,
                    .unknown => {
                        // The type is not resolved; assert that we have a Sema.
                        const sema = opt_sema.?;

                        if (union_type.flagsPtr(ip).status == .field_types_wip)
                            return false;

                        union_type.flagsPtr(ip).requires_comptime = .wip;
                        errdefer union_type.flagsPtr(ip).requires_comptime = .unknown;

                        try sema.resolveTypeFieldsUnion(ty, union_type);

                        const union_obj = ip.loadUnionType(union_type);
                        for (0..union_obj.field_types.len) |field_idx| {
                            const field_ty = union_obj.field_types.get(ip)[field_idx];
                            if (try Type.fromInterned(field_ty).comptimeOnlyAdvanced(zcu, opt_sema)) {
                                union_obj.flagsPtr(ip).requires_comptime = .yes;
                                return true;
                            }
                        }

                        union_obj.flagsPtr(ip).requires_comptime = .no;
                        return false;
                    },
                },

                .opaque_type => false,

                .enum_type => |enum_type| return Type.fromInterned(enum_type.tag_ty).comptimeOnlyAdvanced(zcu, opt_sema),

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
                .opt,
                .aggregate,
                .un,
                // memoization, not types
                .memoized_call,
                => unreachable,
            },
        };
    }

    pub fn isVector(ty: Type, zcu: *const Zcu) bool {
        return ty.zigTypeTag(zcu) == .Vector;
    }

    pub fn isArrayOrVector(ty: Type, zcu: *const Zcu) bool {
        return switch (ty.zigTypeTag(zcu)) {
            .Array, .Vector => true,
            else => false,
        };
    }

    pub fn isIndexable(ty: Type, zcu: *Zcu) bool {
        return switch (ty.zigTypeTag(zcu)) {
            .Array, .Vector => true,
            .Pointer => switch (ty.ptrSize(zcu)) {
                .Slice, .Many, .C => true,
                .One => switch (ty.childType(zcu).zigTypeTag(zcu)) {
                    .Array, .Vector => true,
                    .Struct => ty.childType(zcu).isTuple(zcu),
                    else => false,
                },
            },
            .Struct => ty.isTuple(zcu),
            else => false,
        };
    }

    pub fn indexableHasLen(ty: Type, zcu: *Zcu) bool {
        return switch (ty.zigTypeTag(zcu)) {
            .Array, .Vector => true,
            .Pointer => switch (ty.ptrSize(zcu)) {
                .Many, .C => false,
                .Slice => true,
                .One => switch (ty.childType(zcu).zigTypeTag(zcu)) {
                    .Array, .Vector => true,
                    .Struct => ty.childType(zcu).isTuple(zcu),
                    else => false,
                },
            },
            .Struct => ty.isTuple(zcu),
            else => false,
        };
    }

    /// Returns null if the type has no namespace.
    pub fn getNamespaceIndex(ty: Type, zcu: *Zcu) InternPool.OptionalNamespaceIndex {
        return switch (zcu.intern_pool.indexToKey(ty.toIntern())) {
            .opaque_type => |opaque_type| opaque_type.namespace.toOptional(),
            .struct_type => |struct_type| struct_type.namespace,
            .union_type => |union_type| union_type.namespace.toOptional(),
            .enum_type => |enum_type| enum_type.namespace,

            else => .none,
        };
    }

    /// Returns null if the type has no namespace.
    pub fn getNamespace(ty: Type, zcu: *Zcu) ?*Zcu.Namespace {
        return if (getNamespaceIndex(ty, zcu).unwrap()) |i| zcu.namespacePtr(i) else null;
    }

    // Works for vectors and vectors of integers.
    pub fn minInt(ty: Type, zcu: *Zcu, dest_ty: Type) !Value {
        const scalar = try minIntScalar(ty.scalarType(zcu), zcu, dest_ty.scalarType(zcu));
        return if (ty.zigTypeTag(zcu) == .Vector) Value.fromInterned((try zcu.intern(.{ .aggregate = .{
            .ty = dest_ty.toIntern(),
            .storage = .{ .repeated_elem = scalar.toIntern() },
        } }))) else scalar;
    }

    /// Asserts that the type is an integer.
    pub fn minIntScalar(ty: Type, zcu: *Zcu, dest_ty: Type) !Value {
        const info = ty.intInfo(zcu);
        if (info.signedness == .unsigned) return zcu.intValue(dest_ty, 0);
        if (info.bits == 0) return zcu.intValue(dest_ty, -1);

        if (std.math.cast(u6, info.bits - 1)) |shift| {
            const n = @as(i64, std.math.minInt(i64)) >> (63 - shift);
            return zcu.intValue(dest_ty, n);
        }

        var res = try std.math.big.int.Managed.init(zcu.gpa);
        defer res.deinit();

        try res.setTwosCompIntLimit(.min, info.signedness, info.bits);

        return zcu.intValue_big(dest_ty, res.toConst());
    }

    // Works for vectors and vectors of integers.
    /// The returned Value will have type dest_ty.
    pub fn maxInt(ty: Type, zcu: *Zcu, dest_ty: Type) !Value {
        const scalar = try maxIntScalar(ty.scalarType(zcu), zcu, dest_ty.scalarType(zcu));
        return if (ty.zigTypeTag(zcu) == .Vector) Value.fromInterned((try zcu.intern(.{ .aggregate = .{
            .ty = dest_ty.toIntern(),
            .storage = .{ .repeated_elem = scalar.toIntern() },
        } }))) else scalar;
    }

    /// The returned Value will have type dest_ty.
    pub fn maxIntScalar(ty: Type, zcu: *Zcu, dest_ty: Type) !Value {
        const info = ty.intInfo(zcu);

        switch (info.bits) {
            0 => return switch (info.signedness) {
                .signed => try zcu.intValue(dest_ty, -1),
                .unsigned => try zcu.intValue(dest_ty, 0),
            },
            1 => return switch (info.signedness) {
                .signed => try zcu.intValue(dest_ty, 0),
                .unsigned => try zcu.intValue(dest_ty, 1),
            },
            else => {},
        }

        if (std.math.cast(u6, info.bits - 1)) |shift| switch (info.signedness) {
            .signed => {
                const n = @as(i64, std.math.maxInt(i64)) >> (63 - shift);
                return zcu.intValue(dest_ty, n);
            },
            .unsigned => {
                const n = @as(u64, std.math.maxInt(u64)) >> (63 - shift);
                return zcu.intValue(dest_ty, n);
            },
        };

        var res = try std.math.big.int.Managed.init(zcu.gpa);
        defer res.deinit();

        try res.setTwosCompIntLimit(.max, info.signedness, info.bits);

        return zcu.intValue_big(dest_ty, res.toConst());
    }

    /// Asserts the type is an enum or a union.
    pub fn intTagType(ty: Type, zcu: *Zcu) Type {
        return switch (zcu.intern_pool.indexToKey(ty.toIntern())) {
            .union_type => |union_type| Type.fromInterned(union_type.enum_tag_ty).intTagType(zcu),
            .enum_type => |enum_type| Type.fromInterned(enum_type.tag_ty),
            else => unreachable,
        };
    }

    pub fn isNonexhaustiveEnum(ty: Type, zcu: *Zcu) bool {
        return switch (zcu.intern_pool.indexToKey(ty.toIntern())) {
            .enum_type => |enum_type| switch (enum_type.tag_mode) {
                .nonexhaustive => true,
                .auto, .explicit => false,
            },
            else => false,
        };
    }

    // Asserts that `ty` is an error set and not `anyerror`.
    // Asserts that `ty` is resolved if it is an inferred error set.
    pub fn errorSetNames(ty: Type, zcu: *Zcu) []const InternPool.NullTerminatedString {
        const ip = &zcu.intern_pool;
        return switch (ip.indexToKey(ty.toIntern())) {
            .error_set_type => |x| x.names.get(ip),
            .inferred_error_set_type => |i| switch (ip.funcIesResolved(i).*) {
                .none => unreachable, // unresolved inferred error set
                .anyerror_type => unreachable,
                else => |t| ip.indexToKey(t).error_set_type.names.get(ip),
            },
            else => unreachable,
        };
    }

    pub fn enumFields(ty: Type, zcu: *Zcu) []const InternPool.NullTerminatedString {
        const ip = &zcu.intern_pool;
        return ip.indexToKey(ty.toIntern()).enum_type.names.get(ip);
    }

    pub fn enumFieldCount(ty: Type, zcu: *Zcu) usize {
        return zcu.intern_pool.indexToKey(ty.toIntern()).enum_type.names.len;
    }

    pub fn enumFieldName(ty: Type, field_index: usize, zcu: *Zcu) InternPool.NullTerminatedString {
        const ip = &zcu.intern_pool;
        return ip.indexToKey(ty.toIntern()).enum_type.names.get(ip)[field_index];
    }

    pub fn enumFieldIndex(ty: Type, field_name: InternPool.NullTerminatedString, zcu: *Zcu) ?u32 {
        const ip = &zcu.intern_pool;
        const enum_type = ip.indexToKey(ty.toIntern()).enum_type;
        return enum_type.nameIndex(ip, field_name);
    }

    /// Asserts `ty` is an enum. `enum_tag` can either be `enum_field_index` or
    /// an integer which represents the enum value. Returns the field index in
    /// declaration order, or `null` if `enum_tag` does not match any field.
    pub fn enumTagFieldIndex(ty: Type, enum_tag: Value, zcu: *Zcu) ?u32 {
        const ip = &zcu.intern_pool;
        const enum_type = ip.indexToKey(ty.toIntern()).enum_type;
        const int_tag = switch (ip.indexToKey(enum_tag.toIntern())) {
            .int => enum_tag.toIntern(),
            .enum_tag => |info| info.int,
            else => unreachable,
        };
        assert(ip.typeOf(int_tag) == enum_type.tag_ty);
        return enum_type.tagValueIndex(ip, int_tag);
    }

    /// Returns none in the case of a tuple which uses the integer index as the field name.
    pub fn structFieldName(ty: Type, field_index: u32, zcu: *Zcu) InternPool.OptionalNullTerminatedString {
        const ip = &zcu.intern_pool;
        return switch (ip.indexToKey(ty.toIntern())) {
            .struct_type => |struct_type| struct_type.fieldName(ip, field_index),
            .anon_struct_type => |anon_struct| anon_struct.fieldName(ip, field_index),
            else => unreachable,
        };
    }

    /// When struct types have no field names, the names are implicitly understood to be
    /// strings corresponding to the field indexes in declaration order. It used to be the
    /// case that a NullTerminatedString would be stored for each field in this case, however,
    /// now, callers must handle the possibility that there are no names stored at all.
    /// Here we fake the previous behavior. Probably something better could be done by examining
    /// all the callsites of this function.
    pub fn legacyStructFieldName(ty: Type, i: u32, zcu: *Zcu) InternPool.NullTerminatedString {
        return ty.structFieldName(i, zcu).unwrap() orelse
            zcu.intern_pool.getOrPutStringFmt(zcu.gpa, "{d}", .{i}) catch @panic("OOM");
    }

    pub fn structFieldCount(ty: Type, zcu: *Zcu) u32 {
        const ip = &zcu.intern_pool;
        return switch (ip.indexToKey(ty.toIntern())) {
            .struct_type => |struct_type| struct_type.field_types.len,
            .anon_struct_type => |anon_struct| anon_struct.types.len,
            else => unreachable,
        };
    }

    /// Supports structs and unions.
    pub fn structFieldType(ty: Type, index: usize, zcu: *Zcu) Type {
        const ip = &zcu.intern_pool;
        return switch (ip.indexToKey(ty.toIntern())) {
            .struct_type => |struct_type| Type.fromInterned(struct_type.field_types.get(ip)[index]),
            .union_type => |union_type| {
                const union_obj = ip.loadUnionType(union_type);
                return Type.fromInterned(union_obj.field_types.get(ip)[index]);
            },
            .anon_struct_type => |anon_struct| Type.fromInterned(anon_struct.types.get(ip)[index]),
            else => unreachable,
        };
    }

    pub fn structFieldAlign(ty: Type, index: usize, zcu: *Zcu) Alignment {
        const ip = &zcu.intern_pool;
        switch (ip.indexToKey(ty.toIntern())) {
            .struct_type => |struct_type| {
                assert(struct_type.layout != .Packed);
                const explicit_align = struct_type.fieldAlign(ip, index);
                const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[index]);
                return zcu.structFieldAlignment(explicit_align, field_ty, struct_type.layout);
            },
            .anon_struct_type => |anon_struct| {
                return Type.fromInterned(anon_struct.types.get(ip)[index]).abiAlignment(zcu);
            },
            .union_type => |union_type| {
                const union_obj = ip.loadUnionType(union_type);
                return zcu.unionFieldNormalAlignment(union_obj, @intCast(index));
            },
            else => unreachable,
        }
    }

    pub fn structFieldDefaultValue(ty: Type, index: usize, zcu: *Zcu) Value {
        const ip = &zcu.intern_pool;
        switch (ip.indexToKey(ty.toIntern())) {
            .struct_type => |struct_type| {
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

    pub fn structFieldValueComptime(ty: Type, zcu: *Zcu, index: usize) !?Value {
        const ip = &zcu.intern_pool;
        switch (ip.indexToKey(ty.toIntern())) {
            .struct_type => |struct_type| {
                assert(struct_type.haveFieldInits(ip));
                if (struct_type.fieldIsComptime(ip, index)) {
                    return Value.fromInterned(struct_type.field_inits.get(ip)[index]);
                } else {
                    return Type.fromInterned(struct_type.field_types.get(ip)[index]).onePossibleValue(zcu);
                }
            },
            .anon_struct_type => |tuple| {
                const val = tuple.values.get(ip)[index];
                if (val == .none) {
                    return Type.fromInterned(tuple.types.get(ip)[index]).onePossibleValue(zcu);
                } else {
                    return Value.fromInterned(val);
                }
            },
            else => unreachable,
        }
    }

    pub fn structFieldIsComptime(ty: Type, index: usize, zcu: *Zcu) bool {
        const ip = &zcu.intern_pool;
        return switch (ip.indexToKey(ty.toIntern())) {
            .struct_type => |struct_type| struct_type.fieldIsComptime(ip, index),
            .anon_struct_type => |anon_struct| anon_struct.values.get(ip)[index] != .none,
            else => unreachable,
        };
    }

    pub const FieldOffset = struct {
        field: usize,
        offset: u64,
    };

    /// Supports structs and unions.
    pub fn structFieldOffset(ty: Type, index: usize, zcu: *Zcu) u64 {
        const ip = &zcu.intern_pool;
        switch (ip.indexToKey(ty.toIntern())) {
            .struct_type => |struct_type| {
                assert(struct_type.haveLayout(ip));
                assert(struct_type.layout != .Packed);
                return struct_type.offsets.get(ip)[index];
            },

            .anon_struct_type => |tuple| {
                var offset: u64 = 0;
                var big_align: Alignment = .none;

                for (tuple.types.get(ip), tuple.values.get(ip), 0..) |field_ty, field_val, i| {
                    if (field_val != .none or !Type.fromInterned(field_ty).hasRuntimeBits(zcu)) {
                        // comptime field
                        if (i == index) return offset;
                        continue;
                    }

                    const field_align = Type.fromInterned(field_ty).abiAlignment(zcu);
                    big_align = big_align.max(field_align);
                    offset = field_align.forward(offset);
                    if (i == index) return offset;
                    offset += Type.fromInterned(field_ty).abiSize(zcu);
                }
                offset = big_align.max(.@"1").forward(offset);
                return offset;
            },

            .union_type => |union_type| {
                if (!union_type.hasTag(ip))
                    return 0;
                const union_obj = ip.loadUnionType(union_type);
                const layout = zcu.getUnionLayout(union_obj);
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

    pub fn declSrcLoc(ty: Type, zcu: *Zcu) Zcu.SrcLoc {
        return declSrcLocOrNull(ty, zcu).?;
    }

    pub fn declSrcLocOrNull(ty: Type, zcu: *Zcu) ?Zcu.SrcLoc {
        return switch (zcu.intern_pool.indexToKey(ty.toIntern())) {
            .struct_type => |struct_type| {
                return zcu.declPtr(struct_type.decl.unwrap() orelse return null).srcLoc(zcu);
            },
            .union_type => |union_type| {
                return zcu.declPtr(union_type.decl).srcLoc(zcu);
            },
            .opaque_type => |opaque_type| zcu.opaqueSrcLoc(opaque_type),
            .enum_type => |enum_type| zcu.declPtr(enum_type.decl).srcLoc(zcu),
            else => null,
        };
    }

    pub fn getOwnerDecl(ty: Type, zcu: *Zcu) InternPool.DeclIndex {
        return ty.getOwnerDeclOrNull(zcu) orelse unreachable;
    }

    pub fn getOwnerDeclOrNull(ty: Type, zcu: *Zcu) ?InternPool.DeclIndex {
        return switch (zcu.intern_pool.indexToKey(ty.toIntern())) {
            .struct_type => |struct_type| struct_type.decl.unwrap(),
            .union_type => |union_type| union_type.decl,
            .opaque_type => |opaque_type| opaque_type.decl,
            .enum_type => |enum_type| enum_type.decl,
            else => null,
        };
    }

    pub fn isGenericPoison(ty: Type) bool {
        return ty.toIntern() == .generic_poison_type;
    }

    pub fn isTuple(ty: Type, zcu: *Zcu) bool {
        const ip = &zcu.intern_pool;
        return switch (ip.indexToKey(ty.toIntern())) {
            .struct_type => |struct_type| {
                if (struct_type.layout == .Packed) return false;
                if (struct_type.decl == .none) return false;
                return struct_type.flagsPtr(ip).is_tuple;
            },
            .anon_struct_type => |anon_struct| anon_struct.names.len == 0,
            else => false,
        };
    }

    pub fn isAnonStruct(ty: Type, zcu: *Zcu) bool {
        if (ty.toIntern() == .empty_struct_type) return true;
        return switch (zcu.intern_pool.indexToKey(ty.toIntern())) {
            .anon_struct_type => |anon_struct_type| anon_struct_type.names.len > 0,
            else => false,
        };
    }

    pub fn isTupleOrAnonStruct(ty: Type, zcu: *Zcu) bool {
        const ip = &zcu.intern_pool;
        return switch (ip.indexToKey(ty.toIntern())) {
            .struct_type => |struct_type| {
                if (struct_type.layout == .Packed) return false;
                if (struct_type.decl == .none) return false;
                return struct_type.flagsPtr(ip).is_tuple;
            },
            .anon_struct_type => true,
            else => false,
        };
    }

    pub fn isSimpleTuple(ty: Type, zcu: *Zcu) bool {
        return switch (zcu.intern_pool.indexToKey(ty.toIntern())) {
            .anon_struct_type => |anon_struct_type| anon_struct_type.names.len == 0,
            else => false,
        };
    }

    pub fn isSimpleTupleOrAnonStruct(ty: Type, zcu: *Zcu) bool {
        return switch (zcu.intern_pool.indexToKey(ty.toIntern())) {
            .anon_struct_type => true,
            else => false,
        };
    }

    /// Traverses optional child types and error union payloads until the type
    /// is not a pointer. For `E!?u32`, returns `u32`; for `*u8`, returns `*u8`.
    pub fn optEuBaseType(ty: Type, zcu: *Zcu) Type {
        var cur = ty;
        while (true) switch (cur.zigTypeTag(zcu)) {
            .Optional => cur = cur.optionalChild(zcu),
            .ErrorUnion => cur = cur.errorUnionPayload(zcu),
            else => return cur,
        };
    }

    pub fn toUnsigned(ty: Type, zcu: *Zcu) !Type {
        return switch (ty.zigTypeTag(zcu)) {
            .Int => zcu.intType(.unsigned, ty.intInfo(zcu).bits),
            .Vector => try zcu.vectorType(.{
                .len = ty.vectorLen(zcu),
                .child = (try ty.childType(zcu).toUnsigned(zcu)).toIntern(),
            }),
            else => unreachable,
        };
    }

    pub const @"u1": Type = .{ .ip_index = .u1_type };
    pub const @"u8": Type = .{ .ip_index = .u8_type };
    pub const @"u16": Type = .{ .ip_index = .u16_type };
    pub const @"u29": Type = .{ .ip_index = .u29_type };
    pub const @"u32": Type = .{ .ip_index = .u32_type };
    pub const @"u64": Type = .{ .ip_index = .u64_type };
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
};

fn cTypeAlign(target: Target, c_type: Target.CType) Alignment {
    return Alignment.fromByteUnits(target.c_type_alignment(c_type));
}
