pub const std = @import("std");

const Attribute = @import("Attribute.zig");
const Compilation = @import("Compilation.zig");
const LangOpts = @import("LangOpts.zig");
const record_layout = @import("record_layout.zig");
const Parser = @import("Parser.zig");
const StringInterner = @import("StringInterner.zig");
const StringId = StringInterner.StringId;
const Tree = @import("Tree.zig");
const Node = Tree.Node;
const TokenIndex = Tree.TokenIndex;

const Repr = struct {
    tag: Tag,
    /// If a Type has a child type it is stored in data[0].
    data: [2]u32,

    pub const Tag = enum(u8) {
        complex,
        bit_int,
        atomic,
        func,
        func_variadic,
        func_old_style,
        func_zero,
        func_variadic_zero,
        func_old_style_zero,
        func_one,
        func_variadic_one,
        func_old_style_one,
        pointer,
        pointer_decayed,
        array_incomplete,
        array_fixed,
        array_static,
        array_variable,
        array_unspecified_variable,
        vector,
        @"struct",
        struct_incomplete,
        @"union",
        union_incomplete,
        @"enum",
        enum_fixed,
        enum_incomplete,
        enum_incomplete_fixed,
        typeof,
        typeof_expr,
        typedef,
        attributed,
        attributed_one,
    };
};

const Index = enum(u29) {
    /// A NaN-like poison value
    /// Can only be nested in function types.
    invalid = std.math.maxInt(u29) - 0,
    /// GNU auto type
    /// This is a placeholder specifier - it must be replaced by the actual type specifier (determined by the initializer)
    /// Must *NOT* be nested.
    auto_type = std.math.maxInt(u29) - 1,
    /// C23 auto, behaves like auto_type
    /// Must *NOT* be nested.
    c23_auto = std.math.maxInt(u29) - 2,
    void = std.math.maxInt(u29) - 3,
    bool = std.math.maxInt(u29) - 4,
    nullptr_t = std.math.maxInt(u29) - 5,
    int_char = std.math.maxInt(u29) - 6,
    int_schar = std.math.maxInt(u29) - 7,
    int_uchar = std.math.maxInt(u29) - 8,
    int_short = std.math.maxInt(u29) - 9,
    int_ushort = std.math.maxInt(u29) - 10,
    int_int = std.math.maxInt(u29) - 11,
    int_uint = std.math.maxInt(u29) - 12,
    int_long = std.math.maxInt(u29) - 13,
    int_ulong = std.math.maxInt(u29) - 14,
    int_long_long = std.math.maxInt(u29) - 15,
    int_ulong_long = std.math.maxInt(u29) - 16,
    int_int128 = std.math.maxInt(u29) - 17,
    int_uint128 = std.math.maxInt(u29) - 18,
    float_fp16 = std.math.maxInt(u29) - 19,
    float_float16 = std.math.maxInt(u29) - 20,
    float_float = std.math.maxInt(u29) - 21,
    float_double = std.math.maxInt(u29) - 22,
    float_long_double = std.math.maxInt(u29) - 23,
    float_float128 = std.math.maxInt(u29) - 24,
    void_pointer = std.math.maxInt(u29) - 25,
    char_pointer = std.math.maxInt(u29) - 26,
    int_pointer = std.math.maxInt(u29) - 27,
    /// Special type used when combining declarators.
    declarator_combine = std.math.maxInt(u29) - 28,
    float_bf16 = std.math.maxInt(u29) - 29,
    float_float32 = std.math.maxInt(u29) - 30,
    float_float64 = std.math.maxInt(u29) - 31,
    float_float32x = std.math.maxInt(u29) - 32,
    float_float64x = std.math.maxInt(u29) - 33,
    float_float128x = std.math.maxInt(u29) - 34,
    float_dfloat32 = std.math.maxInt(u29) - 35,
    float_dfloat64 = std.math.maxInt(u29) - 36,
    float_dfloat128 = std.math.maxInt(u29) - 37,
    float_dfloat64x = std.math.maxInt(u29) - 38,
    _,
};

const TypeStore = @This();

