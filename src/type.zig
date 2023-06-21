const std = @import("std");
const builtin = @import("builtin");
const Value = @import("value.zig").Value;
const assert = std.debug.assert;
const Target = std.Target;
const Module = @import("Module.zig");
const log = std.log.scoped(.Type);
const target_util = @import("target.zig");
const TypedValue = @import("TypedValue.zig");
const Sema = @import("Sema.zig");
const InternPool = @import("InternPool.zig");

/// Both types and values are canonically represented by a single 32-bit integer
/// which is an index into an `InternPool` data structure.
/// This struct abstracts around this storage by providing methods only
/// applicable to types rather than values in general.
pub const Type = struct {
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

    pub fn hash(ty: Type, mod: *const Module) u32 {
        _ = mod; // TODO: remove this parameter
        // The InternPool data structure hashes based on Key to make interned objects
        // unique. An Index can be treated simply as u32 value for the
        // purpose of Type/Value hashing and equality.
        return std.hash.uint32(@intFromEnum(ty.toIntern()));
    }

    pub fn format(ty: Type, comptime unused_fmt_string: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = ty;
        _ = unused_fmt_string;
        _ = options;
        _ = writer;
        @compileError("do not format types directly; use either ty.fmtDebug() or ty.fmt()");
    }

    pub fn fmt(ty: Type, module: *Module) std.fmt.Formatter(format2) {
        return .{ .data = .{
            .ty = ty,
            .module = module,
        } };
    }

    const FormatContext = struct {
        ty: Type,
        module: *Module,
    };

    fn format2(
        ctx: FormatContext,
        comptime unused_format_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        comptime assert(unused_format_string.len == 0);
        _ = options;
        return print(ctx.ty, writer, ctx.module);
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
    pub fn print(ty: Type, writer: anytype, mod: *Module) @TypeOf(writer).Error!void {
        switch (mod.intern_pool.indexToKey(ty.toIntern())) {
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
                    .Many => try writer.print("[*:{}]", .{info.sentinel.toValue().fmtValue(info.child.toType(), mod)}),
                    .Slice => try writer.print("[:{}]", .{info.sentinel.toValue().fmtValue(info.child.toType(), mod)}),
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
                    const alignment = info.flags.alignment.toByteUnitsOptional() orelse
                        info.child.toType().abiAlignment(mod);
                    try writer.print("align({d}", .{alignment});

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

                try print(info.child.toType(), writer, mod);
                return;
            },
            .array_type => |array_type| {
                if (array_type.sentinel == .none) {
                    try writer.print("[{d}]", .{array_type.len});
                    try print(array_type.child.toType(), writer, mod);
                } else {
                    try writer.print("[{d}:{}]", .{
                        array_type.len,
                        array_type.sentinel.toValue().fmtValue(array_type.child.toType(), mod),
                    });
                    try print(array_type.child.toType(), writer, mod);
                }
                return;
            },
            .vector_type => |vector_type| {
                try writer.print("@Vector({d}, ", .{vector_type.len});
                try print(vector_type.child.toType(), writer, mod);
                try writer.writeAll(")");
                return;
            },
            .opt_type => |child| {
                try writer.writeByte('?');
                return print(child.toType(), writer, mod);
            },
            .error_union_type => |error_union_type| {
                try print(error_union_type.error_set_type.toType(), writer, mod);
                try writer.writeByte('!');
                try print(error_union_type.payload_type.toType(), writer, mod);
                return;
            },
            .inferred_error_set_type => |index| {
                const ies = mod.inferredErrorSetPtr(index);
                const func = ies.func;

                try writer.writeAll("@typeInfo(@typeInfo(@TypeOf(");
                const owner_decl = mod.declPtr(mod.funcPtr(func).owner_decl);
                try owner_decl.renderFullyQualifiedName(mod, writer);
                try writer.writeAll(")).Fn.return_type.?).ErrorUnion.error_set");
            },
            .error_set_type => |error_set_type| {
                const names = error_set_type.names;
                try writer.writeAll("error{");
                for (names, 0..) |name, i| {
                    if (i != 0) try writer.writeByte(',');
                    try writer.print("{}", .{name.fmt(&mod.intern_pool)});
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
                if (mod.structPtrUnwrap(struct_type.index)) |struct_obj| {
                    const decl = mod.declPtr(struct_obj.owner_decl);
                    try decl.renderFullyQualifiedName(mod, writer);
                } else if (struct_type.namespace.unwrap()) |namespace_index| {
                    const namespace = mod.namespacePtr(namespace_index);
                    try namespace.renderFullyQualifiedName(mod, .empty, writer);
                } else {
                    try writer.writeAll("@TypeOf(.{})");
                }
            },
            .anon_struct_type => |anon_struct| {
                if (anon_struct.types.len == 0) {
                    return writer.writeAll("@TypeOf(.{})");
                }
                try writer.writeAll("struct{");
                for (anon_struct.types, anon_struct.values, 0..) |field_ty, val, i| {
                    if (i != 0) try writer.writeAll(", ");
                    if (val != .none) {
                        try writer.writeAll("comptime ");
                    }
                    if (anon_struct.names.len != 0) {
                        try writer.print("{}: ", .{anon_struct.names[i].fmt(&mod.intern_pool)});
                    }

                    try print(field_ty.toType(), writer, mod);

                    if (val != .none) {
                        try writer.print(" = {}", .{val.toValue().fmtValue(field_ty.toType(), mod)});
                    }
                }
                try writer.writeAll("}");
            },

            .union_type => |union_type| {
                const union_obj = mod.unionPtr(union_type.index);
                const decl = mod.declPtr(union_obj.owner_decl);
                try decl.renderFullyQualifiedName(mod, writer);
            },
            .opaque_type => |opaque_type| {
                const decl = mod.declPtr(opaque_type.decl);
                try decl.renderFullyQualifiedName(mod, writer);
            },
            .enum_type => |enum_type| {
                const decl = mod.declPtr(enum_type.decl);
                try decl.renderFullyQualifiedName(mod, writer);
            },
            .func_type => |fn_info| {
                if (fn_info.is_noinline) {
                    try writer.writeAll("noinline ");
                }
                try writer.writeAll("fn(");
                for (fn_info.param_types, 0..) |param_ty, i| {
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
                        try print(param_ty.toType(), writer, mod);
                    }
                }
                if (fn_info.is_var_args) {
                    if (fn_info.param_types.len != 0) {
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
                    try print(fn_info.return_type.toType(), writer, mod);
                }
            },
            .anyframe_type => |child| {
                if (child == .none) return writer.writeAll("anyframe");
                try writer.writeAll("anyframe->");
                return print(child.toType(), writer, mod);
            },

            // values, not types
            .undef,
            .runtime_value,
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

    pub fn toIntern(ty: Type) InternPool.Index {
        assert(ty.ip_index != .none);
        return ty.ip_index;
    }

    pub fn toValue(self: Type) Value {
        return self.toIntern().toValue();
    }

    const RuntimeBitsError = Module.CompileError || error{NeedLazy};

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
        mod: *Module,
        ignore_comptime_only: bool,
        strat: AbiAlignmentAdvancedStrat,
    ) RuntimeBitsError!bool {
        return switch (ty.toIntern()) {
            // False because it is a comptime-only type.
            .empty_struct_type => false,
            else => switch (mod.intern_pool.indexToKey(ty.toIntern())) {
                .int_type => |int_type| int_type.bits != 0,
                .ptr_type => |ptr_type| {
                    // Pointers to zero-bit types still have a runtime address; however, pointers
                    // to comptime-only types do not, with the exception of function pointers.
                    if (ignore_comptime_only) return true;
                    const child_ty = ptr_type.child.toType();
                    if (child_ty.zigTypeTag(mod) == .Fn) return !mod.typeToFunc(child_ty).?.is_generic;
                    if (strat == .sema) return !(try strat.sema.typeRequiresComptime(ty));
                    return !comptimeOnly(ty, mod);
                },
                .anyframe_type => true,
                .array_type => |array_type| {
                    if (array_type.sentinel != .none) {
                        return array_type.child.toType().hasRuntimeBitsAdvanced(mod, ignore_comptime_only, strat);
                    } else {
                        return array_type.len > 0 and
                            try array_type.child.toType().hasRuntimeBitsAdvanced(mod, ignore_comptime_only, strat);
                    }
                },
                .vector_type => |vector_type| {
                    return vector_type.len > 0 and
                        try vector_type.child.toType().hasRuntimeBitsAdvanced(mod, ignore_comptime_only, strat);
                },
                .opt_type => |child| {
                    const child_ty = child.toType();
                    if (child_ty.isNoReturn(mod)) {
                        // Then the optional is comptime-known to be null.
                        return false;
                    }
                    if (ignore_comptime_only) {
                        return true;
                    } else if (strat == .sema) {
                        return !(try strat.sema.typeRequiresComptime(child_ty));
                    } else {
                        return !comptimeOnly(child_ty, mod);
                    }
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
                    const struct_obj = mod.structPtrUnwrap(struct_type.index) orelse {
                        // This struct has no fields.
                        return false;
                    };
                    if (struct_obj.status == .field_types_wip) {
                        // In this case, we guess that hasRuntimeBits() for this type is true,
                        // and then later if our guess was incorrect, we emit a compile error.
                        struct_obj.assumed_runtime_bits = true;
                        return true;
                    }
                    switch (strat) {
                        .sema => |sema| _ = try sema.resolveTypeFields(ty),
                        .eager => assert(struct_obj.haveFieldTypes()),
                        .lazy => if (!struct_obj.haveFieldTypes()) return error.NeedLazy,
                    }
                    for (struct_obj.fields.values()) |field| {
                        if (field.is_comptime) continue;
                        if (try field.ty.hasRuntimeBitsAdvanced(mod, ignore_comptime_only, strat))
                            return true;
                    } else {
                        return false;
                    }
                },
                .anon_struct_type => |tuple| {
                    for (tuple.types, tuple.values) |field_ty, val| {
                        if (val != .none) continue; // comptime field
                        if (try field_ty.toType().hasRuntimeBitsAdvanced(mod, ignore_comptime_only, strat)) return true;
                    }
                    return false;
                },

                .union_type => |union_type| {
                    const union_obj = mod.unionPtr(union_type.index);
                    switch (union_type.runtime_tag) {
                        .none => {
                            if (union_obj.status == .field_types_wip) {
                                // In this case, we guess that hasRuntimeBits() for this type is true,
                                // and then later if our guess was incorrect, we emit a compile error.
                                union_obj.assumed_runtime_bits = true;
                                return true;
                            }
                        },
                        .safety, .tagged => {
                            if (try union_obj.tag_ty.hasRuntimeBitsAdvanced(mod, ignore_comptime_only, strat)) {
                                return true;
                            }
                        },
                    }
                    switch (strat) {
                        .sema => |sema| _ = try sema.resolveTypeFields(ty),
                        .eager => assert(union_obj.haveFieldTypes()),
                        .lazy => if (!union_obj.haveFieldTypes()) return error.NeedLazy,
                    }
                    for (union_obj.fields.values()) |value| {
                        if (try value.ty.hasRuntimeBitsAdvanced(mod, ignore_comptime_only, strat))
                            return true;
                    } else {
                        return false;
                    }
                },

                .opaque_type => true,
                .enum_type => |enum_type| enum_type.tag_ty.toType().hasRuntimeBitsAdvanced(mod, ignore_comptime_only, strat),

                // values, not types
                .undef,
                .runtime_value,
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
    pub fn hasWellDefinedLayout(ty: Type, mod: *Module) bool {
        return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
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

            .array_type => |array_type| array_type.child.toType().hasWellDefinedLayout(mod),
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
                const struct_obj = mod.structPtrUnwrap(struct_type.index) orelse {
                    // Struct with no fields has a well-defined layout of no bits.
                    return true;
                };
                return struct_obj.layout != .Auto;
            },
            .union_type => |union_type| switch (union_type.runtime_tag) {
                .none, .safety => mod.unionPtr(union_type.index).layout != .Auto,
                .tagged => false,
            },
            .enum_type => |enum_type| switch (enum_type.tag_mode) {
                .auto => false,
                .explicit, .nonexhaustive => true,
            },

            // values, not types
            .undef,
            .runtime_value,
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

    pub fn hasRuntimeBits(ty: Type, mod: *Module) bool {
        return hasRuntimeBitsAdvanced(ty, mod, false, .eager) catch unreachable;
    }

    pub fn hasRuntimeBitsIgnoreComptime(ty: Type, mod: *Module) bool {
        return hasRuntimeBitsAdvanced(ty, mod, true, .eager) catch unreachable;
    }

    pub fn isFnOrHasRuntimeBits(ty: Type, mod: *Module) bool {
        switch (ty.zigTypeTag(mod)) {
            .Fn => {
                const fn_info = mod.typeToFunc(ty).?;
                if (fn_info.is_generic) return false;
                if (fn_info.is_var_args) return true;
                switch (fn_info.cc) {
                    // If there was a comptime calling convention,
                    // it should also return false here.
                    .Inline => return false,
                    else => {},
                }
                if (fn_info.return_type.toType().comptimeOnly(mod)) return false;
                return true;
            },
            else => return ty.hasRuntimeBits(mod),
        }
    }

    /// Same as `isFnOrHasRuntimeBits` but comptime-only types may return a false positive.
    pub fn isFnOrHasRuntimeBitsIgnoreComptime(ty: Type, mod: *Module) bool {
        return switch (ty.zigTypeTag(mod)) {
            .Fn => true,
            else => return ty.hasRuntimeBitsIgnoreComptime(mod),
        };
    }

    pub fn isNoReturn(ty: Type, mod: *Module) bool {
        return mod.intern_pool.isNoReturn(ty.toIntern());
    }

    /// Returns 0 if the pointer is naturally aligned and the element type is 0-bit.
    pub fn ptrAlignment(ty: Type, mod: *Module) u32 {
        return ptrAlignmentAdvanced(ty, mod, null) catch unreachable;
    }

    pub fn ptrAlignmentAdvanced(ty: Type, mod: *Module, opt_sema: ?*Sema) !u32 {
        return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
            .ptr_type => |ptr_type| {
                if (ptr_type.flags.alignment.toByteUnitsOptional()) |a| {
                    return @intCast(u32, a);
                } else if (opt_sema) |sema| {
                    const res = try ptr_type.child.toType().abiAlignmentAdvanced(mod, .{ .sema = sema });
                    return res.scalar;
                } else {
                    return (ptr_type.child.toType().abiAlignmentAdvanced(mod, .eager) catch unreachable).scalar;
                }
            },
            .opt_type => |child| child.toType().ptrAlignmentAdvanced(mod, opt_sema),
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

    /// Returns 0 for 0-bit types.
    pub fn abiAlignment(ty: Type, mod: *Module) u32 {
        return (ty.abiAlignmentAdvanced(mod, .eager) catch unreachable).scalar;
    }

    /// May capture a reference to `ty`.
    /// Returned value has type `comptime_int`.
    pub fn lazyAbiAlignment(ty: Type, mod: *Module) !Value {
        switch (try ty.abiAlignmentAdvanced(mod, .lazy)) {
            .val => |val| return val,
            .scalar => |x| return mod.intValue(Type.comptime_int, x),
        }
    }

    pub const AbiAlignmentAdvanced = union(enum) {
        scalar: u32,
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
        mod: *Module,
        strat: AbiAlignmentAdvancedStrat,
    ) Module.CompileError!AbiAlignmentAdvanced {
        const target = mod.getTarget();

        const opt_sema = switch (strat) {
            .sema => |sema| sema,
            else => null,
        };

        switch (ty.toIntern()) {
            .empty_struct_type => return AbiAlignmentAdvanced{ .scalar = 0 },
            else => switch (mod.intern_pool.indexToKey(ty.toIntern())) {
                .int_type => |int_type| {
                    if (int_type.bits == 0) return AbiAlignmentAdvanced{ .scalar = 0 };
                    return AbiAlignmentAdvanced{ .scalar = intAbiAlignment(int_type.bits, target) };
                },
                .ptr_type, .anyframe_type => {
                    return AbiAlignmentAdvanced{ .scalar = @divExact(target.ptrBitWidth(), 8) };
                },
                .array_type => |array_type| {
                    return array_type.child.toType().abiAlignmentAdvanced(mod, strat);
                },
                .vector_type => |vector_type| {
                    const bits_u64 = try bitSizeAdvanced(vector_type.child.toType(), mod, opt_sema);
                    const bits = @intCast(u32, bits_u64);
                    const bytes = ((bits * vector_type.len) + 7) / 8;
                    const alignment = std.math.ceilPowerOfTwoAssert(u32, bytes);
                    return AbiAlignmentAdvanced{ .scalar = alignment };
                },

                .opt_type => return abiAlignmentAdvancedOptional(ty, mod, strat),
                .error_union_type => |info| return abiAlignmentAdvancedErrorUnion(ty, mod, strat, info.payload_type.toType()),

                // TODO revisit this when we have the concept of the error tag type
                .error_set_type, .inferred_error_set_type => return AbiAlignmentAdvanced{ .scalar = 2 },

                // represents machine code; not a pointer
                .func_type => |func_type| return AbiAlignmentAdvanced{
                    .scalar = if (func_type.alignment.toByteUnitsOptional()) |a|
                        @intCast(u32, a)
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
                    => return AbiAlignmentAdvanced{ .scalar = 1 },

                    .usize,
                    .isize,
                    .export_options,
                    .extern_options,
                    => return AbiAlignmentAdvanced{ .scalar = @divExact(target.ptrBitWidth(), 8) },

                    .c_char => return AbiAlignmentAdvanced{ .scalar = target.c_type_alignment(.char) },
                    .c_short => return AbiAlignmentAdvanced{ .scalar = target.c_type_alignment(.short) },
                    .c_ushort => return AbiAlignmentAdvanced{ .scalar = target.c_type_alignment(.ushort) },
                    .c_int => return AbiAlignmentAdvanced{ .scalar = target.c_type_alignment(.int) },
                    .c_uint => return AbiAlignmentAdvanced{ .scalar = target.c_type_alignment(.uint) },
                    .c_long => return AbiAlignmentAdvanced{ .scalar = target.c_type_alignment(.long) },
                    .c_ulong => return AbiAlignmentAdvanced{ .scalar = target.c_type_alignment(.ulong) },
                    .c_longlong => return AbiAlignmentAdvanced{ .scalar = target.c_type_alignment(.longlong) },
                    .c_ulonglong => return AbiAlignmentAdvanced{ .scalar = target.c_type_alignment(.ulonglong) },
                    .c_longdouble => return AbiAlignmentAdvanced{ .scalar = target.c_type_alignment(.longdouble) },

                    .f16 => return AbiAlignmentAdvanced{ .scalar = 2 },
                    .f32 => return AbiAlignmentAdvanced{ .scalar = target.c_type_alignment(.float) },
                    .f64 => switch (target.c_type_bit_size(.double)) {
                        64 => return AbiAlignmentAdvanced{ .scalar = target.c_type_alignment(.double) },
                        else => return AbiAlignmentAdvanced{ .scalar = 8 },
                    },
                    .f80 => switch (target.c_type_bit_size(.longdouble)) {
                        80 => return AbiAlignmentAdvanced{ .scalar = target.c_type_alignment(.longdouble) },
                        else => {
                            const u80_ty: Type = .{ .ip_index = .u80_type };
                            return AbiAlignmentAdvanced{ .scalar = abiAlignment(u80_ty, mod) };
                        },
                    },
                    .f128 => switch (target.c_type_bit_size(.longdouble)) {
                        128 => return AbiAlignmentAdvanced{ .scalar = target.c_type_alignment(.longdouble) },
                        else => return AbiAlignmentAdvanced{ .scalar = 16 },
                    },

                    // TODO revisit this when we have the concept of the error tag type
                    .anyerror => return AbiAlignmentAdvanced{ .scalar = 2 },

                    .void,
                    .type,
                    .comptime_int,
                    .comptime_float,
                    .null,
                    .undefined,
                    .enum_literal,
                    .type_info,
                    => return AbiAlignmentAdvanced{ .scalar = 0 },

                    .noreturn => unreachable,
                    .generic_poison => unreachable,
                },
                .struct_type => |struct_type| {
                    const struct_obj = mod.structPtrUnwrap(struct_type.index) orelse
                        return AbiAlignmentAdvanced{ .scalar = 0 };

                    if (opt_sema) |sema| {
                        if (struct_obj.status == .field_types_wip) {
                            // We'll guess "pointer-aligned", if the struct has an
                            // underaligned pointer field then some allocations
                            // might require explicit alignment.
                            return AbiAlignmentAdvanced{ .scalar = @divExact(target.ptrBitWidth(), 8) };
                        }
                        _ = try sema.resolveTypeFields(ty);
                    }
                    if (!struct_obj.haveFieldTypes()) switch (strat) {
                        .eager => unreachable, // struct layout not resolved
                        .sema => unreachable, // handled above
                        .lazy => return .{ .val = (try mod.intern(.{ .int = .{
                            .ty = .comptime_int_type,
                            .storage = .{ .lazy_align = ty.toIntern() },
                        } })).toValue() },
                    };
                    if (struct_obj.layout == .Packed) {
                        switch (strat) {
                            .sema => |sema| try sema.resolveTypeLayout(ty),
                            .lazy => if (!struct_obj.haveLayout()) return .{ .val = (try mod.intern(.{ .int = .{
                                .ty = .comptime_int_type,
                                .storage = .{ .lazy_align = ty.toIntern() },
                            } })).toValue() },
                            .eager => {},
                        }
                        assert(struct_obj.haveLayout());
                        return AbiAlignmentAdvanced{ .scalar = struct_obj.backing_int_ty.abiAlignment(mod) };
                    }

                    const fields = ty.structFields(mod);
                    var big_align: u32 = 0;
                    for (fields.values()) |field| {
                        if (!(field.ty.hasRuntimeBitsAdvanced(mod, false, strat) catch |err| switch (err) {
                            error.NeedLazy => return .{ .val = (try mod.intern(.{ .int = .{
                                .ty = .comptime_int_type,
                                .storage = .{ .lazy_align = ty.toIntern() },
                            } })).toValue() },
                            else => |e| return e,
                        })) continue;

                        const field_align = @intCast(u32, field.abi_align.toByteUnitsOptional() orelse
                            switch (try field.ty.abiAlignmentAdvanced(mod, strat)) {
                            .scalar => |a| a,
                            .val => switch (strat) {
                                .eager => unreachable, // struct layout not resolved
                                .sema => unreachable, // handled above
                                .lazy => return .{ .val = (try mod.intern(.{ .int = .{
                                    .ty = .comptime_int_type,
                                    .storage = .{ .lazy_align = ty.toIntern() },
                                } })).toValue() },
                            },
                        });
                        big_align = @max(big_align, field_align);

                        // This logic is duplicated in Module.Struct.Field.alignment.
                        if (struct_obj.layout == .Extern or target.ofmt == .c) {
                            if (field.ty.isAbiInt(mod) and field.ty.intInfo(mod).bits >= 128) {
                                // The C ABI requires 128 bit integer fields of structs
                                // to be 16-bytes aligned.
                                big_align = @max(big_align, 16);
                            }
                        }
                    }
                    return AbiAlignmentAdvanced{ .scalar = big_align };
                },
                .anon_struct_type => |tuple| {
                    var big_align: u32 = 0;
                    for (tuple.types, tuple.values) |field_ty, val| {
                        if (val != .none) continue; // comptime field
                        if (!(field_ty.toType().hasRuntimeBits(mod))) continue;

                        switch (try field_ty.toType().abiAlignmentAdvanced(mod, strat)) {
                            .scalar => |field_align| big_align = @max(big_align, field_align),
                            .val => switch (strat) {
                                .eager => unreachable, // field type alignment not resolved
                                .sema => unreachable, // passed to abiAlignmentAdvanced above
                                .lazy => return .{ .val = (try mod.intern(.{ .int = .{
                                    .ty = .comptime_int_type,
                                    .storage = .{ .lazy_align = ty.toIntern() },
                                } })).toValue() },
                            },
                        }
                    }
                    return AbiAlignmentAdvanced{ .scalar = big_align };
                },

                .union_type => |union_type| {
                    const union_obj = mod.unionPtr(union_type.index);
                    return abiAlignmentAdvancedUnion(ty, mod, strat, union_obj, union_type.hasTag());
                },
                .opaque_type => return AbiAlignmentAdvanced{ .scalar = 1 },
                .enum_type => |enum_type| return AbiAlignmentAdvanced{ .scalar = enum_type.tag_ty.toType().abiAlignment(mod) },

                // values, not types
                .undef,
                .runtime_value,
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
        mod: *Module,
        strat: AbiAlignmentAdvancedStrat,
        payload_ty: Type,
    ) Module.CompileError!AbiAlignmentAdvanced {
        // This code needs to be kept in sync with the equivalent switch prong
        // in abiSizeAdvanced.
        const code_align = abiAlignment(Type.anyerror, mod);
        switch (strat) {
            .eager, .sema => {
                if (!(payload_ty.hasRuntimeBitsAdvanced(mod, false, strat) catch |err| switch (err) {
                    error.NeedLazy => return .{ .val = (try mod.intern(.{ .int = .{
                        .ty = .comptime_int_type,
                        .storage = .{ .lazy_align = ty.toIntern() },
                    } })).toValue() },
                    else => |e| return e,
                })) {
                    return AbiAlignmentAdvanced{ .scalar = code_align };
                }
                return AbiAlignmentAdvanced{ .scalar = @max(
                    code_align,
                    (try payload_ty.abiAlignmentAdvanced(mod, strat)).scalar,
                ) };
            },
            .lazy => {
                switch (try payload_ty.abiAlignmentAdvanced(mod, strat)) {
                    .scalar => |payload_align| {
                        return AbiAlignmentAdvanced{
                            .scalar = @max(code_align, payload_align),
                        };
                    },
                    .val => {},
                }
                return .{ .val = (try mod.intern(.{ .int = .{
                    .ty = .comptime_int_type,
                    .storage = .{ .lazy_align = ty.toIntern() },
                } })).toValue() };
            },
        }
    }

    fn abiAlignmentAdvancedOptional(
        ty: Type,
        mod: *Module,
        strat: AbiAlignmentAdvancedStrat,
    ) Module.CompileError!AbiAlignmentAdvanced {
        const target = mod.getTarget();
        const child_type = ty.optionalChild(mod);

        switch (child_type.zigTypeTag(mod)) {
            .Pointer => return AbiAlignmentAdvanced{ .scalar = @divExact(target.ptrBitWidth(), 8) },
            .ErrorSet => return abiAlignmentAdvanced(Type.anyerror, mod, strat),
            .NoReturn => return AbiAlignmentAdvanced{ .scalar = 0 },
            else => {},
        }

        switch (strat) {
            .eager, .sema => {
                if (!(child_type.hasRuntimeBitsAdvanced(mod, false, strat) catch |err| switch (err) {
                    error.NeedLazy => return .{ .val = (try mod.intern(.{ .int = .{
                        .ty = .comptime_int_type,
                        .storage = .{ .lazy_align = ty.toIntern() },
                    } })).toValue() },
                    else => |e| return e,
                })) {
                    return AbiAlignmentAdvanced{ .scalar = 1 };
                }
                return child_type.abiAlignmentAdvanced(mod, strat);
            },
            .lazy => switch (try child_type.abiAlignmentAdvanced(mod, strat)) {
                .scalar => |x| return AbiAlignmentAdvanced{ .scalar = @max(x, 1) },
                .val => return .{ .val = (try mod.intern(.{ .int = .{
                    .ty = .comptime_int_type,
                    .storage = .{ .lazy_align = ty.toIntern() },
                } })).toValue() },
            },
        }
    }

    pub fn abiAlignmentAdvancedUnion(
        ty: Type,
        mod: *Module,
        strat: AbiAlignmentAdvancedStrat,
        union_obj: *Module.Union,
        have_tag: bool,
    ) Module.CompileError!AbiAlignmentAdvanced {
        const opt_sema = switch (strat) {
            .sema => |sema| sema,
            else => null,
        };
        if (opt_sema) |sema| {
            if (union_obj.status == .field_types_wip) {
                // We'll guess "pointer-aligned", if the union has an
                // underaligned pointer field then some allocations
                // might require explicit alignment.
                const target = mod.getTarget();
                return AbiAlignmentAdvanced{ .scalar = @divExact(target.ptrBitWidth(), 8) };
            }
            _ = try sema.resolveTypeFields(ty);
        }
        if (!union_obj.haveFieldTypes()) switch (strat) {
            .eager => unreachable, // union layout not resolved
            .sema => unreachable, // handled above
            .lazy => return .{ .val = (try mod.intern(.{ .int = .{
                .ty = .comptime_int_type,
                .storage = .{ .lazy_align = ty.toIntern() },
            } })).toValue() },
        };
        if (union_obj.fields.count() == 0) {
            if (have_tag) {
                return abiAlignmentAdvanced(union_obj.tag_ty, mod, strat);
            } else {
                return AbiAlignmentAdvanced{ .scalar = @intFromBool(union_obj.layout == .Extern) };
            }
        }

        var max_align: u32 = 0;
        if (have_tag) max_align = union_obj.tag_ty.abiAlignment(mod);
        for (union_obj.fields.values()) |field| {
            if (!(field.ty.hasRuntimeBitsAdvanced(mod, false, strat) catch |err| switch (err) {
                error.NeedLazy => return .{ .val = (try mod.intern(.{ .int = .{
                    .ty = .comptime_int_type,
                    .storage = .{ .lazy_align = ty.toIntern() },
                } })).toValue() },
                else => |e| return e,
            })) continue;

            const field_align = @intCast(u32, field.abi_align.toByteUnitsOptional() orelse
                switch (try field.ty.abiAlignmentAdvanced(mod, strat)) {
                .scalar => |a| a,
                .val => switch (strat) {
                    .eager => unreachable, // struct layout not resolved
                    .sema => unreachable, // handled above
                    .lazy => return .{ .val = (try mod.intern(.{ .int = .{
                        .ty = .comptime_int_type,
                        .storage = .{ .lazy_align = ty.toIntern() },
                    } })).toValue() },
                },
            });
            max_align = @max(max_align, field_align);
        }
        return AbiAlignmentAdvanced{ .scalar = max_align };
    }

    /// May capture a reference to `ty`.
    pub fn lazyAbiSize(ty: Type, mod: *Module) !Value {
        switch (try ty.abiSizeAdvanced(mod, .lazy)) {
            .val => |val| return val,
            .scalar => |x| return mod.intValue(Type.comptime_int, x),
        }
    }

    /// Asserts the type has the ABI size already resolved.
    /// Types that return false for hasRuntimeBits() return 0.
    pub fn abiSize(ty: Type, mod: *Module) u64 {
        return (abiSizeAdvanced(ty, mod, .eager) catch unreachable).scalar;
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
        mod: *Module,
        strat: AbiAlignmentAdvancedStrat,
    ) Module.CompileError!AbiSizeAdvanced {
        const target = mod.getTarget();

        switch (ty.toIntern()) {
            .empty_struct_type => return AbiSizeAdvanced{ .scalar = 0 },

            else => switch (mod.intern_pool.indexToKey(ty.toIntern())) {
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
                    switch (try array_type.child.toType().abiSizeAdvanced(mod, strat)) {
                        .scalar => |elem_size| return .{ .scalar = len * elem_size },
                        .val => switch (strat) {
                            .sema, .eager => unreachable,
                            .lazy => return .{ .val = (try mod.intern(.{ .int = .{
                                .ty = .comptime_int_type,
                                .storage = .{ .lazy_size = ty.toIntern() },
                            } })).toValue() },
                        },
                    }
                },
                .vector_type => |vector_type| {
                    const opt_sema = switch (strat) {
                        .sema => |sema| sema,
                        .eager => null,
                        .lazy => return .{ .val = (try mod.intern(.{ .int = .{
                            .ty = .comptime_int_type,
                            .storage = .{ .lazy_size = ty.toIntern() },
                        } })).toValue() },
                    };
                    const elem_bits_u64 = try vector_type.child.toType().bitSizeAdvanced(mod, opt_sema);
                    const elem_bits = @intCast(u32, elem_bits_u64);
                    const total_bits = elem_bits * vector_type.len;
                    const total_bytes = (total_bits + 7) / 8;
                    const alignment = switch (try ty.abiAlignmentAdvanced(mod, strat)) {
                        .scalar => |x| x,
                        .val => return .{ .val = (try mod.intern(.{ .int = .{
                            .ty = .comptime_int_type,
                            .storage = .{ .lazy_size = ty.toIntern() },
                        } })).toValue() },
                    };
                    const result = std.mem.alignForward(u32, total_bytes, alignment);
                    return AbiSizeAdvanced{ .scalar = result };
                },

                .opt_type => return ty.abiSizeAdvancedOptional(mod, strat),

                // TODO revisit this when we have the concept of the error tag type
                .error_set_type, .inferred_error_set_type => return AbiSizeAdvanced{ .scalar = 2 },

                .error_union_type => |error_union_type| {
                    const payload_ty = error_union_type.payload_type.toType();
                    // This code needs to be kept in sync with the equivalent switch prong
                    // in abiAlignmentAdvanced.
                    const code_size = abiSize(Type.anyerror, mod);
                    if (!(payload_ty.hasRuntimeBitsAdvanced(mod, false, strat) catch |err| switch (err) {
                        error.NeedLazy => return .{ .val = (try mod.intern(.{ .int = .{
                            .ty = .comptime_int_type,
                            .storage = .{ .lazy_size = ty.toIntern() },
                        } })).toValue() },
                        else => |e| return e,
                    })) {
                        // Same as anyerror.
                        return AbiSizeAdvanced{ .scalar = code_size };
                    }
                    const code_align = abiAlignment(Type.anyerror, mod);
                    const payload_align = abiAlignment(payload_ty, mod);
                    const payload_size = switch (try payload_ty.abiSizeAdvanced(mod, strat)) {
                        .scalar => |elem_size| elem_size,
                        .val => switch (strat) {
                            .sema => unreachable,
                            .eager => unreachable,
                            .lazy => return .{ .val = (try mod.intern(.{ .int = .{
                                .ty = .comptime_int_type,
                                .storage = .{ .lazy_size = ty.toIntern() },
                            } })).toValue() },
                        },
                    };

                    var size: u64 = 0;
                    if (code_align > payload_align) {
                        size += code_size;
                        size = std.mem.alignForward(u64, size, payload_align);
                        size += payload_size;
                        size = std.mem.alignForward(u64, size, code_align);
                    } else {
                        size += payload_size;
                        size = std.mem.alignForward(u64, size, code_align);
                        size += code_size;
                        size = std.mem.alignForward(u64, size, payload_align);
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
                            return AbiSizeAdvanced{ .scalar = abiSize(u80_ty, mod) };
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

                    // TODO revisit this when we have the concept of the error tag type
                    .anyerror => return AbiSizeAdvanced{ .scalar = 2 },

                    .prefetch_options => unreachable, // missing call to resolveTypeFields
                    .export_options => unreachable, // missing call to resolveTypeFields
                    .extern_options => unreachable, // missing call to resolveTypeFields

                    .type_info => unreachable,
                    .noreturn => unreachable,
                    .generic_poison => unreachable,
                },
                .struct_type => |struct_type| switch (ty.containerLayout(mod)) {
                    .Packed => {
                        const struct_obj = mod.structPtrUnwrap(struct_type.index) orelse
                            return AbiSizeAdvanced{ .scalar = 0 };

                        switch (strat) {
                            .sema => |sema| try sema.resolveTypeLayout(ty),
                            .lazy => if (!struct_obj.haveLayout()) return .{ .val = (try mod.intern(.{ .int = .{
                                .ty = .comptime_int_type,
                                .storage = .{ .lazy_size = ty.toIntern() },
                            } })).toValue() },
                            .eager => {},
                        }
                        assert(struct_obj.haveLayout());
                        return AbiSizeAdvanced{ .scalar = struct_obj.backing_int_ty.abiSize(mod) };
                    },
                    else => {
                        switch (strat) {
                            .sema => |sema| try sema.resolveTypeLayout(ty),
                            .lazy => {
                                const struct_obj = mod.structPtrUnwrap(struct_type.index) orelse
                                    return AbiSizeAdvanced{ .scalar = 0 };
                                if (!struct_obj.haveLayout()) return .{ .val = (try mod.intern(.{ .int = .{
                                    .ty = .comptime_int_type,
                                    .storage = .{ .lazy_size = ty.toIntern() },
                                } })).toValue() };
                            },
                            .eager => {},
                        }
                        const field_count = ty.structFieldCount(mod);
                        if (field_count == 0) {
                            return AbiSizeAdvanced{ .scalar = 0 };
                        }
                        return AbiSizeAdvanced{ .scalar = ty.structFieldOffset(field_count, mod) };
                    },
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
                    return AbiSizeAdvanced{ .scalar = ty.structFieldOffset(field_count, mod) };
                },

                .union_type => |union_type| {
                    const union_obj = mod.unionPtr(union_type.index);
                    return abiSizeAdvancedUnion(ty, mod, strat, union_obj, union_type.hasTag());
                },
                .opaque_type => unreachable, // no size available
                .enum_type => |enum_type| return AbiSizeAdvanced{ .scalar = enum_type.tag_ty.toType().abiSize(mod) },

                // values, not types
                .undef,
                .runtime_value,
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

    pub fn abiSizeAdvancedUnion(
        ty: Type,
        mod: *Module,
        strat: AbiAlignmentAdvancedStrat,
        union_obj: *Module.Union,
        have_tag: bool,
    ) Module.CompileError!AbiSizeAdvanced {
        switch (strat) {
            .sema => |sema| try sema.resolveTypeLayout(ty),
            .lazy => if (!union_obj.haveLayout()) return .{ .val = (try mod.intern(.{ .int = .{
                .ty = .comptime_int_type,
                .storage = .{ .lazy_size = ty.toIntern() },
            } })).toValue() },
            .eager => {},
        }
        return AbiSizeAdvanced{ .scalar = union_obj.abiSize(mod, have_tag) };
    }

    fn abiSizeAdvancedOptional(
        ty: Type,
        mod: *Module,
        strat: AbiAlignmentAdvancedStrat,
    ) Module.CompileError!AbiSizeAdvanced {
        const child_ty = ty.optionalChild(mod);

        if (child_ty.isNoReturn(mod)) {
            return AbiSizeAdvanced{ .scalar = 0 };
        }

        if (!(child_ty.hasRuntimeBitsAdvanced(mod, false, strat) catch |err| switch (err) {
            error.NeedLazy => return .{ .val = (try mod.intern(.{ .int = .{
                .ty = .comptime_int_type,
                .storage = .{ .lazy_size = ty.toIntern() },
            } })).toValue() },
            else => |e| return e,
        })) return AbiSizeAdvanced{ .scalar = 1 };

        if (ty.optionalReprIsPayload(mod)) {
            return abiSizeAdvanced(child_ty, mod, strat);
        }

        const payload_size = switch (try child_ty.abiSizeAdvanced(mod, strat)) {
            .scalar => |elem_size| elem_size,
            .val => switch (strat) {
                .sema => unreachable,
                .eager => unreachable,
                .lazy => return .{ .val = (try mod.intern(.{ .int = .{
                    .ty = .comptime_int_type,
                    .storage = .{ .lazy_size = ty.toIntern() },
                } })).toValue() },
            },
        };

        // Optional types are represented as a struct with the child type as the first
        // field and a boolean as the second. Since the child type's abi alignment is
        // guaranteed to be >= that of bool's (1 byte) the added size is exactly equal
        // to the child type's ABI alignment.
        return AbiSizeAdvanced{
            .scalar = child_ty.abiAlignment(mod) + payload_size,
        };
    }

    fn intAbiSize(bits: u16, target: Target) u64 {
        const alignment = intAbiAlignment(bits, target);
        return std.mem.alignForward(u64, @intCast(u16, (@as(u17, bits) + 7) / 8), alignment);
    }

    fn intAbiAlignment(bits: u16, target: Target) u32 {
        return @min(
            std.math.ceilPowerOfTwoPromote(u16, @intCast(u16, (@as(u17, bits) + 7) / 8)),
            target.maxIntAlignment(),
        );
    }

    pub fn bitSize(ty: Type, mod: *Module) u64 {
        return bitSizeAdvanced(ty, mod, null) catch unreachable;
    }

    /// If you pass `opt_sema`, any recursive type resolutions will happen if
    /// necessary, possibly returning a CompileError. Passing `null` instead asserts
    /// the type is fully resolved, and there will be no error, guaranteed.
    pub fn bitSizeAdvanced(
        ty: Type,
        mod: *Module,
        opt_sema: ?*Sema,
    ) Module.CompileError!u64 {
        const target = mod.getTarget();

        const strat: AbiAlignmentAdvancedStrat = if (opt_sema) |sema| .{ .sema = sema } else .eager;

        switch (mod.intern_pool.indexToKey(ty.toIntern())) {
            .int_type => |int_type| return int_type.bits,
            .ptr_type => |ptr_type| switch (ptr_type.flags.size) {
                .Slice => return target.ptrBitWidth() * 2,
                else => return target.ptrBitWidth(),
            },
            .anyframe_type => return target.ptrBitWidth(),

            .array_type => |array_type| {
                const len = array_type.len + @intFromBool(array_type.sentinel != .none);
                if (len == 0) return 0;
                const elem_ty = array_type.child.toType();
                const elem_size = @max(elem_ty.abiAlignment(mod), elem_ty.abiSize(mod));
                if (elem_size == 0) return 0;
                const elem_bit_size = try bitSizeAdvanced(elem_ty, mod, opt_sema);
                return (len - 1) * 8 * elem_size + elem_bit_size;
            },
            .vector_type => |vector_type| {
                const child_ty = vector_type.child.toType();
                const elem_bit_size = try bitSizeAdvanced(child_ty, mod, opt_sema);
                return elem_bit_size * vector_type.len;
            },
            .opt_type => {
                // Optionals and error unions are not packed so their bitsize
                // includes padding bits.
                return (try abiSizeAdvanced(ty, mod, strat)).scalar * 8;
            },

            // TODO revisit this when we have the concept of the error tag type
            .error_set_type, .inferred_error_set_type => return 16,

            .error_union_type => {
                // Optionals and error unions are not packed so their bitsize
                // includes padding bits.
                return (try abiSizeAdvanced(ty, mod, strat)).scalar * 8;
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

                // TODO revisit this when we have the concept of the error tag type
                .anyerror => return 16,

                .anyopaque => unreachable,
                .type => unreachable,
                .comptime_int => unreachable,
                .comptime_float => unreachable,
                .noreturn => unreachable,
                .null => unreachable,
                .undefined => unreachable,
                .enum_literal => unreachable,
                .generic_poison => unreachable,

                .atomic_order => unreachable, // missing call to resolveTypeFields
                .atomic_rmw_op => unreachable, // missing call to resolveTypeFields
                .calling_convention => unreachable, // missing call to resolveTypeFields
                .address_space => unreachable, // missing call to resolveTypeFields
                .float_mode => unreachable, // missing call to resolveTypeFields
                .reduce_op => unreachable, // missing call to resolveTypeFields
                .call_modifier => unreachable, // missing call to resolveTypeFields
                .prefetch_options => unreachable, // missing call to resolveTypeFields
                .export_options => unreachable, // missing call to resolveTypeFields
                .extern_options => unreachable, // missing call to resolveTypeFields
                .type_info => unreachable, // missing call to resolveTypeFields
            },
            .struct_type => |struct_type| {
                const struct_obj = mod.structPtrUnwrap(struct_type.index) orelse return 0;
                if (struct_obj.layout != .Packed) {
                    return (try ty.abiSizeAdvanced(mod, strat)).scalar * 8;
                }
                if (opt_sema) |sema| _ = try sema.resolveTypeLayout(ty);
                assert(struct_obj.haveLayout());
                return try struct_obj.backing_int_ty.bitSizeAdvanced(mod, opt_sema);
            },

            .anon_struct_type => {
                if (opt_sema) |sema| _ = try sema.resolveTypeFields(ty);
                return (try ty.abiSizeAdvanced(mod, strat)).scalar * 8;
            },

            .union_type => |union_type| {
                if (opt_sema) |sema| _ = try sema.resolveTypeFields(ty);
                if (ty.containerLayout(mod) != .Packed) {
                    return (try ty.abiSizeAdvanced(mod, strat)).scalar * 8;
                }
                const union_obj = mod.unionPtr(union_type.index);
                assert(union_obj.haveFieldTypes());

                var size: u64 = 0;
                for (union_obj.fields.values()) |field| {
                    size = @max(size, try bitSizeAdvanced(field.ty, mod, opt_sema));
                }
                return size;
            },
            .opaque_type => unreachable,
            .enum_type => |enum_type| return bitSizeAdvanced(enum_type.tag_ty.toType(), mod, opt_sema),

            // values, not types
            .undef,
            .runtime_value,
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
    pub fn layoutIsResolved(ty: Type, mod: *Module) bool {
        switch (ty.zigTypeTag(mod)) {
            .Struct => {
                if (mod.typeToStruct(ty)) |struct_obj| {
                    return struct_obj.haveLayout();
                }
                return true;
            },
            .Union => {
                if (mod.typeToUnion(ty)) |union_obj| {
                    return union_obj.haveLayout();
                }
                return true;
            },
            .Array => {
                if (ty.arrayLenIncludingSentinel(mod) == 0) return true;
                return ty.childType(mod).layoutIsResolved(mod);
            },
            .Optional => {
                const payload_ty = ty.optionalChild(mod);
                return payload_ty.layoutIsResolved(mod);
            },
            .ErrorUnion => {
                const payload_ty = ty.errorUnionPayload(mod);
                return payload_ty.layoutIsResolved(mod);
            },
            else => return true,
        }
    }

    pub fn isSinglePointer(ty: Type, mod: *const Module) bool {
        return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
            .ptr_type => |ptr_info| ptr_info.flags.size == .One,
            else => false,
        };
    }

    /// Asserts `ty` is a pointer.
    pub fn ptrSize(ty: Type, mod: *const Module) std.builtin.Type.Pointer.Size {
        return ptrSizeOrNull(ty, mod).?;
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
        return mod.intern_pool.slicePtrType(ty.toIntern()).toType();
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
                .error_set_type => true,
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
        return ip.childType(ty.toIntern()).toType();
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
                .One => ptr_type.child.toType().shallowElemType(mod),
                .Many, .C, .Slice => ptr_type.child.toType(),
            },
            .anyframe_type => |child| {
                assert(child != .none);
                return child.toType();
            },
            .vector_type => |vector_type| vector_type.child.toType(),
            .array_type => |array_type| array_type.child.toType(),
            .opt_type => |child| mod.intern_pool.childType(child).toType(),
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
            .opt_type => |child| child.toType(),
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
        return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
            .union_type => |union_type| switch (union_type.runtime_tag) {
                .tagged => {
                    const union_obj = mod.unionPtr(union_type.index);
                    assert(union_obj.haveFieldTypes());
                    return union_obj.tag_ty;
                },
                else => null,
            },
            else => null,
        };
    }

    /// Same as `unionTagType` but includes safety tag.
    /// Codegen should use this version.
    pub fn unionTagTypeSafety(ty: Type, mod: *Module) ?Type {
        return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
            .union_type => |union_type| {
                if (!union_type.hasTag()) return null;
                const union_obj = mod.unionPtr(union_type.index);
                assert(union_obj.haveFieldTypes());
                return union_obj.tag_ty;
            },
            else => null,
        };
    }

    /// Asserts the type is a union; returns the tag type, even if the tag will
    /// not be stored at runtime.
    pub fn unionTagTypeHypothetical(ty: Type, mod: *Module) Type {
        const union_obj = mod.typeToUnion(ty).?;
        assert(union_obj.haveFieldTypes());
        return union_obj.tag_ty;
    }

    pub fn unionFields(ty: Type, mod: *Module) Module.Union.Fields {
        const union_obj = mod.typeToUnion(ty).?;
        assert(union_obj.haveFieldTypes());
        return union_obj.fields;
    }

    pub fn unionFieldType(ty: Type, enum_tag: Value, mod: *Module) Type {
        const union_obj = mod.typeToUnion(ty).?;
        const index = ty.unionTagFieldIndex(enum_tag, mod).?;
        assert(union_obj.haveFieldTypes());
        return union_obj.fields.values()[index].ty;
    }

    pub fn unionTagFieldIndex(ty: Type, enum_tag: Value, mod: *Module) ?usize {
        const union_obj = mod.typeToUnion(ty).?;
        const index = union_obj.tag_ty.enumTagFieldIndex(enum_tag, mod) orelse return null;
        const name = union_obj.tag_ty.enumFieldName(index, mod);
        return union_obj.fields.getIndex(name);
    }

    pub fn unionHasAllZeroBitFieldTypes(ty: Type, mod: *Module) bool {
        const union_obj = mod.typeToUnion(ty).?;
        return union_obj.hasAllZeroBitFieldTypes(mod);
    }

    pub fn unionGetLayout(ty: Type, mod: *Module) Module.Union.Layout {
        const union_type = mod.intern_pool.indexToKey(ty.toIntern()).union_type;
        const union_obj = mod.unionPtr(union_type.index);
        return union_obj.getLayout(mod, union_type.hasTag());
    }

    pub fn containerLayout(ty: Type, mod: *Module) std.builtin.Type.ContainerLayout {
        return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
            .struct_type => |struct_type| {
                const struct_obj = mod.structPtrUnwrap(struct_type.index) orelse return .Auto;
                return struct_obj.layout;
            },
            .anon_struct_type => .Auto,
            .union_type => |union_type| {
                const union_obj = mod.unionPtr(union_type.index);
                return union_obj.layout;
            },
            else => unreachable,
        };
    }

    /// Asserts that the type is an error union.
    pub fn errorUnionPayload(ty: Type, mod: *Module) Type {
        return mod.intern_pool.indexToKey(ty.toIntern()).error_union_type.payload_type.toType();
    }

    /// Asserts that the type is an error union.
    pub fn errorUnionSet(ty: Type, mod: *Module) Type {
        return mod.intern_pool.indexToKey(ty.toIntern()).error_union_type.error_set_type.toType();
    }

    /// Returns false for unresolved inferred error sets.
    pub fn errorSetIsEmpty(ty: Type, mod: *Module) bool {
        return switch (ty.toIntern()) {
            .anyerror_type => false,
            else => switch (mod.intern_pool.indexToKey(ty.toIntern())) {
                .error_set_type => |error_set_type| error_set_type.names.len == 0,
                .inferred_error_set_type => |index| {
                    const inferred_error_set = mod.inferredErrorSetPtr(index);
                    // Can't know for sure.
                    if (!inferred_error_set.is_resolved) return false;
                    if (inferred_error_set.is_anyerror) return false;
                    return inferred_error_set.errors.count() == 0;
                },
                else => unreachable,
            },
        };
    }

    /// Returns true if it is an error set that includes anyerror, false otherwise.
    /// Note that the result may be a false negative if the type did not get error set
    /// resolution prior to this call.
    pub fn isAnyError(ty: Type, mod: *Module) bool {
        return switch (ty.toIntern()) {
            .anyerror_type => true,
            else => switch (mod.intern_pool.indexToKey(ty.toIntern())) {
                .inferred_error_set_type => |i| mod.inferredErrorSetPtr(i).is_anyerror,
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
                .error_set_type => |error_set_type| {
                    return error_set_type.nameIndex(ip, name) != null;
                },
                .inferred_error_set_type => |index| {
                    const ies = ip.inferredErrorSetPtrConst(index);
                    if (ies.is_anyerror) return true;
                    return ies.errors.contains(name);
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
                .inferred_error_set_type => |index| {
                    const ies = ip.inferredErrorSetPtr(index);
                    if (ies.is_anyerror) return true;
                    // If the string is not interned, then the field certainly is not present.
                    const field_name_interned = ip.getString(name).unwrap() orelse return false;
                    return ies.errors.contains(field_name_interned);
                },
                else => unreachable,
            },
        };
    }

    /// Asserts the type is an array or vector or struct.
    pub fn arrayLen(ty: Type, mod: *const Module) u64 {
        return arrayLenIp(ty, &mod.intern_pool);
    }

    pub fn arrayLenIp(ty: Type, ip: *const InternPool) u64 {
        return switch (ip.indexToKey(ty.toIntern())) {
            .vector_type => |vector_type| vector_type.len,
            .array_type => |array_type| array_type.len,
            .struct_type => |struct_type| {
                const struct_obj = ip.structPtrUnwrapConst(struct_type.index) orelse return 0;
                return struct_obj.fields.count();
            },
            .anon_struct_type => |tuple| tuple.types.len,

            else => unreachable,
        };
    }

    pub fn arrayLenIncludingSentinel(ty: Type, mod: *const Module) u64 {
        return ty.arrayLen(mod) + @intFromBool(ty.sentinel(mod) != null);
    }

    pub fn vectorLen(ty: Type, mod: *const Module) u32 {
        return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
            .vector_type => |vector_type| vector_type.len,
            .anon_struct_type => |tuple| @intCast(u32, tuple.types.len),
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

            .array_type => |t| if (t.sentinel != .none) t.sentinel.toValue() else null,
            .ptr_type => |t| if (t.sentinel != .none) t.sentinel.toValue() else null,

            else => unreachable,
        };
    }

    /// Returns true if and only if the type is a fixed-width integer.
    pub fn isInt(self: Type, mod: *const Module) bool {
        return self.isSignedInt(mod) or self.isUnsignedInt(mod);
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
            .Struct => ty.containerLayout(mod) == .Packed,
            else => false,
        };
    }

    /// Asserts the type is an integer, enum, error set, or vector of one of them.
    pub fn intInfo(starting_ty: Type, mod: *Module) InternPool.Key.IntType {
        const target = mod.getTarget();
        var ty = starting_ty;

        while (true) switch (ty.toIntern()) {
            .anyerror_type => {
                // TODO revisit this when error sets support custom int types
                return .{ .signedness = .unsigned, .bits = 16 };
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
            else => switch (mod.intern_pool.indexToKey(ty.toIntern())) {
                .int_type => |int_type| return int_type,
                .struct_type => |struct_type| {
                    const struct_obj = mod.structPtrUnwrap(struct_type.index).?;
                    assert(struct_obj.layout == .Packed);
                    ty = struct_obj.backing_int_ty;
                },
                .enum_type => |enum_type| ty = enum_type.tag_ty.toType(),
                .vector_type => |vector_type| ty = vector_type.child.toType(),

                // TODO revisit this when error sets support custom int types
                .error_set_type, .inferred_error_set_type => return .{ .signedness = .unsigned, .bits = 16 },

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
                .runtime_value,
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
    pub fn fnReturnType(ty: Type, mod: *Module) Type {
        return mod.intern_pool.funcReturnType(ty.toIntern()).toType();
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
    pub fn onePossibleValue(starting_type: Type, mod: *Module) !?Value {
        var ty = starting_type;

        while (true) switch (ty.toIntern()) {
            .empty_struct_type => return Value.empty_struct,

            else => switch (mod.intern_pool.indexToKey(ty.toIntern())) {
                .int_type => |int_type| {
                    if (int_type.bits == 0) {
                        return try mod.intValue(ty, 0);
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
                    if (seq_type.len + @intFromBool(has_sentinel) == 0) return (try mod.intern(.{ .aggregate = .{
                        .ty = ty.toIntern(),
                        .storage = .{ .elems = &.{} },
                    } })).toValue();
                    if (try seq_type.child.toType().onePossibleValue(mod)) |opv| {
                        return (try mod.intern(.{ .aggregate = .{
                            .ty = ty.toIntern(),
                            .storage = .{ .repeated_elem = opv.toIntern() },
                        } })).toValue();
                    }
                    return null;
                },
                .opt_type => |child| {
                    if (child == .noreturn_type) {
                        return try mod.nullValue(ty);
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
                    => return null,

                    .void => return Value.void,
                    .noreturn => return Value.@"unreachable",
                    .null => return Value.null,
                    .undefined => return Value.undef,

                    .generic_poison => unreachable,
                },
                .struct_type => |struct_type| {
                    if (mod.structPtrUnwrap(struct_type.index)) |s| {
                        assert(s.haveFieldTypes());
                        const field_vals = try mod.gpa.alloc(InternPool.Index, s.fields.count());
                        defer mod.gpa.free(field_vals);
                        for (field_vals, s.fields.values()) |*field_val, field| {
                            if (field.is_comptime) {
                                field_val.* = field.default_val;
                                continue;
                            }
                            if (try field.ty.onePossibleValue(mod)) |field_opv| {
                                field_val.* = try field_opv.intern(field.ty, mod);
                            } else return null;
                        }

                        // In this case the struct has no runtime-known fields and
                        // therefore has one possible value.
                        return (try mod.intern(.{ .aggregate = .{
                            .ty = ty.toIntern(),
                            .storage = .{ .elems = field_vals },
                        } })).toValue();
                    }

                    // In this case the struct has no fields at all and
                    // therefore has one possible value.
                    return (try mod.intern(.{ .aggregate = .{
                        .ty = ty.toIntern(),
                        .storage = .{ .elems = &.{} },
                    } })).toValue();
                },

                .anon_struct_type => |tuple| {
                    for (tuple.values) |val| {
                        if (val == .none) return null;
                    }
                    // In this case the struct has all comptime-known fields and
                    // therefore has one possible value.
                    // TODO: write something like getCoercedInts to avoid needing to dupe
                    const duped_values = try mod.gpa.dupe(InternPool.Index, tuple.values);
                    defer mod.gpa.free(duped_values);
                    return (try mod.intern(.{ .aggregate = .{
                        .ty = ty.toIntern(),
                        .storage = .{ .elems = duped_values },
                    } })).toValue();
                },

                .union_type => |union_type| {
                    const union_obj = mod.unionPtr(union_type.index);
                    const tag_val = (try union_obj.tag_ty.onePossibleValue(mod)) orelse return null;
                    if (union_obj.fields.count() == 0) {
                        const only = try mod.intern(.{ .empty_enum_value = ty.toIntern() });
                        return only.toValue();
                    }
                    const only_field = union_obj.fields.values()[0];
                    const val_val = (try only_field.ty.onePossibleValue(mod)) orelse return null;
                    const only = try mod.intern(.{ .un = .{
                        .ty = ty.toIntern(),
                        .tag = tag_val.toIntern(),
                        .val = val_val.toIntern(),
                    } });
                    return only.toValue();
                },
                .opaque_type => return null,
                .enum_type => |enum_type| switch (enum_type.tag_mode) {
                    .nonexhaustive => {
                        if (enum_type.tag_ty == .comptime_int_type) return null;

                        if (try enum_type.tag_ty.toType().onePossibleValue(mod)) |int_opv| {
                            const only = try mod.intern(.{ .enum_tag = .{
                                .ty = ty.toIntern(),
                                .int = int_opv.toIntern(),
                            } });
                            return only.toValue();
                        }

                        return null;
                    },
                    .auto, .explicit => {
                        if (enum_type.tag_ty.toType().hasRuntimeBits(mod)) return null;

                        switch (enum_type.names.len) {
                            0 => {
                                const only = try mod.intern(.{ .empty_enum_value = ty.toIntern() });
                                return only.toValue();
                            },
                            1 => {
                                if (enum_type.values.len == 0) {
                                    const only = try mod.intern(.{ .enum_tag = .{
                                        .ty = ty.toIntern(),
                                        .int = try mod.intern(.{ .int = .{
                                            .ty = enum_type.tag_ty,
                                            .storage = .{ .u64 = 0 },
                                        } }),
                                    } });
                                    return only.toValue();
                                } else {
                                    return enum_type.values[0].toValue();
                                }
                            },
                            else => return null,
                        }
                    },
                },

                // values, not types
                .undef,
                .runtime_value,
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
    /// TODO merge these implementations together with the "advanced" pattern seen
    /// elsewhere in this file.
    pub fn comptimeOnly(ty: Type, mod: *Module) bool {
        return switch (ty.toIntern()) {
            .empty_struct_type => false,

            else => switch (mod.intern_pool.indexToKey(ty.toIntern())) {
                .int_type => false,
                .ptr_type => |ptr_type| {
                    const child_ty = ptr_type.child.toType();
                    if (child_ty.zigTypeTag(mod) == .Fn) {
                        return false;
                    } else {
                        return child_ty.comptimeOnly(mod);
                    }
                },
                .anyframe_type => |child| {
                    if (child == .none) return false;
                    return child.toType().comptimeOnly(mod);
                },
                .array_type => |array_type| array_type.child.toType().comptimeOnly(mod),
                .vector_type => |vector_type| vector_type.child.toType().comptimeOnly(mod),
                .opt_type => |child| child.toType().comptimeOnly(mod),
                .error_union_type => |error_union_type| error_union_type.payload_type.toType().comptimeOnly(mod),

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
                    // A struct with no fields is not comptime-only.
                    const struct_obj = mod.structPtrUnwrap(struct_type.index) orelse return false;
                    switch (struct_obj.requires_comptime) {
                        .wip, .unknown => {
                            // Return false to avoid incorrect dependency loops.
                            // This will be handled correctly once merged with
                            // `Sema.typeRequiresComptime`.
                            return false;
                        },
                        .no => return false,
                        .yes => return true,
                    }
                },

                .anon_struct_type => |tuple| {
                    for (tuple.types, tuple.values) |field_ty, val| {
                        const have_comptime_val = val != .none;
                        if (!have_comptime_val and field_ty.toType().comptimeOnly(mod)) return true;
                    }
                    return false;
                },

                .union_type => |union_type| {
                    const union_obj = mod.unionPtr(union_type.index);
                    switch (union_obj.requires_comptime) {
                        .wip, .unknown => {
                            // Return false to avoid incorrect dependency loops.
                            // This will be handled correctly once merged with
                            // `Sema.typeRequiresComptime`.
                            return false;
                        },
                        .no => return false,
                        .yes => return true,
                    }
                },

                .opaque_type => false,

                .enum_type => |enum_type| enum_type.tag_ty.toType().comptimeOnly(mod),

                // values, not types
                .undef,
                .runtime_value,
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

    pub fn isVector(ty: Type, mod: *const Module) bool {
        return ty.zigTypeTag(mod) == .Vector;
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

    /// Returns null if the type has no namespace.
    pub fn getNamespaceIndex(ty: Type, mod: *Module) Module.Namespace.OptionalIndex {
        return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
            .opaque_type => |opaque_type| opaque_type.namespace.toOptional(),
            .struct_type => |struct_type| struct_type.namespace,
            .union_type => |union_type| mod.unionPtr(union_type.index).namespace.toOptional(),
            .enum_type => |enum_type| enum_type.namespace,

            else => .none,
        };
    }

    /// Returns null if the type has no namespace.
    pub fn getNamespace(ty: Type, mod: *Module) ?*Module.Namespace {
        return if (getNamespaceIndex(ty, mod).unwrap()) |i| mod.namespacePtr(i) else null;
    }

    // Works for vectors and vectors of integers.
    pub fn minInt(ty: Type, mod: *Module, dest_ty: Type) !Value {
        const scalar = try minIntScalar(ty.scalarType(mod), mod, dest_ty.scalarType(mod));
        return if (ty.zigTypeTag(mod) == .Vector) (try mod.intern(.{ .aggregate = .{
            .ty = dest_ty.toIntern(),
            .storage = .{ .repeated_elem = scalar.toIntern() },
        } })).toValue() else scalar;
    }

    /// Asserts that the type is an integer.
    pub fn minIntScalar(ty: Type, mod: *Module, dest_ty: Type) !Value {
        const info = ty.intInfo(mod);
        if (info.signedness == .unsigned) return mod.intValue(dest_ty, 0);
        if (info.bits == 0) return mod.intValue(dest_ty, -1);

        if (std.math.cast(u6, info.bits - 1)) |shift| {
            const n = @as(i64, std.math.minInt(i64)) >> (63 - shift);
            return mod.intValue(dest_ty, n);
        }

        var res = try std.math.big.int.Managed.init(mod.gpa);
        defer res.deinit();

        try res.setTwosCompIntLimit(.min, info.signedness, info.bits);

        return mod.intValue_big(dest_ty, res.toConst());
    }

    // Works for vectors and vectors of integers.
    /// The returned Value will have type dest_ty.
    pub fn maxInt(ty: Type, mod: *Module, dest_ty: Type) !Value {
        const scalar = try maxIntScalar(ty.scalarType(mod), mod, dest_ty.scalarType(mod));
        return if (ty.zigTypeTag(mod) == .Vector) (try mod.intern(.{ .aggregate = .{
            .ty = dest_ty.toIntern(),
            .storage = .{ .repeated_elem = scalar.toIntern() },
        } })).toValue() else scalar;
    }

    /// The returned Value will have type dest_ty.
    pub fn maxIntScalar(ty: Type, mod: *Module, dest_ty: Type) !Value {
        const info = ty.intInfo(mod);

        switch (info.bits) {
            0 => return switch (info.signedness) {
                .signed => try mod.intValue(dest_ty, -1),
                .unsigned => try mod.intValue(dest_ty, 0),
            },
            1 => return switch (info.signedness) {
                .signed => try mod.intValue(dest_ty, 0),
                .unsigned => try mod.intValue(dest_ty, 1),
            },
            else => {},
        }

        if (std.math.cast(u6, info.bits - 1)) |shift| switch (info.signedness) {
            .signed => {
                const n = @as(i64, std.math.maxInt(i64)) >> (63 - shift);
                return mod.intValue(dest_ty, n);
            },
            .unsigned => {
                const n = @as(u64, std.math.maxInt(u64)) >> (63 - shift);
                return mod.intValue(dest_ty, n);
            },
        };

        var res = try std.math.big.int.Managed.init(mod.gpa);
        defer res.deinit();

        try res.setTwosCompIntLimit(.max, info.signedness, info.bits);

        return mod.intValue_big(dest_ty, res.toConst());
    }

    /// Asserts the type is an enum or a union.
    pub fn intTagType(ty: Type, mod: *Module) Type {
        return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
            .union_type => |union_type| mod.unionPtr(union_type.index).tag_ty.intTagType(mod),
            .enum_type => |enum_type| enum_type.tag_ty.toType(),
            else => unreachable,
        };
    }

    pub fn isNonexhaustiveEnum(ty: Type, mod: *Module) bool {
        return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
            .enum_type => |enum_type| switch (enum_type.tag_mode) {
                .nonexhaustive => true,
                .auto, .explicit => false,
            },
            else => false,
        };
    }

    // Asserts that `ty` is an error set and not `anyerror`.
    pub fn errorSetNames(ty: Type, mod: *Module) []const InternPool.NullTerminatedString {
        return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
            .error_set_type => |x| x.names,
            .inferred_error_set_type => |index| {
                const inferred_error_set = mod.inferredErrorSetPtr(index);
                assert(inferred_error_set.is_resolved);
                assert(!inferred_error_set.is_anyerror);
                return inferred_error_set.errors.keys();
            },
            else => unreachable,
        };
    }

    pub fn enumFields(ty: Type, mod: *Module) []const InternPool.NullTerminatedString {
        return mod.intern_pool.indexToKey(ty.toIntern()).enum_type.names;
    }

    pub fn enumFieldCount(ty: Type, mod: *Module) usize {
        return mod.intern_pool.indexToKey(ty.toIntern()).enum_type.names.len;
    }

    pub fn enumFieldName(ty: Type, field_index: usize, mod: *Module) InternPool.NullTerminatedString {
        return mod.intern_pool.indexToKey(ty.toIntern()).enum_type.names[field_index];
    }

    pub fn enumFieldIndex(ty: Type, field_name: InternPool.NullTerminatedString, mod: *Module) ?u32 {
        const ip = &mod.intern_pool;
        const enum_type = ip.indexToKey(ty.toIntern()).enum_type;
        return enum_type.nameIndex(ip, field_name);
    }

    /// Asserts `ty` is an enum. `enum_tag` can either be `enum_field_index` or
    /// an integer which represents the enum value. Returns the field index in
    /// declaration order, or `null` if `enum_tag` does not match any field.
    pub fn enumTagFieldIndex(ty: Type, enum_tag: Value, mod: *Module) ?u32 {
        const ip = &mod.intern_pool;
        const enum_type = ip.indexToKey(ty.toIntern()).enum_type;
        const int_tag = switch (ip.indexToKey(enum_tag.toIntern())) {
            .int => enum_tag.toIntern(),
            .enum_tag => |info| info.int,
            else => unreachable,
        };
        assert(ip.typeOf(int_tag) == enum_type.tag_ty);
        return enum_type.tagValueIndex(ip, int_tag);
    }

    pub fn structFields(ty: Type, mod: *Module) Module.Struct.Fields {
        switch (mod.intern_pool.indexToKey(ty.toIntern())) {
            .struct_type => |struct_type| {
                const struct_obj = mod.structPtrUnwrap(struct_type.index) orelse return .{};
                assert(struct_obj.haveFieldTypes());
                return struct_obj.fields;
            },
            else => unreachable,
        }
    }

    pub fn structFieldName(ty: Type, field_index: usize, mod: *Module) InternPool.NullTerminatedString {
        return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
            .struct_type => |struct_type| {
                const struct_obj = mod.structPtrUnwrap(struct_type.index).?;
                assert(struct_obj.haveFieldTypes());
                return struct_obj.fields.keys()[field_index];
            },
            .anon_struct_type => |anon_struct| anon_struct.names[field_index],
            else => unreachable,
        };
    }

    pub fn structFieldCount(ty: Type, mod: *Module) usize {
        return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
            .struct_type => |struct_type| {
                const struct_obj = mod.structPtrUnwrap(struct_type.index) orelse return 0;
                assert(struct_obj.haveFieldTypes());
                return struct_obj.fields.count();
            },
            .anon_struct_type => |anon_struct| anon_struct.types.len,
            else => unreachable,
        };
    }

    /// Supports structs and unions.
    pub fn structFieldType(ty: Type, index: usize, mod: *Module) Type {
        return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
            .struct_type => |struct_type| {
                const struct_obj = mod.structPtrUnwrap(struct_type.index).?;
                return struct_obj.fields.values()[index].ty;
            },
            .union_type => |union_type| {
                const union_obj = mod.unionPtr(union_type.index);
                return union_obj.fields.values()[index].ty;
            },
            .anon_struct_type => |anon_struct| anon_struct.types[index].toType(),
            else => unreachable,
        };
    }

    pub fn structFieldAlign(ty: Type, index: usize, mod: *Module) u32 {
        switch (mod.intern_pool.indexToKey(ty.toIntern())) {
            .struct_type => |struct_type| {
                const struct_obj = mod.structPtrUnwrap(struct_type.index).?;
                assert(struct_obj.layout != .Packed);
                return struct_obj.fields.values()[index].alignment(mod, struct_obj.layout);
            },
            .anon_struct_type => |anon_struct| {
                return anon_struct.types[index].toType().abiAlignment(mod);
            },
            .union_type => |union_type| {
                const union_obj = mod.unionPtr(union_type.index);
                return union_obj.fields.values()[index].normalAlignment(mod);
            },
            else => unreachable,
        }
    }

    pub fn structFieldDefaultValue(ty: Type, index: usize, mod: *Module) Value {
        switch (mod.intern_pool.indexToKey(ty.toIntern())) {
            .struct_type => |struct_type| {
                const struct_obj = mod.structPtrUnwrap(struct_type.index).?;
                const val = struct_obj.fields.values()[index].default_val;
                // TODO: avoid using `unreachable` to indicate this.
                if (val == .none) return Value.@"unreachable";
                return val.toValue();
            },
            .anon_struct_type => |anon_struct| {
                const val = anon_struct.values[index];
                // TODO: avoid using `unreachable` to indicate this.
                if (val == .none) return Value.@"unreachable";
                return val.toValue();
            },
            else => unreachable,
        }
    }

    pub fn structFieldValueComptime(ty: Type, mod: *Module, index: usize) !?Value {
        switch (mod.intern_pool.indexToKey(ty.toIntern())) {
            .struct_type => |struct_type| {
                const struct_obj = mod.structPtrUnwrap(struct_type.index).?;
                const field = struct_obj.fields.values()[index];
                if (field.is_comptime) {
                    return field.default_val.toValue();
                } else {
                    return field.ty.onePossibleValue(mod);
                }
            },
            .anon_struct_type => |tuple| {
                const val = tuple.values[index];
                if (val == .none) {
                    return tuple.types[index].toType().onePossibleValue(mod);
                } else {
                    return val.toValue();
                }
            },
            else => unreachable,
        }
    }

    pub fn structFieldIsComptime(ty: Type, index: usize, mod: *Module) bool {
        return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
            .struct_type => |struct_type| {
                const struct_obj = mod.structPtrUnwrap(struct_type.index).?;
                if (struct_obj.layout == .Packed) return false;
                const field = struct_obj.fields.values()[index];
                return field.is_comptime;
            },
            .anon_struct_type => |anon_struct| anon_struct.values[index] != .none,
            else => unreachable,
        };
    }

    pub fn packedStructFieldByteOffset(ty: Type, field_index: usize, mod: *Module) u32 {
        const struct_type = mod.intern_pool.indexToKey(ty.toIntern()).struct_type;
        const struct_obj = mod.structPtrUnwrap(struct_type.index).?;
        assert(struct_obj.layout == .Packed);
        comptime assert(Type.packed_struct_layout_version == 2);

        var bit_offset: u16 = undefined;
        var elem_size_bits: u16 = undefined;
        var running_bits: u16 = 0;
        for (struct_obj.fields.values(), 0..) |f, i| {
            if (!f.ty.hasRuntimeBits(mod)) continue;

            const field_bits = @intCast(u16, f.ty.bitSize(mod));
            if (i == field_index) {
                bit_offset = running_bits;
                elem_size_bits = field_bits;
            }
            running_bits += field_bits;
        }
        const byte_offset = bit_offset / 8;
        return byte_offset;
    }

    pub const FieldOffset = struct {
        field: usize,
        offset: u64,
    };

    pub const StructOffsetIterator = struct {
        field: usize = 0,
        offset: u64 = 0,
        big_align: u32 = 0,
        struct_obj: *Module.Struct,
        module: *Module,

        pub fn next(it: *StructOffsetIterator) ?FieldOffset {
            const mod = it.module;
            var i = it.field;
            if (it.struct_obj.fields.count() <= i)
                return null;

            if (it.struct_obj.optimized_order) |some| {
                i = some[i];
                if (i == Module.Struct.omitted_field) return null;
            }
            const field = it.struct_obj.fields.values()[i];
            it.field += 1;

            if (field.is_comptime or !field.ty.hasRuntimeBits(mod)) {
                return FieldOffset{ .field = i, .offset = it.offset };
            }

            const field_align = field.alignment(mod, it.struct_obj.layout);
            it.big_align = @max(it.big_align, field_align);
            const field_offset = std.mem.alignForward(u64, it.offset, field_align);
            it.offset = field_offset + field.ty.abiSize(mod);
            return FieldOffset{ .field = i, .offset = field_offset };
        }
    };

    /// Get an iterator that iterates over all the struct field, returning the field and
    /// offset of that field. Asserts that the type is a non-packed struct.
    pub fn iterateStructOffsets(ty: Type, mod: *Module) StructOffsetIterator {
        const struct_type = mod.intern_pool.indexToKey(ty.toIntern()).struct_type;
        const struct_obj = mod.structPtrUnwrap(struct_type.index).?;
        assert(struct_obj.haveLayout());
        assert(struct_obj.layout != .Packed);
        return .{ .struct_obj = struct_obj, .module = mod };
    }

    /// Supports structs and unions.
    pub fn structFieldOffset(ty: Type, index: usize, mod: *Module) u64 {
        switch (mod.intern_pool.indexToKey(ty.toIntern())) {
            .struct_type => |struct_type| {
                const struct_obj = mod.structPtrUnwrap(struct_type.index).?;
                assert(struct_obj.haveLayout());
                assert(struct_obj.layout != .Packed);
                var it = ty.iterateStructOffsets(mod);
                while (it.next()) |field_offset| {
                    if (index == field_offset.field)
                        return field_offset.offset;
                }

                return std.mem.alignForward(u64, it.offset, @max(it.big_align, 1));
            },

            .anon_struct_type => |tuple| {
                var offset: u64 = 0;
                var big_align: u32 = 0;

                for (tuple.types, tuple.values, 0..) |field_ty, field_val, i| {
                    if (field_val != .none or !field_ty.toType().hasRuntimeBits(mod)) {
                        // comptime field
                        if (i == index) return offset;
                        continue;
                    }

                    const field_align = field_ty.toType().abiAlignment(mod);
                    big_align = @max(big_align, field_align);
                    offset = std.mem.alignForward(u64, offset, field_align);
                    if (i == index) return offset;
                    offset += field_ty.toType().abiSize(mod);
                }
                offset = std.mem.alignForward(u64, offset, @max(big_align, 1));
                return offset;
            },

            .union_type => |union_type| {
                if (!union_type.hasTag())
                    return 0;
                const union_obj = mod.unionPtr(union_type.index);
                const layout = union_obj.getLayout(mod, true);
                if (layout.tag_align >= layout.payload_align) {
                    // {Tag, Payload}
                    return std.mem.alignForward(u64, layout.tag_size, layout.payload_align);
                } else {
                    // {Payload, Tag}
                    return 0;
                }
            },

            else => unreachable,
        }
    }

    pub fn declSrcLoc(ty: Type, mod: *Module) Module.SrcLoc {
        return declSrcLocOrNull(ty, mod).?;
    }

    pub fn declSrcLocOrNull(ty: Type, mod: *Module) ?Module.SrcLoc {
        return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
            .struct_type => |struct_type| {
                const struct_obj = mod.structPtrUnwrap(struct_type.index).?;
                return struct_obj.srcLoc(mod);
            },
            .union_type => |union_type| {
                const union_obj = mod.unionPtr(union_type.index);
                return union_obj.srcLoc(mod);
            },
            .opaque_type => |opaque_type| mod.opaqueSrcLoc(opaque_type),
            .enum_type => |enum_type| mod.declPtr(enum_type.decl).srcLoc(mod),
            else => null,
        };
    }

    pub fn getOwnerDecl(ty: Type, mod: *Module) Module.Decl.Index {
        return ty.getOwnerDeclOrNull(mod) orelse unreachable;
    }

    pub fn getOwnerDeclOrNull(ty: Type, mod: *Module) ?Module.Decl.Index {
        return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
            .struct_type => |struct_type| {
                const struct_obj = mod.structPtrUnwrap(struct_type.index) orelse return null;
                return struct_obj.owner_decl;
            },
            .union_type => |union_type| {
                const union_obj = mod.unionPtr(union_type.index);
                return union_obj.owner_decl;
            },
            .opaque_type => |opaque_type| opaque_type.decl,
            .enum_type => |enum_type| enum_type.decl,
            else => null,
        };
    }

    pub fn isGenericPoison(ty: Type) bool {
        return ty.toIntern() == .generic_poison_type;
    }

    pub fn isTuple(ty: Type, mod: *Module) bool {
        return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
            .struct_type => |struct_type| {
                const struct_obj = mod.structPtrUnwrap(struct_type.index) orelse return false;
                return struct_obj.is_tuple;
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
        return switch (mod.intern_pool.indexToKey(ty.toIntern())) {
            .struct_type => |struct_type| {
                const struct_obj = mod.structPtrUnwrap(struct_type.index) orelse return false;
                return struct_obj.is_tuple;
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

    pub const err_int = Type.u16;

    pub fn smallestUnsignedBits(max: u64) u16 {
        if (max == 0) return 0;
        const base = std.math.log2(max);
        const upper = (@as(u64, 1) << @intCast(u6, base)) - 1;
        return @intCast(u16, base + @intFromBool(upper < max));
    }

    /// This is only used for comptime asserts. Bump this number when you make a change
    /// to packed struct layout to find out all the places in the codebase you need to edit!
    pub const packed_struct_layout_version = 2;
};