pub const QualType = packed struct(u32) {
    @"const": bool = false,
    @"volatile": bool = false,
    restrict: bool = false,

    _index: Index,

    pub const invalid: QualType = .{ ._index = .invalid };
    pub const auto_type: QualType = .{ ._index = .auto_type };
    pub const c23_auto: QualType = .{ ._index = .c23_auto };
    pub const @"void": QualType = .{ ._index = .void };
    pub const @"bool": QualType = .{ ._index = .bool };
    pub const nullptr_t: QualType = .{ ._index = .nullptr_t };
    pub const char: QualType = .{ ._index = .int_char };
    pub const schar: QualType = .{ ._index = .int_schar };
    pub const uchar: QualType = .{ ._index = .int_uchar };
    pub const short: QualType = .{ ._index = .int_short };
    pub const ushort: QualType = .{ ._index = .int_ushort };
    pub const int: QualType = .{ ._index = .int_int };
    pub const uint: QualType = .{ ._index = .int_uint };
    pub const long: QualType = .{ ._index = .int_long };
    pub const ulong: QualType = .{ ._index = .int_ulong };
    pub const long_long: QualType = .{ ._index = .int_long_long };
    pub const ulong_long: QualType = .{ ._index = .int_ulong_long };
    pub const int128: QualType = .{ ._index = .int_int128 };
    pub const uint128: QualType = .{ ._index = .int_uint128 };
    pub const bf16: QualType = .{ ._index = .float_bf16 };
    pub const fp16: QualType = .{ ._index = .float_fp16 };
    pub const float16: QualType = .{ ._index = .float_float16 };
    pub const float: QualType = .{ ._index = .float_float };
    pub const double: QualType = .{ ._index = .float_double };
    pub const long_double: QualType = .{ ._index = .float_long_double };
    pub const float128: QualType = .{ ._index = .float_float128 };
    pub const float32: QualType = .{ ._index = .float_float32 };
    pub const float64: QualType = .{ ._index = .float_float64 };
    pub const float32x: QualType = .{ ._index = .float_float32x };
    pub const float64x: QualType = .{ ._index = .float_float64x };
    pub const float128x: QualType = .{ ._index = .float_float128x };
    pub const dfloat32: QualType = .{ ._index = .float_dfloat32 };
    pub const dfloat64: QualType = .{ ._index = .float_dfloat64 };
    pub const dfloat128: QualType = .{ ._index = .float_dfloat128 };
    pub const dfloat64x: QualType = .{ ._index = .float_dfloat64x };
    pub const void_pointer: QualType = .{ ._index = .void_pointer };
    pub const char_pointer: QualType = .{ ._index = .char_pointer };
    pub const int_pointer: QualType = .{ ._index = .int_pointer };

    pub fn isInvalid(qt: QualType) bool {
        return qt._index == .invalid;
    }

    pub fn isAutoType(qt: QualType) bool {
        return qt._index == .auto_type;
    }

    pub fn isC23Auto(qt: QualType) bool {
        return qt._index == .c23_auto;
    }

    pub fn isQualified(qt: QualType) bool {
        return qt.@"const" or qt.@"volatile" or qt.restrict;
    }

    pub fn unqualified(qt: QualType) QualType {
        return .{ ._index = qt._index };
    }

    pub fn withQualifiers(target: QualType, quals_from: QualType) QualType {
        return .{
            ._index = target._index,
            .@"const" = quals_from.@"const",
            .@"volatile" = quals_from.@"volatile",
            .restrict = quals_from.restrict,
        };
    }

    pub fn @"type"(qt: QualType, comp: *const Compilation) Type {
        switch (qt._index) {
            .invalid => unreachable,
            .auto_type => unreachable,
            .c23_auto => unreachable,
            .declarator_combine => unreachable,
            .void => return .void,
            .bool => return .bool,
            .nullptr_t => return .nullptr_t,
            .int_char => return .{ .int = .char },
            .int_schar => return .{ .int = .schar },
            .int_uchar => return .{ .int = .uchar },
            .int_short => return .{ .int = .short },
            .int_ushort => return .{ .int = .ushort },
            .int_int => return .{ .int = .int },
            .int_uint => return .{ .int = .uint },
            .int_long => return .{ .int = .long },
            .int_ulong => return .{ .int = .ulong },
            .int_long_long => return .{ .int = .long_long },
            .int_ulong_long => return .{ .int = .ulong_long },
            .int_int128 => return .{ .int = .int128 },
            .int_uint128 => return .{ .int = .uint128 },
            .float_bf16 => return .{ .float = .bf16 },
            .float_fp16 => return .{ .float = .fp16 },
            .float_float16 => return .{ .float = .float16 },
            .float_float => return .{ .float = .float },
            .float_double => return .{ .float = .double },
            .float_long_double => return .{ .float = .long_double },
            .float_float128 => return .{ .float = .float128 },
            .float_float32 => return .{ .float = .float32 },
            .float_float64 => return .{ .float = .float64 },
            .float_float32x => return .{ .float = .float32x },
            .float_float64x => return .{ .float = .float64x },
            .float_float128x => return .{ .float = .float128x },
            .float_dfloat32 => return .{ .float = .dfloat32 },
            .float_dfloat64 => return .{ .float = .dfloat64 },
            .float_dfloat128 => return .{ .float = .dfloat128 },
            .float_dfloat64x => return .{ .float = .dfloat64x },
            .void_pointer => return .{ .pointer = .{ .child = .void, .decayed = null } },
            .char_pointer => return .{ .pointer = .{ .child = .char, .decayed = null } },
            .int_pointer => return .{ .pointer = .{ .child = .int, .decayed = null } },

            else => {},
        }

        const repr = comp.type_store.types.get(@intFromEnum(qt._index));
        return switch (repr.tag) {
            .complex => .{ .complex = @bitCast(repr.data[0]) },
            .atomic => .{ .atomic = @bitCast(repr.data[0]) },
            .bit_int => .{ .bit_int = .{
                .bits = @intCast(repr.data[0]),
                .signedness = @enumFromInt(repr.data[1]),
            } },
            .func_zero => .{ .func = .{
                .return_type = @bitCast(repr.data[0]),
                .kind = .normal,
                .params = &.{},
            } },
            .func_variadic_zero => .{ .func = .{
                .return_type = @bitCast(repr.data[0]),
                .kind = .variadic,
                .params = &.{},
            } },
            .func_old_style_zero => .{ .func = .{
                .return_type = @bitCast(repr.data[0]),
                .kind = .old_style,
                .params = &.{},
            } },
            .func_one,
            .func_variadic_one,
            .func_old_style_one,
            .func,
            .func_variadic,
            .func_old_style,
            => {
                const param_size = 4;
                comptime std.debug.assert(@sizeOf(Type.Func.Param) == @sizeOf(u32) * param_size);

                const extra = comp.type_store.extra.items;
                const params_len = switch (repr.tag) {
                    .func_one, .func_variadic_one, .func_old_style_one => 1,
                    .func, .func_variadic, .func_old_style => extra[repr.data[1]],
                    else => unreachable,
                };
                const extra_params = extra[repr.data[1] + @intFromBool(params_len > 1) ..][0 .. params_len * param_size];

                return .{ .func = .{
                    .return_type = @bitCast(repr.data[0]),
                    .kind = switch (repr.tag) {
                        .func_one, .func => .normal,
                        .func_variadic_one, .func_variadic => .variadic,
                        .func_old_style_one, .func_old_style => .old_style,
                        else => unreachable,
                    },
                    .params = std.mem.bytesAsSlice(Type.Func.Param, std.mem.sliceAsBytes(extra_params)),
                } };
            },
            .pointer => .{ .pointer = .{
                .child = @bitCast(repr.data[0]),
                .decayed = null,
            } },
            .pointer_decayed => .{ .pointer = .{
                .child = @bitCast(repr.data[0]),
                .decayed = @bitCast(repr.data[1]),
            } },
            .array_incomplete => .{ .array = .{
                .elem = @bitCast(repr.data[0]),
                .len = .incomplete,
            } },
            .array_fixed => .{ .array = .{
                .elem = @bitCast(repr.data[0]),
                .len = .{ .fixed = @bitCast(comp.type_store.extra.items[repr.data[1]..][0..2].*) },
            } },
            .array_static => .{ .array = .{
                .elem = @bitCast(repr.data[0]),
                .len = .{ .static = @bitCast(comp.type_store.extra.items[repr.data[1]..][0..2].*) },
            } },
            .array_variable => .{ .array = .{
                .elem = @bitCast(repr.data[0]),
                .len = .{ .variable = @enumFromInt(repr.data[1]) },
            } },
            .array_unspecified_variable => .{ .array = .{
                .elem = @bitCast(repr.data[0]),
                .len = .unspecified_variable,
            } },
            .vector => .{ .vector = .{
                .elem = @bitCast(repr.data[0]),
                .len = repr.data[1],
            } },
            .@"struct", .@"union" => {
                const layout_size = 5;
                comptime std.debug.assert(@sizeOf(Type.Record.Layout) == @sizeOf(u32) * layout_size);
                const field_size = 10;
                comptime std.debug.assert(@sizeOf(Type.Record.Field) == @sizeOf(u32) * field_size);

                const extra = comp.type_store.extra.items;
                const layout = @as(*Type.Record.Layout, @ptrCast(extra[repr.data[1] + 1 ..][0..layout_size])).*;
                const fields_len = extra[repr.data[1] + layout_size + 1];
                const extra_fields = extra[repr.data[1] + layout_size + 2 ..][0 .. fields_len * field_size];

                const record: Type.Record = .{
                    .name = @enumFromInt(repr.data[0]),
                    .decl_node = @enumFromInt(extra[repr.data[1]]),
                    .layout = layout,
                    .fields = std.mem.bytesAsSlice(Type.Record.Field, std.mem.sliceAsBytes(extra_fields)),
                };
                return switch (repr.tag) {
                    .@"struct" => .{ .@"struct" = record },
                    .@"union" => .{ .@"union" = record },
                    else => unreachable,
                };
            },
            .struct_incomplete => .{ .@"struct" = .{
                .name = @enumFromInt(repr.data[0]),
                .decl_node = @enumFromInt(repr.data[1]),
                .layout = null,
                .fields = &.{},
            } },
            .union_incomplete => .{ .@"union" = .{
                .name = @enumFromInt(repr.data[0]),
                .decl_node = @enumFromInt(repr.data[1]),
                .layout = null,
                .fields = &.{},
            } },
            .@"enum", .enum_fixed => {
                const extra = comp.type_store.extra.items;
                const field_size = 3;
                comptime std.debug.assert(@sizeOf(Type.Enum.Field) == @sizeOf(u32) * field_size);

                const fields_len = extra[repr.data[1] + 2];
                const extra_fields = extra[repr.data[1] + 3 ..][0 .. fields_len * field_size];

                return .{ .@"enum" = .{
                    .name = @enumFromInt(extra[repr.data[1]]),
                    .decl_node = @enumFromInt(extra[repr.data[1] + 1]),
                    .tag = @bitCast(repr.data[0]),
                    .incomplete = false,
                    .fixed = repr.tag == .enum_fixed,
                    .fields = std.mem.bytesAsSlice(Type.Enum.Field, std.mem.sliceAsBytes(extra_fields)),
                } };
            },
            .enum_incomplete => .{
                .@"enum" = .{
                    .tag = null,
                    .name = @enumFromInt(repr.data[0]),
                    .decl_node = @enumFromInt(repr.data[1]),
                    .incomplete = true,
                    .fixed = false,
                    .fields = &.{},
                },
            },
            .enum_incomplete_fixed => .{
                .@"enum" = .{
                    .tag = @bitCast(repr.data[0]),
                    .name = @enumFromInt(comp.type_store.extra.items[repr.data[1]]),
                    .decl_node = @enumFromInt(comp.type_store.extra.items[repr.data[1] + 1]),
                    .incomplete = true,
                    .fixed = true,
                    .fields = &.{},
                },
            },
            .typeof => .{ .typeof = .{
                .base = @bitCast(repr.data[0]),
                .expr = null,
            } },
            .typeof_expr => .{ .typeof = .{
                .base = @bitCast(repr.data[0]),
                .expr = @enumFromInt(repr.data[1]),
            } },
            .typedef => .{ .typedef = .{
                .base = @bitCast(repr.data[0]),
                .name = @enumFromInt(comp.type_store.extra.items[repr.data[1]]),
                .decl_node = @enumFromInt(comp.type_store.extra.items[repr.data[1] + 1]),
            } },
            .attributed => {
                const extra = comp.type_store.extra.items;
                return .{ .attributed = .{
                    .base = @bitCast(repr.data[0]),
                    .attributes = comp.type_store.attributes.items[extra[repr.data[1]]..][0..extra[repr.data[1] + 1]],
                } };
            },
            .attributed_one => .{ .attributed = .{
                .base = @bitCast(repr.data[0]),
                .attributes = comp.type_store.attributes.items[repr.data[1]..][0..1],
            } },
        };
    }

    pub fn base(qt: QualType, comp: *const Compilation) struct { type: Type, qt: QualType } {
        var cur = qt;
        while (true) switch (cur.type(comp)) {
            .typeof => |typeof| cur = typeof.base,
            .typedef => |typedef| cur = typedef.base,
            .attributed => |attributed| cur = attributed.base,
            else => |ty| return .{ .type = ty, .qt = cur },
        };
    }

    pub fn getRecord(qt: QualType, comp: *const Compilation) ?Type.Record {
        return switch (qt.base(comp).type) {
            .@"struct", .@"union" => |record| record,
            else => null,
        };
    }

    pub fn get(qt: QualType, comp: *const Compilation, comptime tag: std.meta.Tag(Type)) ?@FieldType(Type, @tagName(tag)) {
        comptime std.debug.assert(tag != .typeof and tag != .attributed and tag != .typedef);
        switch (qt._index) {
            .invalid, .auto_type, .c23_auto => return null,
            else => {},
        }

        const base_type = qt.base(comp).type;
        if (base_type == tag) return @field(base_type, @tagName(tag));
        return null;
    }

    pub fn is(qt: QualType, comp: *const Compilation, comptime tag: std.meta.Tag(Type)) bool {
        return qt.get(comp, tag) != null;
    }

    pub fn childType(qt: QualType, comp: *const Compilation) QualType {
        if (qt.isInvalid()) return .invalid;
        return switch (qt.base(comp).type) {
            .complex => |complex| complex,
            .pointer => |pointer| pointer.child,
            .array => |array| array.elem,
            .vector => |vector| vector.elem,
            else => unreachable,
        };
    }

    pub fn arrayLen(qt: QualType, comp: *Compilation) ?u64 {
        const array_type = switch (qt.base(comp).type) {
            .array => |array| array,
            .pointer => |pointer| blk: {
                const decayed = pointer.decayed orelse return null;
                break :blk decayed.get(comp, .array) orelse return null;
            },
            else => return null,
        };
        switch (array_type.len) {
            .fixed, .static => |len| return len,
            else => return null,
        }
    }

    pub const TypeSizeOrder = enum { lt, gt, eq, indeterminate };

    pub fn sizeCompare(a: QualType, b: QualType, comp: *const Compilation) TypeSizeOrder {
        const a_size = a.sizeofOrNull(comp) orelse return .indeterminate;
        const b_size = b.sizeofOrNull(comp) orelse return .indeterminate;
        return switch (std.math.order(a_size, b_size)) {
            .lt => .lt,
            .gt => .gt,
            .eq => .eq,
        };
    }

    /// Size of a type as reported by the sizeof operator.
    pub fn sizeof(qt: QualType, comp: *const Compilation) u64 {
        return qt.sizeofOrNull(comp).?;
    }

    /// Size of a type as reported by the sizeof operator.
    /// Returns null for incomplete types.
    pub fn sizeofOrNull(qt: QualType, comp: *const Compilation) ?u64 {
        if (qt.isInvalid()) return null;
        return loop: switch (qt.base(comp).type) {
            .void => 1,
            .bool => 1,
            .func => 1,
            .nullptr_t, .pointer => comp.target.ptrBitWidth() / 8,
            .int => |int_ty| int_ty.bits(comp) / 8,
            .float => |float_ty| float_ty.bits(comp) / 8,
            .complex => |complex| complex.sizeofOrNull(comp),
            .bit_int => |bit_int| {
                return std.mem.alignForward(u64, (@as(u32, bit_int.bits) + 7) / 8, qt.alignof(comp));
            },
            .atomic => |atomic| atomic.sizeofOrNull(comp),
            .vector => |vector| {
                const elem_size = vector.elem.sizeofOrNull(comp) orelse return null;
                return elem_size * vector.len;
            },
            .array => |array| {
                const len = switch (array.len) {
                    .variable, .unspecified_variable => return null,
                    .incomplete => {
                        return if (comp.langopts.emulate == .msvc) 0 else null;
                    },
                    .fixed, .static => |len| len,
                };
                const elem_size = array.elem.sizeofOrNull(comp) orelse return null;
                const arr_size = elem_size * len;
                if (comp.langopts.emulate == .msvc) {
                    // msvc ignores array type alignment.
                    // Since the size might not be a multiple of the field
                    // alignment, the address of the second element might not be properly aligned
                    // for the field alignment. A flexible array has size 0. See test case 0018.
                    return arr_size;
                } else {
                    return std.mem.alignForward(u64, arr_size, qt.alignof(comp));
                }
            },
            .@"struct", .@"union" => |record| {
                const layout = record.layout orelse return null;
                return layout.size_bits / 8;
            },
            .@"enum" => |enum_ty| {
                const tag = enum_ty.tag orelse return null;
                continue :loop tag.base(comp).type;
            },
            .typeof => unreachable,
            .typedef => unreachable,
            .attributed => unreachable,
        };
    }

    /// Size of type in bits as it would have in a bitfield.
    pub fn bitSizeof(qt: QualType, comp: *const Compilation) u64 {
        return qt.bitSizeofOrNull(comp).?;
    }

    /// Size of type in bits as it would have in a bitfield.
    /// Returns null for incomplete types.
    pub fn bitSizeofOrNull(qt: QualType, comp: *const Compilation) ?u64 {
        if (qt.isInvalid()) return null;
        return loop: switch (qt.base(comp).type) {
            .bool => if (comp.langopts.emulate == .msvc) 8 else 1,
            .bit_int => |bit_int| bit_int.bits,
            .float => |float_ty| float_ty.bits(comp),
            .int => |int_ty| int_ty.bits(comp),
            .nullptr_t, .pointer => comp.target.ptrBitWidth(),
            .atomic => |atomic| continue :loop atomic.base(comp).type,
            .complex => |complex| {
                const child_size = complex.bitSizeofOrNull(comp) orelse return null;
                return child_size * 2;
            },
            else => 8 * (qt.sizeofOrNull(comp) orelse return null),
        };
    }

    pub fn hasIncompleteSize(qt: QualType, comp: *const Compilation) bool {
        if (qt.isInvalid()) return false;
        return switch (qt.base(comp).type) {
            .void => true,
            .array => |array| array.len == .incomplete,
            .@"enum" => |enum_ty| enum_ty.incomplete and !enum_ty.fixed,
            .@"struct", .@"union" => |record| record.layout == null,
            else => false,
        };
    }

    pub fn signedness(qt: QualType, comp: *const Compilation) std.builtin.Signedness {
        return loop: switch (qt.base(comp).type) {
            .complex => |complex| continue :loop complex.base(comp).type,
            .atomic => |atomic| continue :loop atomic.base(comp).type,
            .bool => .unsigned,
            .bit_int => |bit_int| bit_int.signedness,
            .int => |int_ty| switch (int_ty) {
                .char => comp.getCharSignedness(),
                .schar, .short, .int, .long, .long_long, .int128 => .signed,
                .uchar, .ushort, .uint, .ulong, .ulong_long, .uint128 => .unsigned,
            },
            // Pointer values are signed.
            .pointer, .nullptr_t => .signed,
            .@"enum" => .signed,
            else => unreachable,
        };
    }

    /// Size of a type as reported by the alignof operator.
    pub fn alignof(qt: QualType, comp: *const Compilation) u32 {
        if (qt.requestedAlignment(comp)) |requested| request: {
            if (qt.is(comp, .@"enum")) {
                if (comp.langopts.emulate == .gcc) {
                    // gcc does not respect alignment on enums
                    break :request;
                }
            } else if (qt.getRecord(comp)) |record_ty| {
                const layout = record_ty.layout orelse return 0;

                // don't return the attribute for records
                // layout has already accounted for requested alignment
                const computed = @divExact(layout.field_alignment_bits, 8);
                return @max(requested, computed);
            } else if (comp.langopts.emulate == .msvc) {
                const type_align = qt.base(comp).qt.alignof(comp);
                return @max(requested, type_align);
            }
            return requested;
        }

        return loop: switch (qt.base(comp).type) {
            .void => 1,
            .bool => 1,
            .int => |int_ty| switch (int_ty) {
                .char,
                .schar,
                .uchar,
                => 1,
                .short => comp.target.cTypeAlignment(.short),
                .ushort => comp.target.cTypeAlignment(.ushort),
                .int => comp.target.cTypeAlignment(.int),
                .uint => comp.target.cTypeAlignment(.uint),

                .long => comp.target.cTypeAlignment(.long),
                .ulong => comp.target.cTypeAlignment(.ulong),
                .long_long => comp.target.cTypeAlignment(.longlong),
                .ulong_long => comp.target.cTypeAlignment(.ulonglong),
                .int128, .uint128 => if (comp.target.cpu.arch == .s390x and comp.target.os.tag == .linux and comp.target.abi.isGnu()) 8 else 16,
            },
            .float => |float_ty| switch (float_ty) {
                .float => comp.target.cTypeAlignment(.float),
                .double => comp.target.cTypeAlignment(.double),
                .long_double => comp.target.cTypeAlignment(.longdouble),
                .bf16, .fp16, .float16 => 2,
                .float128 => 16,
                .float32 => comp.target.cTypeAlignment(.float),
                .float64 => comp.target.cTypeAlignment(.double),
                .float32x => 8,
                .float64x => 16,
                .float128x => unreachable, // Not supported
                .dfloat32 => 4,
                .dfloat64 => 8,
                .dfloat128 => 16,
                .dfloat64x => 16,
            },
            .bit_int => |bit_int| {
                // https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2709.pdf
                // _BitInt(N) types align with existing calling conventions. They have the same size and alignment as the
                // smallest basic type that can contain them. Types that are larger than __int64_t are conceptually treated
                // as struct of register size chunks. The number of chunks is the smallest number that can contain the type.
                if (bit_int.bits > 64) return 8;
                const basic_type = comp.intLeastN(bit_int.bits, bit_int.signedness);
                return basic_type.alignof(comp);
            },
            .atomic => |atomic| continue :loop atomic.base(comp).type,
            .complex => |complex| continue :loop complex.base(comp).type,

            .pointer, .nullptr_t => switch (comp.target.cpu.arch) {
                .avr => 1,
                else => comp.target.ptrBitWidth() / 8,
            },

            .func => comp.target.defaultFunctionAlignment(),

            .array => |array| continue :loop array.elem.base(comp).type,
            .vector => |vector| continue :loop vector.elem.base(comp).type,

            .@"struct", .@"union" => |record| {
                const layout = record.layout orelse return 0;
                return layout.field_alignment_bits / 8;
            },
            .@"enum" => |enum_ty| {
                const tag = enum_ty.tag orelse return 0;
                continue :loop tag.base(comp).type;
            },
            .typeof => unreachable,
            .typedef => unreachable,
            .attributed => unreachable,
        };
    }

    /// Suffix for integer values of this type
    pub fn intValueSuffix(qt: QualType, comp: *const Compilation) []const u8 {
        return switch (qt.get(comp, .int).?) {
            .short, .int => "",
            .long => "L",
            .long_long => "LL",
            .schar, .uchar, .char => {
                // Only 8-bit char supported currently;
                // TODO: handle platforms with 16-bit int + 16-bit char
                std.debug.assert(qt.sizeof(comp) == 1);
                return "";
            },
            .ushort => {
                if (qt.sizeof(comp) < int.sizeof(comp)) {
                    return "";
                }
                return "U";
            },
            .uint => "U",
            .ulong => "UL",
            .ulong_long => "ULL",
            else => unreachable, // TODO
        };
    }

    /// printf format modifier
    pub fn formatModifier(qt: QualType, comp: *const Compilation) []const u8 {
        return switch (qt.get(comp, .int).?) {
            .schar, .uchar => "hh",
            .short, .ushort => "h",
            .int, .uint => "",
            .long, .ulong => "l",
            .long_long, .ulong_long => "ll",
            else => unreachable, // TODO
        };
    }

    /// Make real int type unsigned.
    /// Discards attributes.
    pub fn makeIntUnsigned(qt: QualType, comp: *Compilation) !QualType {
        switch (qt.base(comp).type) {
            .int => |kind| switch (kind) {
                .char => return .uchar,
                .schar => return .uchar,
                .uchar => return .uchar,
                .short => return .ushort,
                .ushort => return .ushort,
                .int => return .uint,
                .uint => return .uint,
                .long => return .ulong,
                .ulong => return .ulong,
                .long_long => return .ulong_long,
                .ulong_long => return .ulong_long,
                .int128 => return .uint128,
                .uint128 => return .uint128,
            },
            .bit_int => |bit_int| {
                return try comp.type_store.put(comp.gpa, .{ .bit_int = .{
                    .signedness = .unsigned,
                    .bits = bit_int.bits,
                } });
            },
            else => unreachable,
        }
    }

    pub fn toReal(qt: QualType, comp: *const Compilation) QualType {
        return switch (qt.base(comp).type) {
            .complex => |complex| complex,
            else => qt,
        };
    }

    pub fn toComplex(qt: QualType, comp: *Compilation) !QualType {
        if (std.debug.runtime_safety) {
            switch (qt.base(comp).type) {
                .complex => unreachable,
                .float => |float_ty| if (float_ty == .fp16) unreachable,
                .int, .bit_int => {},
                else => unreachable,
            }
        }
        return comp.type_store.put(comp.gpa, .{ .complex = qt });
    }

    pub fn decay(qt: QualType, comp: *Compilation) !QualType {
        if (qt.isInvalid()) return .invalid;
        switch (qt.base(comp).type) {
            .array => |array_ty| {
                // Copy const and volatile to the element
                var elem_qt = array_ty.elem;
                elem_qt.@"const" = qt.@"const" or elem_qt.@"const";
                elem_qt.@"volatile" = qt.@"volatile" or elem_qt.@"volatile";

                var pointer_qt = try comp.type_store.put(comp.gpa, .{ .pointer = .{
                    .child = elem_qt,
                    .decayed = qt,
                } });

                // .. and restrict to the pointer.
                pointer_qt.restrict = qt.restrict or array_ty.elem.restrict;
                return pointer_qt;
            },
            .func => |func_ty| {
                if (func_ty.return_type.isInvalid()) {
                    return .invalid;
                }
                for (func_ty.params) |param| {
                    if (param.qt.isInvalid()) {
                        return .invalid;
                    }
                }

                return comp.type_store.put(comp.gpa, .{ .pointer = .{
                    .child = qt,
                    .decayed = null,
                } });
            },
            else => return qt,
        }
    }

    /// Rank for floating point conversions, ignoring domain (complex vs real)
    /// Asserts that ty is a floating point type
    pub fn floatRank(qt: QualType, comp: *const Compilation) usize {
        return loop: switch (qt.base(comp).type) {
            .float => |float_ty| switch (float_ty) {
                .bf16 => 0,
                .float16 => 1,
                .fp16 => 2,
                .float => 3,
                .float32 => 4,
                .float32x => 5,
                .double => 6,
                .float64 => 7,
                .float64x => 8,
                .long_double => 9,
                .float128 => 10,
                // TODO: ibm128 => 7
                .float128x => unreachable, // Not supported
                .dfloat32 => decimal_float_rank + 0,
                .dfloat64 => decimal_float_rank + 1,
                .dfloat64x => decimal_float_rank + 2,
                .dfloat128 => decimal_float_rank + 3,
            },
            .complex => |complex| continue :loop complex.base(comp).type,
            .atomic => |atomic| continue :loop atomic.base(comp).type,
            else => unreachable,
        };
    }

    pub const decimal_float_rank = 90;

    /// Rank for integer conversions, ignoring domain (complex vs real)
    /// Asserts that ty is an integer type
    pub fn intRank(qt: QualType, comp: *const Compilation) usize {
        return loop: switch (qt.base(comp).type) {
            .bit_int => |bit_int| @as(usize, bit_int.bits) * 8,
            .bool => 1 + @as(usize, @intCast((QualType.bool.bitSizeof(comp) * 8))),
            .int => |int_ty| switch (int_ty) {
                .char, .schar, .uchar => 2 + (int_ty.bits(comp) * 8),
                .short, .ushort => 3 + (int_ty.bits(comp) * 8),
                .int, .uint => 4 + (int_ty.bits(comp) * 8),
                .long, .ulong => 5 + (int_ty.bits(comp) * 8),
                .long_long, .ulong_long => 6 + (int_ty.bits(comp) * 8),
                .int128, .uint128 => 7 + (int_ty.bits(comp) * 8),
            },
            .complex => |complex| continue :loop complex.base(comp).type,
            .atomic => |atomic| continue :loop atomic.base(comp).type,
            .@"enum" => |enum_ty| continue :loop enum_ty.tag.?.base(comp).type,
            else => unreachable,
        };
    }

    pub fn intRankOrder(a: QualType, b: QualType, comp: *const Compilation) std.math.Order {
        std.debug.assert(a.isInt(comp) and b.isInt(comp));

        const a_unsigned = a.signedness(comp) == .unsigned;
        const b_unsigned = b.signedness(comp) == .unsigned;

        const a_rank = a.intRank(comp);
        const b_rank = b.intRank(comp);
        if (a_unsigned == b_unsigned) {
            return std.math.order(a_rank, b_rank);
        }
        if (a_unsigned) {
            if (a_rank >= b_rank) return .gt;
            return .lt;
        }
        std.debug.assert(b_unsigned);
        if (b_rank >= a_rank) return .lt;
        return .gt;
    }

    /// Returns true if `a` and `b` are integer types that differ only in sign
    pub fn sameRankDifferentSign(a: QualType, b: QualType, comp: *const Compilation) bool {
        if (!a.isInt(comp) or !b.isInt(comp)) return false;
        if (a.hasIncompleteSize(comp) or b.hasIncompleteSize(comp)) return false;
        if (a.intRank(comp) != b.intRank(comp)) return false;
        return a.signedness(comp) != b.signedness(comp);
    }

    pub fn promoteInt(qt: QualType, comp: *const Compilation) QualType {
        return loop: switch (qt.base(comp).type) {
            .bool => return .int,
            .@"enum" => |enum_ty| if (enum_ty.tag) |tag| {
                continue :loop tag.base(comp).type;
            } else return .int,
            .bit_int => return qt,
            .complex => return qt, // Assume complex integer type
            .int => |int_ty| switch (int_ty) {
                .char, .schar, .uchar, .short => .int,
                .ushort => if (Type.Int.uchar.bits(comp) == Type.Int.int.bits(comp)) .uint else .int,
                else => return qt,
            },
            .atomic => |atomic| continue :loop atomic.base(comp).type,
            else => unreachable, // Not an integer type
        };
    }

    /// Promote a bitfield. If `int` can hold all the values of the underlying field,
    /// promote to int. Otherwise, promote to unsigned int
    /// Returns null if no promotion is necessary
    pub fn promoteBitfield(qt: QualType, comp: *const Compilation, width: u32) ?QualType {
        const type_size_bits = qt.bitSizeof(comp);

        // Note: GCC and clang will promote `long: 3` to int even though the C standard does not allow this
        if (width < type_size_bits) {
            return .int;
        }

        if (width == type_size_bits) {
            return if (qt.signedness(comp) == .unsigned) .uint else .int;
        }

        return null;
    }

    pub const ScalarKind = enum {
        @"enum",
        bool,
        int,
        float,
        pointer,
        nullptr_t,
        void_pointer,
        complex_int,
        complex_float,
        none,

        pub fn isInt(sk: ScalarKind) bool {
            return switch (sk) {
                .bool, .@"enum", .int, .complex_int => true,
                else => false,
            };
        }

        pub fn isFloat(sk: ScalarKind) bool {
            return switch (sk) {
                .float, .complex_float => true,
                else => false,
            };
        }

        pub fn isReal(sk: ScalarKind) bool {
            return switch (sk) {
                .complex_int, .complex_float => false,
                else => true,
            };
        }

        pub fn isPointer(sk: ScalarKind) bool {
            return switch (sk) {
                .pointer, .void_pointer => true,
                else => false,
            };
        }

        /// Equivalent to isInt() or isFloat()
        pub fn isArithmetic(sk: ScalarKind) bool {
            return switch (sk) {
                .bool, .@"enum", .int, .complex_int, .float, .complex_float => true,
                else => false,
            };
        }
    };

    pub fn scalarKind(qt: QualType, comp: *const Compilation) ScalarKind {
        loop: switch (qt.base(comp).type) {
            .bool => return .bool,
            .int, .bit_int => return .int,
            .float => return .float,
            .nullptr_t => return .nullptr_t,
            .pointer => |pointer| switch (pointer.child.base(comp).type) {
                .void => return .void_pointer,
                else => return .pointer,
            },
            .@"enum" => return .@"enum",
            .complex => |complex| switch (complex.base(comp).type) {
                .int, .bit_int => return .complex_int,
                .float => return .complex_float,
                else => unreachable,
            },
            .atomic => |atomic| continue :loop atomic.base(comp).type,
            else => return .none,
        }
    }

    // Prefer calling scalarKind directly if checking multiple kinds.
    pub fn isInt(qt: QualType, comp: *const Compilation) bool {
        return qt.scalarKind(comp).isInt();
    }

    pub fn isRealInt(qt: QualType, comp: *const Compilation) bool {
        const sk = qt.scalarKind(comp);
        return sk.isInt() and sk.isReal();
    }

    // Prefer calling scalarKind directly if checking multiple kinds.
    pub fn isFloat(qt: QualType, comp: *const Compilation) bool {
        return qt.scalarKind(comp).isFloat();
    }

    // Prefer calling scalarKind directly if checking multiple kinds.
    pub fn isPointer(qt: QualType, comp: *const Compilation) bool {
        return qt.scalarKind(comp).isPointer();
    }

    pub fn eqlQualified(a_qt: QualType, b_qt: QualType, comp: *const Compilation) bool {
        if (a_qt.@"const" != b_qt.@"const") return false;
        if (a_qt.@"volatile" != b_qt.@"volatile") return false;
        if (a_qt.restrict != b_qt.restrict) return false;

        return a_qt.eql(b_qt, comp);
    }

    pub fn eql(a_qt: QualType, b_qt: QualType, comp: *const Compilation) bool {
        if (a_qt.isInvalid() or b_qt.isInvalid()) return false;
        if (a_qt._index == b_qt._index) return true;

        const a_type_qt = a_qt.base(comp);
        const a_type = a_type_qt.type;
        const b_type_qt = b_qt.base(comp);
        const b_type = b_type_qt.type;

        // Alignment check also guards against comparing incomplete enums to ints.
        if (a_type_qt.qt.alignof(comp) != b_type_qt.qt.alignof(comp)) return false;
        if (a_type == .@"enum" and b_type != .@"enum") {
            return a_type.@"enum".tag.?.eql(b_qt, comp);
        } else if (a_type != .@"enum" and b_type == .@"enum") {
            return b_type.@"enum".tag.?.eql(a_qt, comp);
        }

        if (std.meta.activeTag(a_type) != b_type) return false;
        switch (a_type) {
            .void => return true,
            .bool => return true,
            .nullptr_t => return true,
            .int => |a_int| return a_int == b_type.int,
            .float => |a_float| return a_float == b_type.float,
            .complex => |a_complex| {
                const b_complex = b_type.complex;
                // Complex child type cannot be qualified.
                return a_complex.eql(b_complex, comp);
            },
            .bit_int => |a_bit_int| {
                const b_bit_int = b_type.bit_int;
                if (a_bit_int.bits != b_bit_int.bits) return false;
                if (a_bit_int.signedness != b_bit_int.signedness) return false;
                return true;
            },
            .atomic => |a_atomic| {
                const b_atomic = b_type.atomic;
                // Atomic child type cannot be qualified.
                return a_atomic.eql(b_atomic, comp);
            },
            .func => |a_func| {
                const b_func = b_type.func;

                // Function return type cannot be qualified.
                if (!a_func.return_type.eql(b_func.return_type, comp)) return false;

                if (a_func.params.len == 0 and b_func.params.len == 0) {
                    return (a_func.kind == .variadic) == (b_func.kind == .variadic);
                }

                if (a_func.params.len != b_func.params.len) {
                    if (a_func.kind == .old_style and b_func.kind == .old_style) return true;
                    if (a_func.kind == .old_style or b_func.kind == .old_style) {
                        const maybe_has_params = if (a_func.kind == .old_style) b_func else a_func;

                        // Check if any args undergo default argument promotion.
                        for (maybe_has_params.params) |param| {
                            switch (param.qt.base(comp).type) {
                                .bool => return false,
                                .int => |int_ty| switch (int_ty) {
                                    .char, .uchar, .schar => return false,
                                    else => {},
                                },
                                .float => |float_ty| if (float_ty != .double) return false,
                                .@"enum" => |enum_ty| {
                                    if (comp.langopts.emulate == .clang and enum_ty.incomplete) return false;
                                },
                                else => {},
                            }
                        }
                        return true;
                    }
                    return false;
                }

                if ((a_func.kind == .normal) != (b_func.kind == .normal)) return false;

                for (a_func.params, b_func.params) |a_param, b_param| {
                    // Function parameters cannot be qualified.
                    if (!a_param.qt.eql(b_param.qt, comp)) return false;
                }
                return true;
            },
            .pointer => |a_pointer| {
                const b_pointer = b_type.pointer;
                return a_pointer.child.eqlQualified(b_pointer.child, comp);
            },
            .array => |a_array| {
                const b_array = b_type.array;
                const a_len = switch (a_array.len) {
                    .fixed, .static => |len| len,
                    else => null,
                };
                const b_len = switch (b_array.len) {
                    .fixed, .static => |len| len,
                    else => null,
                };
                if (a_len != null and b_len != null) {
                    return a_len.? == b_len.?;
                }

                // Array element qualifiers are ignored.
                return a_array.elem.eql(b_array.elem, comp);
            },
            .vector => |a_vector| {
                const b_vector = b_type.vector;
                if (a_vector.len != b_vector.len) return false;

                // Vector elemnent qualifiers are checked.
                return a_vector.elem.eqlQualified(b_vector.elem, comp);
            },
            .@"struct", .@"union", .@"enum" => return a_type_qt.qt._index == b_type_qt.qt._index,

            .typeof => unreachable, // Never returned from base()
            .typedef => unreachable, // Never returned from base()
            .attributed => unreachable, // Never returned from base()
        }
    }

    pub fn getAttribute(qt: QualType, comp: *const Compilation, comptime tag: Attribute.Tag) ?Attribute.ArgumentsForTag(tag) {
        if (tag == .aligned) @compileError("use requestedAlignment");
        var it = Attribute.Iterator.initType(qt, comp);
        while (it.next()) |item| {
            const attribute, _ = item;
            if (attribute.tag == tag) return @field(attribute.args, @tagName(tag));
        }
        return null;
    }

    pub fn hasAttribute(qt: QualType, comp: *const Compilation, tag: Attribute.Tag) bool {
        var it = Attribute.Iterator.initType(qt, comp);
        while (it.next()) |item| {
            const attr, _ = item;
            if (attr.tag == tag) return true;
        }
        return false;
    }

    pub fn alignable(qt: QualType, comp: *const Compilation) bool {
        if (qt.isInvalid()) return true; // Avoid redundant error.
        const base_type = qt.base(comp);
        return switch (base_type.type) {
            .array, .void => false,
            else => !base_type.qt.hasIncompleteSize(comp),
        };
    }

    pub fn requestedAlignment(qt: QualType, comp: *const Compilation) ?u32 {
        return annotationAlignment(comp, Attribute.Iterator.initType(qt, comp));
    }

    pub fn annotationAlignment(comp: *const Compilation, attrs: Attribute.Iterator) ?u32 {
        var it = attrs;
        var max_requested: ?u32 = null;
        var last_aligned_index: ?usize = null;
        while (it.next()) |item| {
            const attribute, const index = item;
            if (attribute.tag != .aligned) continue;
            if (last_aligned_index) |aligned_index| {
                // once we recurse into a new type, after an `aligned` attribute was found, we're done
                if (index <= aligned_index) break;
            }
            last_aligned_index = index;
            const requested = if (attribute.args.aligned.alignment) |alignment| alignment.requested else comp.target.defaultAlignment();
            if (max_requested == null or max_requested.? < requested) {
                max_requested = requested;
            }
        }
        return max_requested;
    }

    pub fn linkage(qt: QualType, comp: *const Compilation) std.builtin.GlobalLinkage {
        if (qt.hasAttribute(comp, .internal_linkage)) return .internal;
        if (qt.hasAttribute(comp, .weak)) return .weak;
        if (qt.hasAttribute(comp, .selectany)) return .link_once;
        return .strong;
    }

    pub fn enumIsPacked(qt: QualType, comp: *const Compilation) bool {
        std.debug.assert(qt.is(comp, .@"enum"));
        return comp.langopts.short_enums or comp.target.packAllEnums() or qt.hasAttribute(comp, .@"packed");
    }

    pub fn shouldDesugar(qt: QualType, comp: *const Compilation) bool {
        loop: switch (qt.type(comp)) {
            .attributed => |attributed| continue :loop attributed.base.type(comp),
            .pointer => |pointer| continue :loop pointer.child.type(comp),
            .func => |func| {
                for (func.params) |param| {
                    if (param.qt.shouldDesugar(comp)) return true;
                }
                continue :loop func.return_type.type(comp);
            },
            .typeof => return true,
            .typedef => |typedef| return !typedef.base.is(comp, .nullptr_t),
            else => return false,
        }
    }

    pub fn print(qt: QualType, comp: *const Compilation, w: *std.Io.Writer) std.Io.Writer.Error!void {
        if (qt.isC23Auto()) {
            try w.writeAll("auto");
            return;
        }
        _ = try qt.printPrologue(comp, false, w);
        try qt.printEpilogue(comp, false, w);
    }

    pub fn printNamed(qt: QualType, name: []const u8, comp: *const Compilation, w: *std.Io.Writer) std.Io.Writer.Error!void {
        if (qt.isC23Auto()) {
            try w.print("auto {s}", .{name});
            return;
        }
        const simple = try qt.printPrologue(comp, false, w);
        if (simple) try w.writeByte(' ');
        try w.writeAll(name);
        try qt.printEpilogue(comp, false, w);
    }

    pub fn printDesugared(qt: QualType, comp: *const Compilation, w: *std.Io.Writer) std.Io.Writer.Error!void {
        _ = try qt.printPrologue(comp, true, w);
        try qt.printEpilogue(comp, true, w);
    }

    fn printPrologue(qt: QualType, comp: *const Compilation, desugar: bool, w: *std.Io.Writer) std.Io.Writer.Error!bool {
        loop: switch (qt.type(comp)) {
            .pointer => |pointer| {
                const simple = try pointer.child.printPrologue(comp, desugar, w);
                if (simple) try w.writeByte(' ');
                switch (pointer.child.base(comp).type) {
                    .func, .array => try w.writeByte('('),
                    else => {},
                }
                try w.writeByte('*');
                if (qt.@"const") try w.writeAll("const");
                if (qt.@"volatile") {
                    if (qt.@"const") try w.writeByte(' ');
                    try w.writeAll("volatile");
                }
                if (qt.restrict) {
                    if (qt.@"const" or qt.@"volatile") try w.writeByte(' ');
                    try w.writeAll("restrict");
                }
                return false;
            },
            .func => |func| {
                const simple = try func.return_type.printPrologue(comp, desugar, w);
                if (simple) try w.writeByte(' ');
                return false;
            },
            .array => |array| {
                if (qt.@"const") {
                    try w.writeAll("const ");
                }
                if (qt.@"volatile") {
                    try w.writeAll("volatile");
                }

                const simple = try array.elem.printPrologue(comp, desugar, w);
                if (simple) try w.writeByte(' ');
                return false;
            },
            .typeof => |typeof| if (desugar) {
                continue :loop typeof.base.type(comp);
            } else {
                try w.writeAll("typeof(");
                try typeof.base.print(comp, w);
                try w.writeAll(")");
                return true;
            },
            .typedef => |typedef| if (desugar) {
                continue :loop typedef.base.type(comp);
            } else {
                try w.writeAll(typedef.name.lookup(comp));
                return true;
            },
            .attributed => |attributed| continue :loop attributed.base.type(comp),
            else => {},
        }
        if (qt.@"const") try w.writeAll("const ");
        if (qt.@"volatile") try w.writeAll("volatile ");

        switch (qt.base(comp).type) {
            .pointer => unreachable,
            .func => unreachable,
            .array => unreachable,
            .typeof => unreachable,
            .typedef => unreachable,
            .attributed => unreachable,

            .void => try w.writeAll("void"),
            .bool => try w.writeAll(if (comp.langopts.standard.atLeast(.c23)) "bool" else "_Bool"),
            .nullptr_t => try w.writeAll("nullptr_t"),
            .int => |int_ty| switch (int_ty) {
                .char => try w.writeAll("char"),
                .schar => try w.writeAll("signed char"),
                .uchar => try w.writeAll("unsigned char"),
                .short => try w.writeAll("short"),
                .ushort => try w.writeAll("unsigned short"),
                .int => try w.writeAll("int"),
                .uint => try w.writeAll("unsigned int"),
                .long => try w.writeAll("long"),
                .ulong => try w.writeAll("unsigned long"),
                .long_long => try w.writeAll("long long"),
                .ulong_long => try w.writeAll("unsigned long long"),
                .int128 => try w.writeAll("__int128"),
                .uint128 => try w.writeAll("unsigned __int128"),
            },
            .bit_int => |bit_int| try w.print("{s} _BitInt({d})", .{ @tagName(bit_int.signedness), bit_int.bits }),
            .float => |float_ty| switch (float_ty) {
                .bf16 => try w.writeAll("__bf16"),
                .fp16 => try w.writeAll("__fp16"),
                .float16 => try w.writeAll("_Float16"),
                .float => try w.writeAll("float"),
                .double => try w.writeAll("double"),
                .long_double => try w.writeAll("long double"),
                .float128 => try w.writeAll("__float128"),
                .float32 => try w.writeAll("_Float32"),
                .float64 => try w.writeAll("_Float64"),
                .float32x => try w.writeAll("_Float32x"),
                .float64x => try w.writeAll("_Float64x"),
                .float128x => try w.writeAll("_Float128x"),
                .dfloat32 => try w.writeAll("_Decimal32"),
                .dfloat64 => try w.writeAll("_Decimal64"),
                .dfloat128 => try w.writeAll("_Decimal128"),
                .dfloat64x => try w.writeAll("_Decimal64x"),
            },
            .complex => |complex| {
                try w.writeAll("_Complex ");
                _ = try complex.printPrologue(comp, desugar, w);
            },
            .atomic => |atomic| {
                try w.writeAll("_Atomic(");
                _ = try atomic.printPrologue(comp, desugar, w);
                try atomic.printEpilogue(comp, desugar, w);
                try w.writeAll(")");
            },

            .vector => |vector| {
                try w.print("__attribute__((__vector_size__({d} * sizeof(", .{vector.len});
                _ = try vector.elem.printPrologue(comp, desugar, w);
                try w.writeAll(")))) ");
                _ = try vector.elem.printPrologue(comp, desugar, w);
            },

            .@"struct" => |struct_ty| try w.print("struct {s}", .{struct_ty.name.lookup(comp)}),
            .@"union" => |union_ty| try w.print("union {s}", .{union_ty.name.lookup(comp)}),
            .@"enum" => |enum_ty| if (enum_ty.fixed) {
                try w.print("enum {s}: ", .{enum_ty.name.lookup(comp)});
                _ = try enum_ty.tag.?.printPrologue(comp, desugar, w);
            } else {
                try w.print("enum {s}", .{enum_ty.name.lookup(comp)});
            },
        }
        return true;
    }

    fn printEpilogue(qt: QualType, comp: *const Compilation, desugar: bool, w: *std.Io.Writer) std.Io.Writer.Error!void {
        loop: switch (qt.type(comp)) {
            .pointer => |pointer| {
                switch (pointer.child.base(comp).type) {
                    .func, .array => try w.writeByte(')'),
                    else => {},
                }
                continue :loop pointer.child.type(comp);
            },
            .func => |func| {
                try w.writeByte('(');
                for (func.params, 0..) |param, i| {
                    if (i != 0) try w.writeAll(", ");
                    _ = try param.qt.printPrologue(comp, desugar, w);
                    try param.qt.printEpilogue(comp, desugar, w);
                }
                if (func.kind != .normal) {
                    if (func.params.len != 0) try w.writeAll(", ");
                    try w.writeAll("...");
                } else if (func.params.len == 0 and !comp.langopts.standard.atLeast(.c23)) {
                    try w.writeAll("void");
                }
                try w.writeByte(')');
                continue :loop func.return_type.type(comp);
            },
            .array => |array| {
                try w.writeByte('[');
                switch (array.len) {
                    .fixed, .static => |len| try w.print("{d}", .{len}),
                    .incomplete => {},
                    .unspecified_variable => try w.writeByte('*'),
                    .variable => try w.writeAll("<expr>"),
                }

                const static = array.len == .static;
                if (static) try w.writeAll("static");
                if (qt.restrict) {
                    if (static or qt.@"const" or qt.@"volatile") try w.writeByte(' ');
                    try w.writeAll("restrict");
                }
                try w.writeByte(']');

                continue :loop array.elem.type(comp);
            },
            .attributed => |attributed| continue :loop attributed.base.type(comp),
            else => {},
        }
    }

    pub fn dump(qt: QualType, comp: *const Compilation, w: *std.Io.Writer) std.Io.Writer.Error!void {
        if (qt.@"const") try w.writeAll("const ");
        if (qt.@"volatile") try w.writeAll("volatile ");
        if (qt.restrict) try w.writeAll("restrict ");
        if (qt.isInvalid()) return w.writeAll("invalid");
        switch (qt.type(comp)) {
            .pointer => |pointer| {
                if (pointer.decayed) |decayed| {
                    try w.writeAll("decayed *");
                    try decayed.dump(comp, w);
                } else {
                    try w.writeAll("*");
                    try pointer.child.dump(comp, w);
                }
            },
            .func => |func| {
                if (func.kind == .old_style)
                    try w.writeAll("kr (")
                else
                    try w.writeAll("fn (");

                for (func.params, 0..) |param, i| {
                    if (i != 0) try w.writeAll(", ");
                    if (param.name != .empty) try w.print("{s}: ", .{param.name.lookup(comp)});
                    try param.qt.dump(comp, w);
                }
                if (func.kind != .normal) {
                    if (func.params.len != 0) try w.writeAll(", ");
                    try w.writeAll("...");
                }
                try w.writeAll(") ");
                try func.return_type.dump(comp, w);
            },
            .array => |array| {
                switch (array.len) {
                    .fixed => |len| try w.print("[{d}]", .{len}),
                    .static => |len| try w.print("[static {d}]", .{len}),
                    .incomplete => try w.writeAll("[]"),
                    .unspecified_variable => try w.writeAll("[*]"),
                    .variable => try w.writeAll("[<expr>]"),
                }
                try array.elem.dump(comp, w);
            },
            .vector => |vector| {
                try w.print("vector({d}, ", .{vector.len});
                try vector.elem.dump(comp, w);
                try w.writeAll(")");
            },
            .typeof => |typeof| {
                try w.writeAll("typeof(");
                if (typeof.expr != null) try w.writeAll("<expr>: ");
                try typeof.base.dump(comp, w);
                try w.writeAll(")");
            },
            .attributed => |attributed| {
                try w.writeAll("attributed(");
                try attributed.base.dump(comp, w);
                try w.writeAll(")");
            },
            .typedef => |typedef| {
                try w.writeAll(typedef.name.lookup(comp));
                try w.writeAll(": ");
                try typedef.base.dump(comp, w);
            },
            .@"enum" => |enum_ty| {
                try w.print("enum {s}: ", .{enum_ty.name.lookup(comp)});
                if (enum_ty.tag) |some| {
                    try some.dump(comp, w);
                } else {
                    try w.writeAll("<incomplete>");
                }
            },
            else => try qt.unqualified().print(comp, w),
        }
    }
};

pub const Type = union(enum) {
    void,
    bool,
    /// C23 nullptr_t
    nullptr_t,

    int: Int,
    float: Float,
    complex: QualType,
    bit_int: BitInt,
    atomic: QualType,

    func: Func,
    pointer: Pointer,
    array: Array,
    vector: Vector,

    @"struct": Record,
    @"union": Record,
    @"enum": Enum,

    typeof: TypeOf,
    typedef: TypeDef,
    attributed: Attributed,

    pub const Int = enum {
        char,
        schar,
        uchar,
        short,
        ushort,
        int,
        uint,
        long,
        ulong,
        long_long,
        ulong_long,
        int128,
        uint128,

        pub fn bits(int: Int, comp: *const Compilation) u16 {
            return switch (int) {
                .char => comp.target.cTypeBitSize(.char),
                .schar => comp.target.cTypeBitSize(.char),
                .uchar => comp.target.cTypeBitSize(.char),
                .short => comp.target.cTypeBitSize(.short),
                .ushort => comp.target.cTypeBitSize(.ushort),
                .int => comp.target.cTypeBitSize(.int),
                .uint => comp.target.cTypeBitSize(.uint),
                .long => comp.target.cTypeBitSize(.long),
                .ulong => comp.target.cTypeBitSize(.ulong),
                .long_long => comp.target.cTypeBitSize(.longlong),
                .ulong_long => comp.target.cTypeBitSize(.ulonglong),
                .int128 => 128,
                .uint128 => 128,
            };
        }
    };

    pub const Float = enum {
        bf16,
        fp16,
        float16,
        float,
        double,
        long_double,
        float128,
        float32,
        float64,
        float32x,
        float64x,
        float128x,
        dfloat32,
        dfloat64,
        dfloat128,
        dfloat64x,

        pub fn bits(float: Float, comp: *const Compilation) u16 {
            return switch (float) {
                .bf16 => 16,
                .fp16 => 16,
                .float16 => 16,
                .float => comp.target.cTypeBitSize(.float),
                .double => comp.target.cTypeBitSize(.double),
                .long_double => comp.target.cTypeBitSize(.longdouble),
                .float128 => 128,
                .float32 => 32,
                .float64 => 64,
                .float32x => 32 * 2,
                .float64x => 64 * 2,
                .float128x => unreachable, // Not supported
                .dfloat32 => 32,
                .dfloat64 => 64,
                .dfloat128 => 128,
                .dfloat64x => 64 * 2,
            };
        }
    };

    pub const BitInt = struct {
        /// Must be >= 1 if unsigned and >= 2 if signed
        bits: u16,
        signedness: std.builtin.Signedness,
    };

    pub const Func = struct {
        return_type: QualType,
        kind: enum {
            /// int foo(int bar, char baz) and int (void)
            normal,
            /// int foo(int bar, char baz, ...)
            variadic,
            /// int foo(bar, baz) and int foo()
            /// is also var args, but we can give warnings about incorrect amounts of parameters
            old_style,
        },
        params: []const Param,

        pub const Param = extern struct {
            qt: QualType,
            name: StringId,
            name_tok: TokenIndex,
            node: Node.OptIndex,
        };
    };

    pub const Pointer = struct {
        child: QualType,
        decayed: ?QualType,
    };

    pub const Array = struct {
        elem: QualType,
        len: union(enum) {
            incomplete,
            fixed: u64,
            static: u64,
            variable: Node.Index,
            unspecified_variable,
        },
    };

    pub const Vector = struct {
        elem: QualType,
        len: u32,
    };

    pub const Record = struct {
        name: StringId,
        decl_node: Node.Index,
        layout: ?Layout = null,
        fields: []const Field,

        pub const Field = extern struct {
            qt: QualType,
            name: StringId,
            /// zero for anonymous fields
            name_tok: TokenIndex = 0,
            bit_width: enum(u32) {
                null = std.math.maxInt(u32),
                _,

                pub fn unpack(width: @This()) ?u32 {
                    if (width == .null) return null;
                    return @intFromEnum(width);
                }
            } = .null,
            layout: Field.Layout = .{
                .offset_bits = 0,
                .size_bits = 0,
            },
            _attr_index: u32 = 0,
            _attr_len: u32 = 0,

            pub fn attributes(field: Field, comp: *const Compilation) []const Attribute {
                return comp.type_store.attributes.items[field._attr_index..][0..field._attr_len];
            }

            pub const Layout = extern struct {
                /// `offset_bits` and `size_bits` should both be INVALID if and only if the field
                /// is an unnamed bitfield. There is no way to reference an unnamed bitfield in C, so
                /// there should be no way to observe these values. If it is used, this value will
                /// maximize the chance that a safety-checked overflow will occur.
                const INVALID = std.math.maxInt(u64);

                /// The offset of the field, in bits, from the start of the struct.
                offset_bits: u64 align(4) = INVALID,
                /// The size, in bits, of the field.
                ///
                /// For bit-fields, this is the width of the field.
                size_bits: u64 align(4) = INVALID,
            };
        };

        pub const Layout = extern struct {
            /// The size of the type in bits.
            ///
            /// This is the value returned by `sizeof` in C
            /// (but in bits instead of bytes). This is a multiple of `pointer_alignment_bits`.
            size_bits: u64 align(4),
            /// The alignment of the type, in bits, when used as a field in a record.
            ///
            /// This is usually the value returned by `_Alignof` in C, but there are some edge
            /// cases in GCC where `_Alignof` returns a smaller value.
            field_alignment_bits: u32,
            /// The alignment, in bits, of valid pointers to this type.
            /// `size_bits` is a multiple of this value.
            pointer_alignment_bits: u32,
            /// The required alignment of the type in bits.
            ///
            /// This value is only used by MSVC targets. It is 8 on all other
            /// targets. On MSVC targets, this value restricts the effects of `#pragma pack` except
            /// in some cases involving bit-fields.
            required_alignment_bits: u32,
        };

        pub fn isAnonymous(record: Record, comp: *const Compilation) bool {
            // anonymous records can be recognized by their names which are in
            // the format "(anonymous TAG at path:line:col)".
            return record.name.lookup(comp)[0] == '(';
        }

        pub fn hasField(record: Record, comp: *const Compilation, name: StringId) bool {
            std.debug.assert(record.layout != null);
            std.debug.assert(name != .empty);
            for (record.fields) |field| {
                if (name == field.name) return true;
                if (field.name_tok == 0) if (field.qt.getRecord(comp)) |field_record_ty| {
                    if (field_record_ty.hasField(comp, name)) return true;
                };
            }
            return false;
        }
    };

    pub const Enum = struct {
        /// Null if the enum is incomplete and not fixed.
        tag: ?QualType,
        fixed: bool,
        incomplete: bool,
        name: StringId,
        decl_node: Node.Index,
        fields: []const Field,

        pub const Field = extern struct {
            qt: QualType,
            name: StringId,
            name_tok: TokenIndex,
        };

        pub fn isAnonymous(@"enum": Enum, comp: *const Compilation) bool {
            // anonymous enums can be recognized by their names which are in
            // the format "(anonymous TAG at path:line:col)".
            return @"enum".name.lookup(comp)[0] == '(';
        }
    };

    pub const TypeOf = struct {
        base: QualType,
        expr: ?Node.Index,
    };

    pub const TypeDef = struct {
        base: QualType,
        name: StringId,
        decl_node: Node.Index,
    };

    pub const Attributed = struct {
        base: QualType,
        attributes: []const Attribute,
    };
};

types: std.MultiArrayList(Repr) = .empty,
extra: std.ArrayList(u32) = .empty,
attributes: std.ArrayList(Attribute) = .empty,
anon_name_arena: std.heap.ArenaAllocator.State = .{},

wchar: QualType = .invalid,
uint_least16_t: QualType = .invalid,
uint_least32_t: QualType = .invalid,
ptrdiff: QualType = .invalid,
size: QualType = .invalid,
va_list: QualType = .invalid,
pid_t: QualType = .invalid,
ns_constant_string: QualType = .invalid,
file: QualType = .invalid,
jmp_buf: QualType = .invalid,
sigjmp_buf: QualType = .invalid,
ucontext_t: QualType = .invalid,
intmax: QualType = .invalid,
intptr: QualType = .invalid,
int16: QualType = .invalid,
int64: QualType = .invalid,

pub fn deinit(ts: *TypeStore, gpa: std.mem.Allocator) void {
    ts.types.deinit(gpa);
    ts.extra.deinit(gpa);
    ts.attributes.deinit(gpa);
    ts.anon_name_arena.promote(gpa).deinit();
    ts.* = undefined;
}

pub fn put(ts: *TypeStore, gpa: std.mem.Allocator, ty: Type) !QualType {
    return .{ ._index = try ts.putExtra(gpa, ty) };
}

pub fn putExtra(ts: *TypeStore, gpa: std.mem.Allocator, ty: Type) !Index {
    switch (ty) {
        .void => return .void,
        .bool => return .bool,
        .nullptr_t => return .nullptr_t,
        .int => |int| switch (int) {
            .char => return .int_char,
            .schar => return .int_schar,
            .uchar => return .int_uchar,
            .short => return .int_short,
            .ushort => return .int_ushort,
            .int => return .int_int,
            .uint => return .int_uint,
            .long => return .int_long,
            .ulong => return .int_ulong,
            .long_long => return .int_long_long,
            .ulong_long => return .int_ulong_long,
            .int128 => return .int_int128,
            .uint128 => return .int_uint128,
        },
        .float => |float| switch (float) {
            .bf16 => return .float_bf16,
            .fp16 => return .float_fp16,
            .float16 => return .float_float16,
            .float => return .float_float,
            .double => return .float_double,
            .long_double => return .float_long_double,
            .float128 => return .float_float128,
            .float32 => return .float_float32,
            .float64 => return .float_float64,
            .float32x => return .float_float32x,
            .float64x => return .float_float64x,
            .float128x => return .float_float128x,
            .dfloat32 => return .float_dfloat32,
            .dfloat64 => return .float_dfloat64,
            .dfloat128 => return .float_dfloat128,
            .dfloat64x => return .float_dfloat64x,
        },
        else => {},
    }
    const index = try ts.types.addOne(gpa);
    try ts.set(gpa, ty, index);
    return @enumFromInt(index);
}

pub fn set(ts: *TypeStore, gpa: std.mem.Allocator, ty: Type, index: usize) !void {
    var repr: Repr = undefined;
    switch (ty) {
        .void => unreachable,
        .bool => unreachable,
        .nullptr_t => unreachable,
        .int => unreachable,
        .float => unreachable,
        .complex => |complex| {
            repr.tag = .complex;
            repr.data[0] = @bitCast(complex);
        },
        .bit_int => |bit_int| {
            repr.tag = .bit_int;
            repr.data[0] = bit_int.bits;
            repr.data[1] = @intFromEnum(bit_int.signedness);
        },
        .atomic => |atomic| {
            repr.tag = .atomic;
            std.debug.assert(!atomic.@"const" and !atomic.@"volatile");
            repr.data[0] = @bitCast(atomic);
        },
        .func => |func| {
            repr.data[0] = @bitCast(func.return_type);

            const extra_index: u32 = @intCast(ts.extra.items.len);
            repr.data[1] = extra_index;
            if (func.params.len > 1) {
                try ts.extra.append(gpa, @intCast(func.params.len));
            }

            const param_size = 4;
            comptime std.debug.assert(@sizeOf(Type.Func.Param) == @sizeOf(u32) * param_size);

            try ts.extra.ensureUnusedCapacity(gpa, func.params.len * param_size);
            for (func.params) |*param| {
                const casted: *const [param_size]u32 = @ptrCast(param);
                ts.extra.appendSliceAssumeCapacity(casted);
            }

            repr.tag = switch (func.kind) {
                .normal => switch (func.params.len) {
                    0 => .func_zero,
                    1 => .func_one,
                    else => .func,
                },
                .variadic => switch (func.params.len) {
                    0 => .func_variadic_zero,
                    1 => .func_variadic_one,
                    else => .func_variadic,
                },
                .old_style => switch (func.params.len) {
                    0 => .func_old_style_zero,
                    1 => .func_old_style_one,
                    else => .func_old_style,
                },
            };
        },
        .pointer => |pointer| {
            repr.data[0] = @bitCast(pointer.child);
            if (pointer.decayed) |array| {
                repr.tag = .pointer_decayed;
                repr.data[1] = @bitCast(array);
            } else {
                repr.tag = .pointer;
            }
        },
        .array => |array| {
            repr.data[0] = @bitCast(array.elem);

            const extra_index: u32 = @intCast(ts.extra.items.len);
            switch (array.len) {
                .incomplete => {
                    repr.tag = .array_incomplete;
                },
                .fixed => |len| {
                    repr.tag = .array_fixed;
                    repr.data[1] = extra_index;
                    try ts.extra.appendSlice(gpa, &@as([2]u32, @bitCast(len)));
                },
                .static => |len| {
                    repr.tag = .array_static;
                    repr.data[1] = extra_index;
                    try ts.extra.appendSlice(gpa, &@as([2]u32, @bitCast(len)));
                },
                .variable => |expr| {
                    repr.tag = .array_variable;
                    repr.data[1] = @intFromEnum(expr);
                },
                .unspecified_variable => {
                    repr.tag = .array_unspecified_variable;
                },
            }
        },
        .vector => |vector| {
            repr.tag = .vector;
            repr.data[0] = @bitCast(vector.elem);
            repr.data[1] = vector.len;
        },
        .@"struct", .@"union" => |record| record: {
            repr.data[0] = @intFromEnum(record.name);
            const layout = record.layout orelse {
                std.debug.assert(record.fields.len == 0);
                repr.tag = switch (ty) {
                    .@"struct" => .struct_incomplete,
                    .@"union" => .union_incomplete,
                    else => unreachable,
                };
                repr.data[1] = @intFromEnum(record.decl_node);
                break :record;
            };
            repr.tag = switch (ty) {
                .@"struct" => .@"struct",
                .@"union" => .@"union",
                else => unreachable,
            };

            const extra_index: u32 = @intCast(ts.extra.items.len);
            repr.data[1] = extra_index;

            const layout_size = 5;
            comptime std.debug.assert(@sizeOf(Type.Record.Layout) == @sizeOf(u32) * layout_size);
            const field_size = 10;
            comptime std.debug.assert(@sizeOf(Type.Record.Field) == @sizeOf(u32) * field_size);
            try ts.extra.ensureUnusedCapacity(gpa, record.fields.len * field_size + layout_size + 2);

            ts.extra.appendAssumeCapacity(@intFromEnum(record.decl_node));
            const casted_layout: *const [layout_size]u32 = @ptrCast(&layout);
            ts.extra.appendSliceAssumeCapacity(casted_layout);
            ts.extra.appendAssumeCapacity(@intCast(record.fields.len));

            for (record.fields) |*field| {
                const casted: *const [field_size]u32 = @ptrCast(field);
                ts.extra.appendSliceAssumeCapacity(casted);
            }
        },
        .@"enum" => |@"enum"| @"enum": {
            if (@"enum".incomplete) {
                std.debug.assert(@"enum".fields.len == 0);
                if (@"enum".fixed) {
                    repr.tag = .enum_incomplete_fixed;
                    repr.data[0] = @bitCast(@"enum".tag.?);
                    repr.data[1] = @intCast(ts.extra.items.len);
                    try ts.extra.appendSlice(gpa, &.{
                        @intFromEnum(@"enum".name),
                        @intFromEnum(@"enum".decl_node),
                    });
                } else {
                    repr.tag = .enum_incomplete;
                    repr.data[0] = @intFromEnum(@"enum".name);
                    repr.data[1] = @intFromEnum(@"enum".decl_node);
                }
                break :@"enum";
            }
            repr.tag = if (@"enum".fixed) .enum_fixed else .@"enum";
            repr.data[0] = @bitCast(@"enum".tag.?);

            const extra_index: u32 = @intCast(ts.extra.items.len);
            repr.data[1] = extra_index;

            const field_size = 3;
            comptime std.debug.assert(@sizeOf(Type.Enum.Field) == @sizeOf(u32) * field_size);
            try ts.extra.ensureUnusedCapacity(gpa, @"enum".fields.len * field_size + 3);

            ts.extra.appendAssumeCapacity(@intFromEnum(@"enum".name));
            ts.extra.appendAssumeCapacity(@intFromEnum(@"enum".decl_node));
            ts.extra.appendAssumeCapacity(@intCast(@"enum".fields.len));

            for (@"enum".fields) |*field| {
                const casted: *const [field_size]u32 = @ptrCast(field);
                ts.extra.appendSliceAssumeCapacity(casted);
            }
        },
        .typeof => |typeof| {
            repr.data[0] = @bitCast(typeof.base);
            if (typeof.expr) |some| {
                repr.tag = .typeof_expr;
                repr.data[1] = @intFromEnum(some);
            } else {
                repr.tag = .typeof;
            }
        },
        .typedef => |typedef| {
            repr.tag = .typedef;
            repr.data[0] = @bitCast(typedef.base);
            repr.data[1] = @intCast(ts.extra.items.len);
            try ts.extra.appendSlice(gpa, &.{
                @intFromEnum(typedef.name),
                @intFromEnum(typedef.decl_node),
            });
        },
        .attributed => |attributed| {
            repr.data[0] = @bitCast(attributed.base);

            const attr_index: u32 = @intCast(ts.attributes.items.len);
            const attr_count: u32 = @intCast(attributed.attributes.len);
            try ts.attributes.appendSlice(gpa, attributed.attributes);
            if (attr_count > 1) {
                repr.tag = .attributed;
                const extra_index: u32 = @intCast(ts.extra.items.len);
                repr.data[1] = extra_index;
                try ts.extra.appendSlice(gpa, &.{ attr_index, attr_count });
            } else {
                repr.tag = .attributed_one;
                repr.data[1] = attr_index;
            }
        },
    }
    ts.types.set(index, repr);
}

pub fn initNamedTypes(ts: *TypeStore, comp: *Compilation) !void {
    const os = comp.target.os.tag;
    ts.wchar = switch (comp.target.cpu.arch) {
        .xcore => .uchar,
        .ve, .msp430 => .uint,
        .arm, .armeb, .thumb, .thumbeb => if (os != .windows and os != .netbsd and os != .openbsd) .uint else .int,
        .aarch64, .aarch64_be => if (!os.isDarwin() and os != .netbsd) .uint else .int,
        .x86_64, .x86 => if (os == .windows) .ushort else .int,
        else => .int,
    };

    const ptr_width = comp.target.ptrBitWidth();
    ts.ptrdiff = if (os == .windows and ptr_width == 64)
        .long_long
    else switch (ptr_width) {
        16 => .int,
        32 => .int,
        64 => .long,
        else => unreachable,
    };

    ts.size = if (os == .windows and ptr_width == 64)
        .ulong_long
    else switch (ptr_width) {
        16 => .uint,
        32 => .uint,
        64 => .ulong,
        else => unreachable,
    };

    ts.pid_t = switch (os) {
        .haiku => .long,
        // Todo: pid_t is required to "a signed integer type"; are there any systems
        // on which it is `short int`?
        else => .int,
    };

    ts.intmax = comp.target.intMaxType();
    ts.intptr = comp.target.intPtrType();
    ts.int16 = comp.target.int16Type();
    ts.int64 = comp.target.int64Type();
    ts.uint_least16_t = comp.intLeastN(16, .unsigned);
    ts.uint_least32_t = comp.intLeastN(32, .unsigned);

    ts.ns_constant_string = try ts.generateNsConstantStringType(comp);
    ts.va_list = try ts.generateVaListType(comp);
}

fn generateNsConstantStringType(ts: *TypeStore, comp: *Compilation) !QualType {
    const const_int_ptr: QualType = .{ .@"const" = true, ._index = .int_pointer };
    const const_char_ptr: QualType = .{ .@"const" = true, ._index = .char_pointer };

    var record: Type.Record = .{
        .name = try comp.internString("__NSConstantString_tag"),
        .layout = null,
        .decl_node = undefined, // TODO
        .fields = &.{},
    };
    const qt = try ts.put(comp.gpa, .{ .@"struct" = record });

    var fields: [4]Type.Record.Field = .{
        .{ .name = try comp.internString("isa"), .qt = const_int_ptr },
        .{ .name = try comp.internString("flags"), .qt = .int },
        .{ .name = try comp.internString("str"), .qt = const_char_ptr },
        .{ .name = try comp.internString("length"), .qt = .long },
    };
    record.fields = &fields;
    record.layout = record_layout.compute(&fields, qt, comp, null) catch unreachable;
    try ts.set(comp.gpa, .{ .@"struct" = record }, @intFromEnum(qt._index));

    return qt;
}

fn generateVaListType(ts: *TypeStore, comp: *Compilation) !QualType {
    const Kind = enum {
        aarch64_va_list,
        arm_va_list,
        hexagon_va_list,
        powerpc_va_list,
        s390x_va_list,
        x86_64_va_list,
        xtensa_va_list,
    };
    const kind: Kind = switch (comp.target.cpu.arch) {
        .amdgcn,
        .msp430,
        .nvptx,
        .nvptx64,
        .powerpc64,
        .powerpc64le,
        .x86,
        => return .char_pointer,
        .arc,
        .avr,
        .bpfel,
        .bpfeb,
        .csky,
        .lanai,
        .loongarch32,
        .loongarch64,
        .m68k,
        .mips,
        .mipsel,
        .mips64,
        .mips64el,
        .riscv32,
        .riscv32be,
        .riscv64,
        .riscv64be,
        .sparc,
        .sparc64,
        .spirv32,
        .spirv64,
        .ve,
        .wasm32,
        .wasm64,
        .xcore,
        => return .void_pointer,
        .aarch64, .aarch64_be => switch (comp.target.os.tag) {
            .driverkit, .ios, .maccatalyst, .macos, .tvos, .visionos, .watchos, .windows => return .char_pointer,
            else => .aarch64_va_list,
        },
        .arm, .armeb, .thumb, .thumbeb => .arm_va_list,
        .hexagon => if (comp.target.abi.isMusl())
            .hexagon_va_list
        else
            return .char_pointer,
        .powerpc, .powerpcle => .powerpc_va_list,
        .s390x => .s390x_va_list,
        .x86_64 => switch (comp.target.os.tag) {
            .uefi, .windows => return .char_pointer,
            else => .x86_64_va_list,
        },
        .xtensa => .xtensa_va_list,
        else => return .void, // unknown
    };

    const struct_qt = switch (kind) {
        .aarch64_va_list => blk: {
            var record: Type.Record = .{
                .name = try comp.internString("__va_list_tag"),
                .decl_node = undefined, // TODO
                .layout = null,
                .fields = &.{},
            };
            const qt = try ts.put(comp.gpa, .{ .@"struct" = record });

            var fields: [5]Type.Record.Field = .{
                .{ .name = try comp.internString("__stack"), .qt = .void_pointer },
                .{ .name = try comp.internString("__gr_top"), .qt = .void_pointer },
                .{ .name = try comp.internString("__vr_top"), .qt = .void_pointer },
                .{ .name = try comp.internString("__gr_offs"), .qt = .int },
                .{ .name = try comp.internString("__vr_offs"), .qt = .int },
            };
            record.fields = &fields;
            record.layout = record_layout.compute(&fields, qt, comp, null) catch unreachable;
            try ts.set(comp.gpa, .{ .@"struct" = record }, @intFromEnum(qt._index));

            break :blk qt;
        },
        .arm_va_list => blk: {
            var record: Type.Record = .{
                .name = try comp.internString("__va_list_tag"),
                .decl_node = undefined, // TODO
                .layout = null,
                .fields = &.{},
            };
            const qt = try ts.put(comp.gpa, .{ .@"struct" = record });

            var fields: [1]Type.Record.Field = .{
                .{ .name = try comp.internString("__ap"), .qt = .void_pointer },
            };
            record.fields = &fields;
            record.layout = record_layout.compute(&fields, qt, comp, null) catch unreachable;
            try ts.set(comp.gpa, .{ .@"struct" = record }, @intFromEnum(qt._index));

            break :blk qt;
        },
        .hexagon_va_list => blk: {
            var record: Type.Record = .{
                .name = try comp.internString("__va_list_tag"),
                .decl_node = undefined, // TODO
                .layout = null,
                .fields = &.{},
            };
            const qt = try ts.put(comp.gpa, .{ .@"struct" = record });

            var fields: [4]Type.Record.Field = .{
                .{ .name = try comp.internString("__gpr"), .qt = .long },
                .{ .name = try comp.internString("__fpr"), .qt = .long },
                .{ .name = try comp.internString("__overflow_arg_area"), .qt = .void_pointer },
                .{ .name = try comp.internString("__reg_save_area"), .qt = .void_pointer },
            };
            record.fields = &fields;
            record.layout = record_layout.compute(&fields, qt, comp, null) catch unreachable;
            try ts.set(comp.gpa, .{ .@"struct" = record }, @intFromEnum(qt._index));

            break :blk qt;
        },
        .powerpc_va_list => blk: {
            var record: Type.Record = .{
                .name = try comp.internString("__va_list_tag"),
                .decl_node = undefined, // TODO
                .layout = null,
                .fields = &.{},
            };
            const qt = try ts.put(comp.gpa, .{ .@"struct" = record });

            var fields: [5]Type.Record.Field = .{
                .{ .name = try comp.internString("gpr"), .qt = .uchar },
                .{ .name = try comp.internString("fpr"), .qt = .uchar },
                .{ .name = try comp.internString("reserved"), .qt = .ushort },
                .{ .name = try comp.internString("overflow_arg_area"), .qt = .void_pointer },
                .{ .name = try comp.internString("reg_save_area"), .qt = .void_pointer },
            };
            record.fields = &fields;
            record.layout = record_layout.compute(&fields, qt, comp, null) catch unreachable;
            try ts.set(comp.gpa, .{ .@"struct" = record }, @intFromEnum(qt._index));

            break :blk qt;
        },
        .s390x_va_list => blk: {
            var record: Type.Record = .{
                .name = try comp.internString("__va_list_tag"),
                .decl_node = undefined, // TODO
                .layout = null,
                .fields = &.{},
            };
            const qt = try ts.put(comp.gpa, .{ .@"struct" = record });

            var fields: [3]Type.Record.Field = .{
                .{ .name = try comp.internString("__current_saved_reg_area_pointer"), .qt = .void_pointer },
                .{ .name = try comp.internString("__saved_reg_area_end_pointer"), .qt = .void_pointer },
                .{ .name = try comp.internString("__overflow_area_pointer"), .qt = .void_pointer },
            };
            record.fields = &fields;
            record.layout = record_layout.compute(&fields, qt, comp, null) catch unreachable;
            try ts.set(comp.gpa, .{ .@"struct" = record }, @intFromEnum(qt._index));

            break :blk qt;
        },
        .x86_64_va_list => blk: {
            var record: Type.Record = .{
                .name = try comp.internString("__va_list_tag"),
                .decl_node = undefined, // TODO
                .layout = null,
                .fields = &.{},
            };
            const qt = try ts.put(comp.gpa, .{ .@"struct" = record });

            var fields: [4]Type.Record.Field = .{
                .{ .name = try comp.internString("gp_offset"), .qt = .uint },
                .{ .name = try comp.internString("fp_offset"), .qt = .uint },
                .{ .name = try comp.internString("overflow_arg_area"), .qt = .void_pointer },
                .{ .name = try comp.internString("reg_save_area"), .qt = .void_pointer },
            };
            record.fields = &fields;
            record.layout = record_layout.compute(&fields, qt, comp, null) catch unreachable;
            try ts.set(comp.gpa, .{ .@"struct" = record }, @intFromEnum(qt._index));

            break :blk qt;
        },
        .xtensa_va_list => blk: {
            var record: Type.Record = .{
                .name = try comp.internString("__va_list_tag"),
                .decl_node = undefined, // TODO
                .layout = null,
                .fields = &.{},
            };
            const qt = try ts.put(comp.gpa, .{ .@"struct" = record });

            var fields: [3]Type.Record.Field = .{
                .{ .name = try comp.internString("__va_stk"), .qt = .int_pointer },
                .{ .name = try comp.internString("__va_reg"), .qt = .int_pointer },
                .{ .name = try comp.internString("__va_ndx"), .qt = .int },
            };
            record.fields = &fields;
            record.layout = record_layout.compute(&fields, qt, comp, null) catch unreachable;
            try ts.set(comp.gpa, .{ .@"struct" = record }, @intFromEnum(qt._index));

            break :blk qt;
        },
    };

    return ts.put(comp.gpa, .{ .array = .{
        .elem = struct_qt,
        .len = .{ .fixed = 1 },
    } });
}

/// An unfinished Type
pub const Builder = struct {
    parser: *Parser,

    @"const": ?TokenIndex = null,
    /// _Atomic
    atomic: ?TokenIndex = null,
    @"volatile": ?TokenIndex = null,
    restrict: ?TokenIndex = null,
    unaligned: ?TokenIndex = null,
    nullability: union(enum) {
        none,
        nonnull: TokenIndex,
        nullable: TokenIndex,
        nullable_result: TokenIndex,
        null_unspecified: TokenIndex,
    } = .none,

    complex_tok: ?TokenIndex = null,
    bit_int_tok: ?TokenIndex = null,
    typedef: bool = false,
    typeof: bool = false,
    /// _Atomic(type)
    atomic_type: ?TokenIndex = null,

    type: Specifier = .none,
    /// When true an error is returned instead of adding a diagnostic message.
    /// Used for trying to combine typedef types.
    error_on_invalid: bool = false,

    pub const Specifier = union(enum) {
        none,
        void,
        /// GNU __auto_type extension
        auto_type,
        /// C23 auto
        c23_auto,
        nullptr_t,
        bool,
        char,
        schar,
        uchar,
        complex_char,
        complex_schar,
        complex_uchar,

        unsigned,
        signed,
        short,
        sshort,
        ushort,
        short_int,
        sshort_int,
        ushort_int,
        int,
        sint,
        uint,
        long,
        slong,
        ulong,
        long_int,
        slong_int,
        ulong_int,
        long_long,
        slong_long,
        ulong_long,
        long_long_int,
        slong_long_int,
        ulong_long_int,
        int128,
        sint128,
        uint128,
        complex_unsigned,
        complex_signed,
        complex_short,
        complex_sshort,
        complex_ushort,
        complex_short_int,
        complex_sshort_int,
        complex_ushort_int,
        complex_int,
        complex_sint,
        complex_uint,
        complex_long,
        complex_slong,
        complex_ulong,
        complex_long_int,
        complex_slong_int,
        complex_ulong_int,
        complex_long_long,
        complex_slong_long,
        complex_ulong_long,
        complex_long_long_int,
        complex_slong_long_int,
        complex_ulong_long_int,
        complex_int128,
        complex_sint128,
        complex_uint128,
        bit_int: u64,
        sbit_int: u64,
        ubit_int: u64,
        complex_bit_int: u64,
        complex_sbit_int: u64,
        complex_ubit_int: u64,

        bf16,
        fp16,
        float16,
        float,
        double,
        long_double,
        float128,
        float32,
        float64,
        float32x,
        float64x,
        float128x,
        dfloat32,
        dfloat64,
        dfloat128,
        dfloat64x,
        complex,
        complex_float16,
        complex_float,
        complex_double,
        complex_long_double,
        complex_float128,
        complex_float32,
        complex_float64,
        complex_float32x,
        complex_float64x,
        complex_float128x,

        // Any not simply constructed from specifier keywords.
        other: QualType,

        pub fn str(spec: Builder.Specifier, langopts: LangOpts) ?[]const u8 {
            return switch (spec) {
                .none => unreachable,
                .void => "void",
                .auto_type => "__auto_type",
                .c23_auto => "auto",
                .nullptr_t => "nullptr_t",
                .bool => if (langopts.standard.atLeast(.c23)) "bool" else "_Bool",
                .char => "char",
                .schar => "signed char",
                .uchar => "unsigned char",
                .unsigned => "unsigned",
                .signed => "signed",
                .short => "short",
                .ushort => "unsigned short",
                .sshort => "signed short",
                .short_int => "short int",
                .sshort_int => "signed short int",
                .ushort_int => "unsigned short int",
                .int => "int",
                .sint => "signed int",
                .uint => "unsigned int",
                .long => "long",
                .slong => "signed long",
                .ulong => "unsigned long",
                .long_int => "long int",
                .slong_int => "signed long int",
                .ulong_int => "unsigned long int",
                .long_long => "long long",
                .slong_long => "signed long long",
                .ulong_long => "unsigned long long",
                .long_long_int => "long long int",
                .slong_long_int => "signed long long int",
                .ulong_long_int => "unsigned long long int",
                .int128 => "__int128",
                .sint128 => "signed __int128",
                .uint128 => "unsigned __int128",
                .complex_char => "_Complex char",
                .complex_schar => "_Complex signed char",
                .complex_uchar => "_Complex unsigned char",
                .complex_unsigned => "_Complex unsigned",
                .complex_signed => "_Complex signed",
                .complex_short => "_Complex short",
                .complex_ushort => "_Complex unsigned short",
                .complex_sshort => "_Complex signed short",
                .complex_short_int => "_Complex short int",
                .complex_sshort_int => "_Complex signed short int",
                .complex_ushort_int => "_Complex unsigned short int",
                .complex_int => "_Complex int",
                .complex_sint => "_Complex signed int",
                .complex_uint => "_Complex unsigned int",
                .complex_long => "_Complex long",
                .complex_slong => "_Complex signed long",
                .complex_ulong => "_Complex unsigned long",
                .complex_long_int => "_Complex long int",
                .complex_slong_int => "_Complex signed long int",
                .complex_ulong_int => "_Complex unsigned long int",
                .complex_long_long => "_Complex long long",
                .complex_slong_long => "_Complex signed long long",
                .complex_ulong_long => "_Complex unsigned long long",
                .complex_long_long_int => "_Complex long long int",
                .complex_slong_long_int => "_Complex signed long long int",
                .complex_ulong_long_int => "_Complex unsigned long long int",
                .complex_int128 => "_Complex __int128",
                .complex_sint128 => "_Complex signed __int128",
                .complex_uint128 => "_Complex unsigned __int128",

                .bf16 => "__bf16",
                .fp16 => "__fp16",
                .float16 => "_Float16",
                .float => "float",
                .double => "double",
                .long_double => "long double",
                .float128 => "__float128",
                .complex => "_Complex",
                .complex_float16 => "_Complex _Float16",
                .complex_float => "_Complex float",
                .complex_double => "_Complex double",
                .complex_long_double => "_Complex long double",
                .complex_float128 => "_Complex __float128",

                else => null,
            };
        }
    };

    pub fn finish(b: Builder) Parser.Error!QualType {
        const qt: QualType = switch (b.type) {
            .none => blk: {
                if (b.parser.comp.langopts.standard.atLeast(.c23)) {
                    try b.parser.err(b.parser.tok_i, .missing_type_specifier_c23, .{});
                } else {
                    try b.parser.err(b.parser.tok_i, .missing_type_specifier, .{});
                }
                break :blk .int;
            },
            .void => .void,
            .auto_type => .auto_type,
            .c23_auto => .c23_auto,
            .nullptr_t => unreachable, // nullptr_t can only be accessed via typeof(nullptr)
            .bool => .bool,
            .char => .char,
            .schar => .schar,
            .uchar => .uchar,

            .unsigned => .uint,
            .signed => .int,
            .short_int, .sshort_int, .short, .sshort => .short,
            .ushort, .ushort_int => .ushort,
            .int, .sint => .int,
            .uint => .uint,
            .long, .slong, .long_int, .slong_int => .long,
            .ulong, .ulong_int => .ulong,
            .long_long, .slong_long, .long_long_int, .slong_long_int => .long_long,
            .ulong_long, .ulong_long_int => .ulong_long,
            .int128, .sint128 => .int128,
            .uint128 => .uint128,

            .complex_char,
            .complex_schar,
            .complex_uchar,
            .complex_unsigned,
            .complex_signed,
            .complex_short_int,
            .complex_sshort_int,
            .complex_short,
            .complex_sshort,
            .complex_ushort,
            .complex_ushort_int,
            .complex_int,
            .complex_sint,
            .complex_uint,
            .complex_long,
            .complex_slong,
            .complex_long_int,
            .complex_slong_int,
            .complex_ulong,
            .complex_ulong_int,
            .complex_long_long,
            .complex_slong_long,
            .complex_long_long_int,
            .complex_slong_long_int,
            .complex_ulong_long,
            .complex_ulong_long_int,
            .complex_int128,
            .complex_sint128,
            .complex_uint128,
            => blk: {
                const base_qt: QualType = switch (b.type) {
                    .complex_char => .char,
                    .complex_schar => .schar,
                    .complex_uchar => .uchar,
                    .complex_unsigned => .uint,
                    .complex_signed => .int,
                    .complex_short_int, .complex_sshort_int, .complex_short, .complex_sshort => .short,
                    .complex_ushort, .complex_ushort_int => .ushort,
                    .complex_int, .complex_sint => .int,
                    .complex_uint => .uint,
                    .complex_long, .complex_slong, .complex_long_int, .complex_slong_int => .long,
                    .complex_ulong, .complex_ulong_int => .ulong,
                    .complex_long_long, .complex_slong_long, .complex_long_long_int, .complex_slong_long_int => .long_long,
                    .complex_ulong_long, .complex_ulong_long_int => .ulong_long,
                    .complex_int128, .complex_sint128 => .int128,
                    .complex_uint128 => .uint128,
                    else => unreachable,
                };
                if (b.complex_tok) |tok| try b.parser.err(tok, .complex_int, .{});
                break :blk try base_qt.toComplex(b.parser.comp);
            },

            .bit_int, .sbit_int, .ubit_int, .complex_bit_int, .complex_ubit_int, .complex_sbit_int => |bits| blk: {
                const unsigned = b.type == .ubit_int or b.type == .complex_ubit_int;
                const complex = b.type == .complex_bit_int or b.type == .complex_ubit_int or b.type == .complex_sbit_int;
                const complex_str = if (complex) "_Complex " else "";

                if (unsigned) {
                    if (bits < 1) {
                        try b.parser.err(b.bit_int_tok.?, .unsigned_bit_int_too_small, .{complex_str});
                        return .invalid;
                    }
                } else {
                    if (bits < 2) {
                        try b.parser.err(b.bit_int_tok.?, .signed_bit_int_too_small, .{complex_str});
                        return .invalid;
                    }
                }
                if (bits > Compilation.bit_int_max_bits) {
                    try b.parser.err(b.bit_int_tok.?, if (unsigned) .unsigned_bit_int_too_big else .signed_bit_int_too_big, .{complex_str});
                    return .invalid;
                }
                if (b.complex_tok) |tok| try b.parser.err(tok, .complex_int, .{});

                const qt = try b.parser.comp.type_store.put(b.parser.comp.gpa, .{ .bit_int = .{
                    .signedness = if (unsigned) .unsigned else .signed,
                    .bits = @intCast(bits),
                } });
                break :blk if (complex) try qt.toComplex(b.parser.comp) else qt;
            },

            .bf16 => .bf16,
            .fp16 => .fp16,
            .float16 => .float16,
            .float => .float,
            .double => .double,
            .long_double => .long_double,
            .float128 => .float128,
            .float32 => .float32,
            .float64 => .float64,
            .float32x => .float32x,
            .float64x => .float64x,
            .float128x => .float128x,
            .dfloat32 => .dfloat32,
            .dfloat64 => .dfloat64,
            .dfloat128 => .dfloat128,
            .dfloat64x => .dfloat64x,

            .complex_float16,
            .complex_float,
            .complex_double,
            .complex_long_double,
            .complex_float128,
            .complex_float32,
            .complex_float64,
            .complex_float32x,
            .complex_float64x,
            .complex_float128x,
            .complex,
            => blk: {
                const base_qt: QualType = switch (b.type) {
                    .complex_float16 => .float16,
                    .complex_float => .float,
                    .complex_double => .double,
                    .complex_long_double => .long_double,
                    .complex_float128 => .float128,
                    .complex_float32 => .float32,
                    .complex_float64 => .float64,
                    .complex_float32x => .float32x,
                    .complex_float64x => .float64x,
                    .complex_float128x => .float128x,
                    .complex => .double,
                    else => unreachable,
                };
                if (b.type == .complex) try b.parser.err(b.parser.tok_i - 1, .plain_complex, .{});
                break :blk try base_qt.toComplex(b.parser.comp);
            },

            .other => |qt| qt,
        };
        return b.finishQuals(qt);
    }

    pub fn finishQuals(b: Builder, qt: QualType) !QualType {
        if (qt.isInvalid()) return .invalid;
        const gpa = b.parser.comp.gpa;
        var result_qt = qt;
        if (b.atomic_type orelse b.atomic) |atomic_tok| {
            if (result_qt.isAutoType()) return b.parser.todo("_Atomic __auto_type");
            if (result_qt.isC23Auto()) {
                try b.parser.err(atomic_tok, .atomic_auto, .{});
                return .invalid;
            }
            if (result_qt.hasIncompleteSize(b.parser.comp)) {
                try b.parser.err(atomic_tok, .atomic_incomplete, .{qt});
                return .invalid;
            }
            switch (result_qt.base(b.parser.comp).type) {
                .array => {
                    try b.parser.err(atomic_tok, .atomic_array, .{qt});
                    return .invalid;
                },
                .func => {
                    try b.parser.err(atomic_tok, .atomic_func, .{qt});
                    return .invalid;
                },
                .atomic => {
                    try b.parser.err(atomic_tok, .atomic_atomic, .{qt});
                    return .invalid;
                },
                .complex => {
                    try b.parser.err(atomic_tok, .atomic_complex, .{qt});
                    return .invalid;
                },
                else => {
                    result_qt = try b.parser.comp.type_store.put(gpa, .{ .atomic = result_qt });
                },
            }
        }

        // We can't use `qt.isPointer()` because `qt` might contain a `.declarator_combine`.
        const is_pointer = qt.isAutoType() or qt.isC23Auto() or qt.base(b.parser.comp).type == .pointer;

        if (b.unaligned != null and !is_pointer) {
            result_qt = (try b.parser.comp.type_store.put(gpa, .{ .attributed = .{
                .base = result_qt,
                .attributes = &.{.{ .tag = .unaligned, .args = .{ .unaligned = .{} }, .syntax = .keyword }},
            } })).withQualifiers(result_qt);
        }
        switch (b.nullability) {
            .none => {},
            .nonnull,
            .nullable,
            .nullable_result,
            .null_unspecified,
            => |tok| if (!is_pointer) {
                // TODO this should be checked later so that auto types can be properly validated.
                try b.parser.err(tok, .invalid_nullability, .{qt});
            },
        }

        if (b.@"const" != null) result_qt.@"const" = true;
        if (b.@"volatile" != null) result_qt.@"volatile" = true;

        if (b.restrict) |restrict_tok| {
            if (result_qt.isAutoType()) return b.parser.todo("restrict __auto_type");
            if (result_qt.isC23Auto()) {
                try b.parser.err(restrict_tok, .restrict_non_pointer, .{qt});
                return result_qt;
            }
            switch (qt.base(b.parser.comp).type) {
                .array, .pointer => result_qt.restrict = true,
                else => {
                    try b.parser.err(restrict_tok, .restrict_non_pointer, .{qt});
                },
            }
        }
        return result_qt;
    }

    fn cannotCombine(b: Builder, source_tok: TokenIndex) !void {
        if (b.type.str(b.parser.comp.langopts)) |some| {
            return b.parser.err(source_tok, .cannot_combine_spec, .{some});
        }
        try b.parser.err(source_tok, .cannot_combine_spec_qt, .{try b.finish()});
    }

    fn duplicateSpec(b: *Builder, source_tok: TokenIndex, spec: []const u8) !void {
        if (b.parser.comp.langopts.emulate != .clang) return b.cannotCombine(source_tok);
        try b.parser.err(b.parser.tok_i, .duplicate_decl_spec, .{spec});
    }

    pub fn combineFromTypeof(b: *Builder, new: QualType, source_tok: TokenIndex) Compilation.Error!void {
        if (b.atomic_type != null) return b.parser.err(source_tok, .cannot_combine_spec, .{"_Atomic"});
        if (b.typedef) return b.parser.err(source_tok, .cannot_combine_spec, .{"type-name"});
        if (b.typeof) return b.parser.err(source_tok, .cannot_combine_spec, .{"typeof"});
        if (b.type != .none) return b.parser.err(source_tok, .cannot_combine_with_typeof, .{@tagName(b.type)});
        b.typeof = true;
        b.type = .{ .other = new };
    }

    pub fn combineAtomic(b: *Builder, base_qt: QualType, source_tok: TokenIndex) !void {
        if (b.atomic_type != null) return b.parser.err(source_tok, .cannot_combine_spec, .{"_Atomic"});
        if (b.typedef) return b.parser.err(source_tok, .cannot_combine_spec, .{"type-name"});
        if (b.typeof) return b.parser.err(source_tok, .cannot_combine_spec, .{"typeof"});

        const new_spec = TypeStore.Builder.fromType(b.parser.comp, base_qt);
        try b.combine(new_spec, source_tok);

        b.atomic_type = source_tok;
    }

    /// Try to combine type from typedef, returns true if successful.
    pub fn combineTypedef(b: *Builder, typedef_qt: QualType) bool {
        if (b.type != .none) return false;

        b.typedef = true;
        b.type = .{ .other = typedef_qt };
        return true;
    }

    pub fn combine(b: *Builder, new: Builder.Specifier, source_tok: TokenIndex) !void {
        if (b.typeof) {
            return b.parser.err(source_tok, .cannot_combine_with_typeof, .{@tagName(new)});
        }
        if (b.atomic_type != null) {
            return b.parser.err(source_tok, .cannot_combine_spec, .{"_Atomic"});
        }
        if (b.typedef) {
            return b.parser.err(source_tok, .cannot_combine_spec, .{"type-name"});
        }
        if (b.type == .other and b.type.other.isInvalid()) return;

        switch (new) {
            .complex => b.complex_tok = source_tok,
            .bit_int => b.bit_int_tok = source_tok,
            else => {},
        }

        if (new == .int128 and !b.parser.comp.target.hasInt128()) {
            try b.parser.err(source_tok, .type_not_supported_on_target, .{"__int128"});
        }

        b.type = switch (new) {
            else => switch (b.type) {
                .none => new,
                else => return b.cannotCombine(source_tok),
            },
            .signed => switch (b.type) {
                .none => .signed,
                .char => .schar,
                .short => .sshort,
                .short_int => .sshort_int,
                .int => .sint,
                .long => .slong,
                .long_int => .slong_int,
                .long_long => .slong_long,
                .long_long_int => .slong_long_int,
                .int128 => .sint128,
                .bit_int => |bits| .{ .sbit_int = bits },
                .complex => .complex_signed,
                .complex_char => .complex_schar,
                .complex_short => .complex_sshort,
                .complex_short_int => .complex_sshort_int,
                .complex_int => .complex_sint,
                .complex_long => .complex_slong,
                .complex_long_int => .complex_slong_int,
                .complex_long_long => .complex_slong_long,
                .complex_long_long_int => .complex_slong_long_int,
                .complex_int128 => .sint128,
                .complex_bit_int => |bits| .{ .complex_sbit_int = bits },
                .signed,
                .sshort,
                .sshort_int,
                .sint,
                .slong,
                .slong_int,
                .slong_long,
                .slong_long_int,
                .sint128,
                .sbit_int,
                .complex_schar,
                .complex_signed,
                .complex_sshort,
                .complex_sshort_int,
                .complex_sint,
                .complex_slong,
                .complex_slong_int,
                .complex_slong_long,
                .complex_slong_long_int,
                .complex_sint128,
                .complex_sbit_int,
                => return b.duplicateSpec(source_tok, "signed"),
                else => return b.cannotCombine(source_tok),
            },
            .unsigned => switch (b.type) {
                .none => .unsigned,
                .char => .uchar,
                .short => .ushort,
                .short_int => .ushort_int,
                .int => .uint,
                .long => .ulong,
                .long_int => .ulong_int,
                .long_long => .ulong_long,
                .long_long_int => .ulong_long_int,
                .int128 => .uint128,
                .bit_int => |bits| .{ .ubit_int = bits },
                .complex => .complex_unsigned,
                .complex_char => .complex_uchar,
                .complex_short => .complex_ushort,
                .complex_short_int => .complex_ushort_int,
                .complex_int => .complex_uint,
                .complex_long => .complex_ulong,
                .complex_long_int => .complex_ulong_int,
                .complex_long_long => .complex_ulong_long,
                .complex_long_long_int => .complex_ulong_long_int,
                .complex_int128 => .complex_uint128,
                .complex_bit_int => |bits| .{ .complex_ubit_int = bits },
                .unsigned,
                .ushort,
                .ushort_int,
                .uint,
                .ulong,
                .ulong_int,
                .ulong_long,
                .ulong_long_int,
                .uint128,
                .ubit_int,
                .complex_uchar,
                .complex_unsigned,
                .complex_ushort,
                .complex_ushort_int,
                .complex_uint,
                .complex_ulong,
                .complex_ulong_int,
                .complex_ulong_long,
                .complex_ulong_long_int,
                .complex_uint128,
                .complex_ubit_int,
                => return b.duplicateSpec(source_tok, "unsigned"),
                else => return b.cannotCombine(source_tok),
            },
            .char => switch (b.type) {
                .none => .char,
                .unsigned => .uchar,
                .signed => .schar,
                .complex => .complex_char,
                .complex_signed => .schar,
                .complex_unsigned => .uchar,
                else => return b.cannotCombine(source_tok),
            },
            .short => switch (b.type) {
                .none => .short,
                .unsigned => .ushort,
                .signed => .sshort,
                .int => .short_int,
                .sint => .sshort_int,
                .uint => .ushort_int,
                .complex => .complex_short,
                .complex_signed => .sshort,
                .complex_unsigned => .ushort,
                else => return b.cannotCombine(source_tok),
            },
            .int => switch (b.type) {
                .none => .int,
                .signed => .sint,
                .unsigned => .uint,
                .short => .short_int,
                .sshort => .sshort_int,
                .ushort => .ushort_int,
                .long => .long_int,
                .slong => .slong_int,
                .ulong => .ulong_int,
                .long_long => .long_long_int,
                .slong_long => .slong_long_int,
                .ulong_long => .ulong_long_int,
                .complex => .complex_int,
                .complex_signed => .complex_sint,
                .complex_unsigned => .complex_uint,
                .complex_short => .complex_short_int,
                .complex_sshort => .complex_sshort_int,
                .complex_ushort => .complex_ushort_int,
                .complex_long => .complex_long_int,
                .complex_slong => .complex_slong_int,
                .complex_ulong => .complex_ulong_int,
                .complex_long_long => .complex_long_long_int,
                .complex_slong_long => .complex_slong_long_int,
                .complex_ulong_long => .complex_ulong_long_int,
                else => return b.cannotCombine(source_tok),
            },
            .long => switch (b.type) {
                .none => .long,
                .double => .long_double,
                .unsigned => .ulong,
                .signed => .slong,
                .int => .long_int,
                .uint => .ulong_int,
                .sint => .slong_int,
                .long => .long_long,
                .slong => .slong_long,
                .ulong => .ulong_long,
                .complex => .complex_long,
                .complex_signed => .complex_slong,
                .complex_unsigned => .complex_ulong,
                .complex_long => .complex_long_long,
                .complex_slong => .complex_slong_long,
                .complex_ulong => .complex_ulong_long,
                .complex_double => .complex_long_double,
                else => return b.cannotCombine(source_tok),
            },
            .long_long => switch (b.type) {
                .none => .long_long,
                .unsigned => .ulong_long,
                .signed => .slong_long,
                .int => .long_long_int,
                .sint => .slong_long_int,
                .long => .long_long,
                .slong => .slong_long,
                .ulong => .ulong_long,
                .complex => .complex_long,
                .complex_signed => .complex_slong_long,
                .complex_unsigned => .complex_ulong_long,
                .complex_long => .complex_long_long,
                .complex_slong => .complex_slong_long,
                .complex_ulong => .complex_ulong_long,
                .long_long,
                .ulong_long,
                .ulong_long_int,
                .complex_long_long,
                .complex_ulong_long,
                .complex_ulong_long_int,
                => return b.duplicateSpec(source_tok, "long"),
                else => return b.cannotCombine(source_tok),
            },
            .int128 => switch (b.type) {
                .none => .int128,
                .unsigned => .uint128,
                .signed => .sint128,
                .complex => .complex_int128,
                .complex_signed => .complex_sint128,
                .complex_unsigned => .complex_uint128,
                else => return b.cannotCombine(source_tok),
            },
            .bit_int => switch (b.type) {
                .none => .{ .bit_int = new.bit_int },
                .unsigned => .{ .ubit_int = new.bit_int },
                .signed => .{ .sbit_int = new.bit_int },
                .complex => .{ .complex_bit_int = new.bit_int },
                .complex_signed => .{ .complex_sbit_int = new.bit_int },
                .complex_unsigned => .{ .complex_ubit_int = new.bit_int },
                else => return b.cannotCombine(source_tok),
            },
            .auto_type => switch (b.type) {
                .none => .auto_type,
                else => return b.cannotCombine(source_tok),
            },
            .c23_auto => switch (b.type) {
                .none => .c23_auto,
                else => return b.cannotCombine(source_tok),
            },
            .fp16 => switch (b.type) {
                .none => .fp16,
                else => return b.cannotCombine(source_tok),
            },
            .float16 => switch (b.type) {
                .none => .float16,
                .complex => .complex_float16,
                else => return b.cannotCombine(source_tok),
            },
            .float => switch (b.type) {
                .none => .float,
                .complex => .complex_float,
                else => return b.cannotCombine(source_tok),
            },
            .double => switch (b.type) {
                .none => .double,
                .long => .long_double,
                .complex_long => .complex_long_double,
                .complex => .complex_double,
                else => return b.cannotCombine(source_tok),
            },
            .float128 => switch (b.type) {
                .none => .float128,
                .complex => .complex_float128,
                else => return b.cannotCombine(source_tok),
            },
            .float32 => switch (b.type) {
                .none => .float32,
                .complex => .complex_float32,
                else => return b.cannotCombine(source_tok),
            },
            .float64 => switch (b.type) {
                .none => .float64,
                .complex => .complex_float64,
                else => return b.cannotCombine(source_tok),
            },
            .float32x => switch (b.type) {
                .none => .float32x,
                .complex => .complex_float32x,
                else => return b.cannotCombine(source_tok),
            },
            .float64x => switch (b.type) {
                .none => .float64x,
                .complex => .complex_float64x,
                else => return b.cannotCombine(source_tok),
            },
            .float128x => switch (b.type) {
                .none => .float128x,
                .complex => .complex_float128x,
                else => return b.cannotCombine(source_tok),
            },
            .dfloat32 => switch (b.type) {
                .none => .dfloat32,
                else => return b.cannotCombine(source_tok),
            },
            .dfloat64 => switch (b.type) {
                .none => .dfloat64,
                else => return b.cannotCombine(source_tok),
            },
            .dfloat128 => switch (b.type) {
                .none => .dfloat128,
                else => return b.cannotCombine(source_tok),
            },
            .dfloat64x => switch (b.type) {
                .none => .dfloat64x,
                else => return b.cannotCombine(source_tok),
            },
            .complex => switch (b.type) { //
                .none => .complex,
                .float16 => .complex_float16,
                .float => .complex_float,
                .double => .complex_double,
                .long_double => .complex_long_double,
                .float128 => .complex_float128,
                .float32 => .complex_float32,
                .float64 => .complex_float64,
                .float32x => .complex_float32x,
                .float64x => .complex_float64x,
                .float128x => .complex_float128x,
                .char => .complex_char,
                .schar => .complex_schar,
                .uchar => .complex_uchar,
                .unsigned => .complex_unsigned,
                .signed => .complex_signed,
                .short => .complex_short,
                .sshort => .complex_sshort,
                .ushort => .complex_ushort,
                .short_int => .complex_short_int,
                .sshort_int => .complex_sshort_int,
                .ushort_int => .complex_ushort_int,
                .int => .complex_int,
                .sint => .complex_sint,
                .uint => .complex_uint,
                .long => .complex_long,
                .slong => .complex_slong,
                .ulong => .complex_ulong,
                .long_int => .complex_long_int,
                .slong_int => .complex_slong_int,
                .ulong_int => .complex_ulong_int,
                .long_long => .complex_long_long,
                .slong_long => .complex_slong_long,
                .ulong_long => .complex_ulong_long,
                .long_long_int => .complex_long_long_int,
                .slong_long_int => .complex_slong_long_int,
                .ulong_long_int => .complex_ulong_long_int,
                .int128 => .complex_int128,
                .sint128 => .complex_sint128,
                .uint128 => .complex_uint128,
                .bit_int => |bits| .{ .complex_bit_int = bits },
                .sbit_int => |bits| .{ .complex_sbit_int = bits },
                .ubit_int => |bits| .{ .complex_ubit_int = bits },
                .complex,
                .complex_float,
                .complex_double,
                .complex_long_double,
                .complex_float128,
                .complex_char,
                .complex_schar,
                .complex_uchar,
                .complex_unsigned,
                .complex_signed,
                .complex_short,
                .complex_sshort,
                .complex_ushort,
                .complex_short_int,
                .complex_sshort_int,
                .complex_ushort_int,
                .complex_int,
                .complex_sint,
                .complex_uint,
                .complex_long,
                .complex_slong,
                .complex_ulong,
                .complex_long_int,
                .complex_slong_int,
                .complex_ulong_int,
                .complex_long_long,
                .complex_slong_long,
                .complex_ulong_long,
                .complex_long_long_int,
                .complex_slong_long_int,
                .complex_ulong_long_int,
                .complex_int128,
                .complex_sint128,
                .complex_uint128,
                .complex_bit_int,
                .complex_sbit_int,
                .complex_ubit_int,
                .complex_float32,
                .complex_float64,
                .complex_float32x,
                .complex_float64x,
                .complex_float128x,
                => return b.duplicateSpec(source_tok, "_Complex"),
                else => return b.cannotCombine(source_tok),
            },
        };
    }

    pub fn fromType(comp: *const Compilation, qt: QualType) Builder.Specifier {
        return switch (qt.base(comp).type) {
            .void => .void,
            .nullptr_t => .nullptr_t,
            .bool => .bool,
            .int => |int| switch (int) {
                .char => .char,
                .schar => .schar,
                .uchar => .uchar,
                .short => .short,
                .ushort => .ushort,
                .int => .int,
                .uint => .uint,
                .long => .long,
                .ulong => .ulong,
                .long_long => .long_long,
                .ulong_long => .ulong_long,
                .int128 => .int128,
                .uint128 => .uint128,
            },
            .bit_int => |bit_int| if (bit_int.signedness == .unsigned) {
                return .{ .ubit_int = bit_int.bits };
            } else {
                return .{ .bit_int = bit_int.bits };
            },
            .float => |float| switch (float) {
                .bf16 => .bf16,
                .fp16 => .fp16,
                .float16 => .float16,
                .float => .float,
                .double => .double,
                .long_double => .long_double,
                .float128 => .float128,
                .float32 => .float32,
                .float64 => .float64,
                .float32x => .float32x,
                .float64x => .float64x,
                .float128x => .float128x,
                .dfloat32 => .dfloat32,
                .dfloat64 => .dfloat64,
                .dfloat128 => .dfloat128,
                .dfloat64x => .dfloat64x,
            },
            .complex => |complex| switch (complex.base(comp).type) {
                .int => |int| switch (int) {
                    .char => .complex_char,
                    .schar => .complex_schar,
                    .uchar => .complex_uchar,
                    .short => .complex_short,
                    .ushort => .complex_ushort,
                    .int => .complex_int,
                    .uint => .complex_uint,
                    .long => .complex_long,
                    .ulong => .complex_ulong,
                    .long_long => .complex_long_long,
                    .ulong_long => .complex_ulong_long,
                    .int128 => .complex_int128,
                    .uint128 => .complex_uint128,
                },
                .bit_int => |bit_int| if (bit_int.signedness == .unsigned) {
                    return .{ .complex_ubit_int = bit_int.bits };
                } else {
                    return .{ .complex_bit_int = bit_int.bits };
                },
                .float => |float| switch (float) {
                    .fp16 => unreachable,
                    .bf16 => unreachable,
                    .float16 => .complex_float16,
                    .float => .complex_float,
                    .double => .complex_double,
                    .long_double => .complex_long_double,
                    .float128 => .complex_float128,
                    .float32 => .complex_float32,
                    .float64 => .complex_float64,
                    .float32x => .complex_float32x,
                    .float64x => .complex_float64x,
                    .float128x => .complex_float128x,
                    .dfloat32 => unreachable,
                    .dfloat64 => unreachable,
                    .dfloat128 => unreachable,
                    .dfloat64x => unreachable,
                },
                else => unreachable,
            },
            else => .{ .other = qt },
        };
    }
};
