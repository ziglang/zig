const std = @import("std");
const Tree = @import("Tree.zig");
const TokenIndex = Tree.TokenIndex;
const NodeIndex = Tree.NodeIndex;
const Parser = @import("Parser.zig");
const Compilation = @import("Compilation.zig");
const Attribute = @import("Attribute.zig");

const Type = @This();

pub const Qualifiers = packed struct {
    @"const": bool = false,
    atomic: bool = false,
    @"volatile": bool = false,
    restrict: bool = false,

    // for function parameters only, stored here since it fits in the padding
    register: bool = false,

    pub fn any(quals: Qualifiers) bool {
        return quals.@"const" or quals.restrict or quals.@"volatile" or quals.atomic;
    }

    pub fn dump(quals: Qualifiers, w: anytype) !void {
        if (quals.@"const") try w.writeAll("const ");
        if (quals.atomic) try w.writeAll("_Atomic ");
        if (quals.@"volatile") try w.writeAll("volatile ");
        if (quals.restrict) try w.writeAll("restrict ");
        if (quals.register) try w.writeAll("register ");
    }

    /// Merge the const/volatile qualifiers, used by type resolution
    /// of the conditional operator
    pub fn mergeCV(a: Qualifiers, b: Qualifiers) Qualifiers {
        return .{
            .@"const" = a.@"const" or b.@"const",
            .@"volatile" = a.@"volatile" or b.@"volatile",
        };
    }

    /// Merge all qualifiers, used by typeof()
    fn mergeAll(a: Qualifiers, b: Qualifiers) Qualifiers {
        return .{
            .@"const" = a.@"const" or b.@"const",
            .atomic = a.atomic or b.atomic,
            .@"volatile" = a.@"volatile" or b.@"volatile",
            .restrict = a.restrict or b.restrict,
            .register = a.register or b.register,
        };
    }

    /// Checks if a has all the qualifiers of b
    pub fn hasQuals(a: Qualifiers, b: Qualifiers) bool {
        if (b.@"const" and !a.@"const") return false;
        if (b.@"volatile" and !a.@"volatile") return false;
        if (b.atomic and !a.atomic) return false;
        return true;
    }

    /// register is a storage class and not actually a qualifier
    /// so it is not preserved by typeof()
    pub fn inheritFromTypeof(quals: Qualifiers) Qualifiers {
        var res = quals;
        res.register = false;
        return res;
    }

    pub const Builder = struct {
        @"const": ?TokenIndex = null,
        atomic: ?TokenIndex = null,
        @"volatile": ?TokenIndex = null,
        restrict: ?TokenIndex = null,

        pub fn finish(b: Qualifiers.Builder, p: *Parser, ty: *Type) !void {
            if (ty.specifier != .pointer and b.restrict != null) {
                try p.errStr(.restrict_non_pointer, b.restrict.?, try p.typeStr(ty.*));
            }
            if (b.atomic) |some| {
                if (ty.isArray()) try p.errStr(.atomic_array, some, try p.typeStr(ty.*));
                if (ty.isFunc()) try p.errStr(.atomic_func, some, try p.typeStr(ty.*));
                if (ty.hasIncompleteSize()) try p.errStr(.atomic_incomplete, some, try p.typeStr(ty.*));
            }

            ty.qual = .{
                .@"const" = b.@"const" != null,
                .atomic = b.atomic != null,
                .@"volatile" = b.@"volatile" != null,
                .restrict = b.restrict != null,
            };
        }
    };
};

// TODO improve memory usage
pub const Func = struct {
    return_type: Type,
    params: []Param,

    pub const Param = struct {
        name: []const u8,
        ty: Type,
        name_tok: TokenIndex,
    };
};

pub const Array = struct {
    len: u64,
    elem: Type,
};

pub const Expr = struct {
    node: NodeIndex,
    ty: Type,
};

pub const Attributed = struct {
    attributes: []Attribute,
    base: Type,

    fn create(allocator: std.mem.Allocator, base: Type, attributes: []const Attribute) !*Attributed {
        var attributed_type = try allocator.create(Attributed);
        errdefer allocator.destroy(attributed_type);

        const existing = base.getAttributes();
        var all_attrs = try allocator.alloc(Attribute, existing.len + attributes.len);
        std.mem.copy(Attribute, all_attrs, existing);
        std.mem.copy(Attribute, all_attrs[existing.len..], attributes);

        attributed_type.* = .{
            .attributes = all_attrs,
            .base = base,
        };
        return attributed_type;
    }
};

// TODO improve memory usage
pub const Enum = struct {
    name: []const u8,
    tag_ty: Type,
    fields: []Field,

    pub const Field = struct {
        name: []const u8,
        ty: Type,
        name_tok: TokenIndex,
        node: NodeIndex,
    };

    pub fn isIncomplete(e: Enum) bool {
        return e.fields.len == std.math.maxInt(usize);
    }

    pub fn create(allocator: std.mem.Allocator, name: []const u8) !*Enum {
        var e = try allocator.create(Enum);
        e.name = name;
        e.fields.len = std.math.maxInt(usize);
        return e;
    }
};

// TODO improve memory usage
pub const Record = struct {
    name: []const u8,
    fields: []Field,
    size: u64,
    alignment: u29,

    pub const Field = struct {
        name: []const u8,
        ty: Type,
        /// zero for anonymous fields
        name_tok: TokenIndex = 0,
        bit_width: u32 = 0,

        pub fn isAnonymousRecord(f: Field) bool {
            return f.name_tok == 0 and f.ty.isRecord();
        }
    };

    pub fn isIncomplete(r: Record) bool {
        return r.fields.len == std.math.maxInt(usize);
    }

    pub fn create(allocator: std.mem.Allocator, name: []const u8) !*Record {
        var r = try allocator.create(Record);
        r.name = name;
        r.fields.len = std.math.maxInt(usize);
        return r;
    }
};

pub const Specifier = enum {
    void,
    bool,

    // integers
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

    // floating point numbers
    float,
    double,
    long_double,
    complex_float,
    complex_double,
    complex_long_double,

    // data.sub_type
    pointer,
    unspecified_variable_len_array,
    decayed_unspecified_variable_len_array,
    // data.func
    /// int foo(int bar, char baz) and int (void)
    func,
    /// int foo(int bar, char baz, ...)
    var_args_func,
    /// int foo(bar, baz) and int foo()
    /// is also var args, but we can give warnings about incorrect amounts of parameters
    old_style_func,

    // data.array
    array,
    decayed_array,
    static_array,
    decayed_static_array,
    incomplete_array,
    decayed_incomplete_array,
    // data.expr
    variable_len_array,
    decayed_variable_len_array,

    // data.record
    @"struct",
    @"union",

    // data.enum
    @"enum",

    /// typeof(type-name)
    typeof_type,
    /// decayed array created with typeof(type-name)
    decayed_typeof_type,

    /// typeof(expression)
    typeof_expr,
    /// decayed array created with typeof(expression)
    decayed_typeof_expr,

    /// data.attributed
    attributed,

    /// special type used to implement __builtin_va_start
    special_va_start,
};

/// All fields of Type except data may be mutated
data: union {
    sub_type: *Type,
    func: *Func,
    array: *Array,
    expr: *Expr,
    @"enum": *Enum,
    record: *Record,
    attributed: *Attributed,
    none: void,
} = .{ .none = {} },
specifier: Specifier,
qual: Qualifiers = .{},

/// Determine if type matches the given specifier, recursing into typeof
/// types if necessary.
pub fn is(ty: Type, specifier: Specifier) bool {
    std.debug.assert(specifier != .typeof_type and specifier != .typeof_expr);
    return ty.get(specifier) != null;
}

pub fn withAttributes(self: Type, allocator: std.mem.Allocator, attributes: []const Attribute) !Type {
    if (attributes.len == 0) return self;
    const attributed_type = try Type.Attributed.create(allocator, self, attributes);
    return Type{ .specifier = .attributed, .data = .{ .attributed = attributed_type } };
}

pub fn isCallable(ty: Type) ?Type {
    return switch (ty.specifier) {
        .func, .var_args_func, .old_style_func => ty,
        .pointer => if (ty.data.sub_type.isFunc()) ty.data.sub_type.* else null,
        .typeof_type => ty.data.sub_type.isCallable(),
        .typeof_expr => ty.data.expr.ty.isCallable(),
        .attributed => ty.data.attributed.base.isCallable(),
        else => null,
    };
}

pub fn isFunc(ty: Type) bool {
    return switch (ty.specifier) {
        .func, .var_args_func, .old_style_func => true,
        .typeof_type => ty.data.sub_type.isFunc(),
        .typeof_expr => ty.data.expr.ty.isFunc(),
        .attributed => ty.data.attributed.base.isFunc(),
        else => false,
    };
}

pub fn isArray(ty: Type) bool {
    return switch (ty.specifier) {
        .array, .static_array, .incomplete_array, .variable_len_array, .unspecified_variable_len_array => true,
        .typeof_type => ty.data.sub_type.isArray(),
        .typeof_expr => ty.data.expr.ty.isArray(),
        .attributed => ty.data.attributed.base.isArray(),
        else => false,
    };
}

pub fn isPtr(ty: Type) bool {
    return switch (ty.specifier) {
        .pointer,
        .decayed_array,
        .decayed_static_array,
        .decayed_incomplete_array,
        .decayed_variable_len_array,
        .decayed_unspecified_variable_len_array,
        .decayed_typeof_type,
        .decayed_typeof_expr,
        => true,
        .typeof_type => ty.data.sub_type.isPtr(),
        .typeof_expr => ty.data.expr.ty.isPtr(),
        .attributed => ty.data.attributed.base.isPtr(),
        else => false,
    };
}

pub fn isInt(ty: Type) bool {
    return switch (ty.specifier) {
        .@"enum", .bool, .char, .schar, .uchar, .short, .ushort, .int, .uint, .long, .ulong, .long_long, .ulong_long => true,
        .typeof_type => ty.data.sub_type.isInt(),
        .typeof_expr => ty.data.expr.ty.isInt(),
        .attributed => ty.data.attributed.base.isInt(),
        else => false,
    };
}

pub fn isFloat(ty: Type) bool {
    return switch (ty.specifier) {
        .float, .double, .long_double, .complex_float, .complex_double, .complex_long_double => true,
        .typeof_type => ty.data.sub_type.isFloat(),
        .typeof_expr => ty.data.expr.ty.isFloat(),
        .attributed => ty.data.attributed.base.isFloat(),
        else => false,
    };
}

pub fn isReal(ty: Type) bool {
    return switch (ty.specifier) {
        .complex_float, .complex_double, .complex_long_double => false,
        .typeof_type => ty.data.sub_type.isReal(),
        .typeof_expr => ty.data.expr.ty.isReal(),
        .attributed => ty.data.attributed.base.isReal(),
        else => true,
    };
}

pub fn isVoidStar(ty: Type) bool {
    return switch (ty.specifier) {
        .pointer => ty.data.sub_type.specifier == .void,
        .typeof_type => ty.data.sub_type.isVoidStar(),
        .typeof_expr => ty.data.expr.ty.isVoidStar(),
        .attributed => ty.data.attributed.base.isVoidStar(),
        else => false,
    };
}

pub fn isTypeof(ty: Type) bool {
    return switch (ty.specifier) {
        .typeof_type, .typeof_expr, .decayed_typeof_type, .decayed_typeof_expr => true,
        else => false,
    };
}

pub fn isConst(ty: Type) bool {
    return switch (ty.specifier) {
        .typeof_type, .decayed_typeof_type => ty.qual.@"const" or ty.data.sub_type.isConst(),
        .typeof_expr, .decayed_typeof_expr => ty.qual.@"const" or ty.data.expr.ty.isConst(),
        .attributed => ty.data.attributed.base.isConst(),
        else => ty.qual.@"const",
    };
}

pub fn isUnsignedInt(ty: Type, comp: *Compilation) bool {
    return switch (ty.specifier) {
        .char => return getCharSignedness(comp) == .unsigned,
        .uchar, .ushort, .uint, .ulong, .ulong_long, .bool => true,
        .typeof_type => ty.data.sub_type.isUnsignedInt(comp),
        .typeof_expr => ty.data.expr.ty.isUnsignedInt(comp),
        .attributed => ty.data.attributed.base.isUnsignedInt(comp),
        else => false,
    };
}

pub fn isEnumOrRecord(ty: Type) bool {
    return switch (ty.specifier) {
        .@"enum", .@"struct", .@"union" => true,
        .typeof_type => ty.data.sub_type.isEnumOrRecord(),
        .typeof_expr => ty.data.expr.ty.isEnumOrRecord(),
        .attributed => ty.data.attributed.base.isEnumOrRecord(),
        else => false,
    };
}

pub fn isRecord(ty: Type) bool {
    return switch (ty.specifier) {
        .@"struct", .@"union" => true,
        .typeof_type => ty.data.sub_type.isRecord(),
        .typeof_expr => ty.data.expr.ty.isRecord(),
        .attributed => ty.data.attributed.base.isRecord(),
        else => false,
    };
}

pub fn isAnonymousRecord(ty: Type) bool {
    return switch (ty.specifier) {
        // anonymous records can be recognized by their names which are in
        // the format "(anonymous TAG at path:line:col)".
        .@"struct", .@"union" => ty.data.record.name[0] == '(',
        .typeof_type => ty.data.sub_type.isAnonymousRecord(),
        .typeof_expr => ty.data.expr.ty.isAnonymousRecord(),
        .attributed => ty.data.attributed.base.isAnonymousRecord(),
        else => false,
    };
}

pub fn elemType(ty: Type) Type {
    return switch (ty.specifier) {
        .pointer, .unspecified_variable_len_array, .decayed_unspecified_variable_len_array => ty.data.sub_type.*,
        .array, .static_array, .incomplete_array, .decayed_array, .decayed_static_array, .decayed_incomplete_array => ty.data.array.elem,
        .variable_len_array, .decayed_variable_len_array => ty.data.expr.ty,
        .typeof_type, .decayed_typeof_type, .typeof_expr, .decayed_typeof_expr => {
            const unwrapped = ty.canonicalize(.preserve_quals);
            var elem = unwrapped.elemType();
            elem.qual = elem.qual.mergeAll(unwrapped.qual);
            return elem;
        },
        .attributed => ty.data.attributed.base,
        else => unreachable,
    };
}

pub fn returnType(ty: Type) Type {
    return switch (ty.specifier) {
        .func, .var_args_func, .old_style_func => ty.data.func.return_type,
        .typeof_type, .decayed_typeof_type => ty.data.sub_type.returnType(),
        .typeof_expr, .decayed_typeof_expr => ty.data.expr.ty.returnType(),
        .attributed => ty.data.attributed.base.returnType(),
        else => unreachable,
    };
}

pub fn params(ty: Type) []Func.Param {
    return switch (ty.specifier) {
        .func, .var_args_func, .old_style_func => ty.data.func.params,
        .typeof_type, .decayed_typeof_type => ty.data.sub_type.params(),
        .typeof_expr, .decayed_typeof_expr => ty.data.expr.ty.params(),
        .attributed => ty.data.attributed.base.params(),
        else => unreachable,
    };
}

pub fn arrayLen(ty: Type) ?usize {
    return switch (ty.specifier) {
        .array, .static_array, .decayed_array, .decayed_static_array => ty.data.array.len,
        .typeof_type, .decayed_typeof_type => ty.data.sub_type.arrayLen(),
        .typeof_expr, .decayed_typeof_expr => ty.data.expr.ty.arrayLen(),
        .attributed => ty.data.attributed.base.arrayLen(),
        else => null,
    };
}

pub fn anyQual(ty: Type) bool {
    return switch (ty.specifier) {
        .typeof_type => ty.qual.any() or ty.data.sub_type.anyQual(),
        .typeof_expr => ty.qual.any() or ty.data.expr.ty.anyQual(),
        else => ty.qual.any(),
    };
}

pub fn getAttributes(ty: Type) []const Attribute {
    return switch (ty.specifier) {
        .attributed => ty.data.attributed.attributes,
        .typeof_type, .decayed_typeof_type => ty.data.sub_type.getAttributes(),
        .typeof_expr, .decayed_typeof_expr => ty.data.expr.ty.getAttributes(),
        else => &.{},
    };
}

pub fn integerPromotion(ty: Type, comp: *Compilation) Type {
    var specifier = ty.specifier;
    if (specifier == .@"enum") {
        if (ty.hasIncompleteSize()) return .{ .specifier = .int };
        specifier = ty.data.@"enum".tag_ty.specifier;
    }
    return .{
        .specifier = switch (specifier) {
            .bool, .char, .schar, .uchar, .short => .int,
            .ushort => if (ty.sizeof(comp).? == sizeof(.{ .specifier = .int }, comp)) Specifier.uint else .int,
            .int => .int,
            .uint => .uint,
            .long => .long,
            .ulong => .ulong,
            .long_long => .long_long,
            .ulong_long => .ulong_long,
            .typeof_type => return ty.data.sub_type.integerPromotion(comp),
            .typeof_expr => return ty.data.expr.ty.integerPromotion(comp),
            .attributed => return ty.data.attributed.base.integerPromotion(comp),
            else => unreachable, // not an integer type
        },
    };
}

pub fn hasIncompleteSize(ty: Type) bool {
    return switch (ty.specifier) {
        .void, .incomplete_array => true,
        .@"enum" => ty.data.@"enum".isIncomplete(),
        .@"struct", .@"union" => ty.data.record.isIncomplete(),
        .array, .static_array => ty.data.array.elem.hasIncompleteSize(),
        .typeof_type => ty.data.sub_type.hasIncompleteSize(),
        .typeof_expr => ty.data.expr.ty.hasIncompleteSize(),
        .attributed => ty.data.attributed.base.hasIncompleteSize(),
        else => false,
    };
}

pub fn hasUnboundVLA(ty: Type) bool {
    var cur = ty;
    while (true) {
        switch (cur.specifier) {
            .unspecified_variable_len_array,
            .decayed_unspecified_variable_len_array,
            => return true,
            .array,
            .static_array,
            .incomplete_array,
            .variable_len_array,
            .decayed_array,
            .decayed_static_array,
            .decayed_incomplete_array,
            .decayed_variable_len_array,
            => cur = cur.elemType(),
            .typeof_type, .decayed_typeof_type => cur = cur.data.sub_type.*,
            .typeof_expr, .decayed_typeof_expr => cur = cur.data.expr.ty,
            .attributed => cur = cur.data.attributed.base,
            else => return false,
        }
    }
}

pub fn hasField(ty: Type, name: []const u8) bool {
    switch (ty.specifier) {
        .@"struct" => {
            std.debug.assert(!ty.data.record.isIncomplete());
            for (ty.data.record.fields) |f| {
                if (f.isAnonymousRecord() and f.ty.hasField(name)) return true;
                if (std.mem.eql(u8, name, f.name)) return true;
            }
        },
        .@"union" => {
            std.debug.assert(!ty.data.record.isIncomplete());
            for (ty.data.record.fields) |f| {
                if (f.isAnonymousRecord() and f.ty.hasField(name)) return true;
                if (std.mem.eql(u8, name, f.name)) return true;
            }
        },
        .typeof_type => return ty.data.sub_type.hasField(name),
        .typeof_expr => return ty.data.expr.ty.hasField(name),
        .attributed => return ty.data.attributed.base.hasField(name),
        else => unreachable,
    }
    return false;
}

pub fn getCharSignedness(comp: *Compilation) std.builtin.Signedness {
    switch (comp.target.cpu.arch) {
        .aarch64,
        .aarch64_32,
        .aarch64_be,
        .arm,
        .armeb,
        .thumb,
        .thumbeb,
        => return if (comp.target.os.tag.isDarwin() or comp.target.os.tag == .windows) .signed else .unsigned,
        .powerpc, .powerpc64 => return if (comp.target.os.tag.isDarwin()) .signed else .unsigned,
        .powerpc64le,
        .s390x,
        .xcore,
        .arc,
        => return .unsigned,
        else => return .signed,
    }
}

/// Size of type as reported by sizeof
pub fn sizeof(ty: Type, comp: *Compilation) ?u64 {
    // TODO get target from compilation
    return switch (ty.specifier) {
        .variable_len_array, .unspecified_variable_len_array, .incomplete_array => return null,
        .func, .var_args_func, .old_style_func, .void, .bool => 1,
        .char, .schar, .uchar => 1,
        .short, .ushort => 2,
        .int, .uint => 4,
        .long, .ulong => switch (comp.target.os.tag) {
            .linux,
            .macos,
            .freebsd,
            .netbsd,
            .dragonfly,
            .openbsd,
            .wasi,
            .emscripten,
            => comp.target.cpu.arch.ptrBitWidth() >> 3,
            .windows, .uefi => 4,
            else => 4,
        },
        .long_long, .ulong_long => 8,
        .float => 4,
        .double => 8,
        .long_double => 16,
        .complex_float => 8,
        .complex_double => 16,
        .complex_long_double => 32,
        .pointer,
        .decayed_array,
        .decayed_static_array,
        .decayed_incomplete_array,
        .decayed_variable_len_array,
        .decayed_unspecified_variable_len_array,
        .decayed_typeof_type,
        .decayed_typeof_expr,
        .static_array,
        => comp.target.cpu.arch.ptrBitWidth() >> 3,
        .array => ty.data.array.elem.sizeof(comp).? * ty.data.array.len,
        .@"struct", .@"union" => if (ty.data.record.isIncomplete()) null else ty.data.record.size,
        .@"enum" => if (ty.data.@"enum".isIncomplete()) null else ty.data.@"enum".tag_ty.sizeof(comp),
        .typeof_type => ty.data.sub_type.sizeof(comp),
        .typeof_expr => ty.data.expr.ty.sizeof(comp),
        .attributed => ty.data.attributed.base.sizeof(comp),
        else => unreachable,
    };
}

pub fn bitSizeof(ty: Type, comp: *Compilation) ?u64 {
    return switch (ty.specifier) {
        .bool => 1,
        .typeof_type, .decayed_typeof_type => ty.data.sub_type.bitSizeof(comp),
        .typeof_expr, .decayed_typeof_expr => ty.data.expr.ty.bitSizeof(comp),
        .attributed => ty.data.attributed.base.bitSizeof(comp),
        else => 8 * (ty.sizeof(comp) orelse return null),
    };
}

/// Get the alignment of a type
pub fn alignof(ty: Type, comp: *const Compilation) u29 {
    if (ty.requestedAlignment(comp)) |requested| return requested;

    // TODO get target from compilation
    return switch (ty.specifier) {
        .unspecified_variable_len_array => unreachable, // must be bound in function definition
        .variable_len_array, .incomplete_array => ty.elemType().alignof(comp),
        .func, .var_args_func, .old_style_func => 4, // TODO check target
        .char, .schar, .uchar, .void, .bool => 1,
        .short, .ushort => 2,
        .int, .uint => 4,
        .long, .ulong => switch (comp.target.os.tag) {
            .linux,
            .macos,
            .freebsd,
            .netbsd,
            .dragonfly,
            .openbsd,
            .wasi,
            .emscripten,
            => comp.target.cpu.arch.ptrBitWidth() >> 3,
            .windows, .uefi => 4,
            else => 4,
        },
        .long_long, .ulong_long => 8,
        .float, .complex_float => 4,
        .double, .complex_double => 8,
        .long_double, .complex_long_double => 16,
        .pointer,
        .decayed_array,
        .decayed_static_array,
        .decayed_incomplete_array,
        .decayed_variable_len_array,
        .decayed_unspecified_variable_len_array,
        .static_array,
        => comp.target.cpu.arch.ptrBitWidth() >> 3,
        .array => ty.data.array.elem.alignof(comp),
        .@"struct", .@"union" => if (ty.data.record.isIncomplete()) 0 else ty.data.record.alignment,
        .@"enum" => if (ty.data.@"enum".isIncomplete()) 0 else ty.data.@"enum".tag_ty.alignof(comp),
        .typeof_type, .decayed_typeof_type => ty.data.sub_type.alignof(comp),
        .typeof_expr, .decayed_typeof_expr => ty.data.expr.ty.alignof(comp),
        .attributed => ty.data.attributed.base.alignof(comp),
        else => unreachable,
    };
}

/// Canonicalize a possibly-typeof() type. If the type is not a typeof() type, simply
/// return it. Otherwise, determine the actual qualified type.
/// The `qual_handling` parameter can be used to return the full set of qualifiers
/// added by typeof() operations, which is useful when determining the elemType of
/// arrays and pointers.
pub fn canonicalize(ty: Type, qual_handling: enum { standard, preserve_quals }) Type {
    var cur = ty;
    if (cur.specifier == .attributed) cur = cur.data.attributed.base;
    if (!cur.isTypeof()) return cur;

    var qual = cur.qual;
    while (true) {
        switch (cur.specifier) {
            .typeof_type => cur = cur.data.sub_type.*,
            .typeof_expr => cur = cur.data.expr.ty,
            .decayed_typeof_type => {
                cur = cur.data.sub_type.*;
                cur.decayArray();
            },
            .decayed_typeof_expr => {
                cur = cur.data.expr.ty;
                cur.decayArray();
            },
            else => break,
        }
        qual = qual.mergeAll(cur.qual);
    }
    if ((cur.isArray() or cur.isPtr()) and qual_handling == .standard) {
        cur.qual = .{};
    } else {
        cur.qual = qual;
    }
    return cur;
}

pub fn get(ty: *const Type, specifier: Specifier) ?*const Type {
    std.debug.assert(specifier != .typeof_type and specifier != .typeof_expr);
    return switch (ty.specifier) {
        .typeof_type => ty.data.sub_type.get(specifier),
        .typeof_expr => ty.data.expr.ty.get(specifier),
        .attributed => ty.data.attributed.base.get(specifier),
        else => if (ty.specifier == specifier) ty else null,
    };
}

fn requestedAlignment(ty: Type, comp: *const Compilation) ?u29 {
    return switch (ty.specifier) {
        .typeof_type, .decayed_typeof_type => ty.data.sub_type.requestedAlignment(comp),
        .typeof_expr, .decayed_typeof_expr => ty.data.expr.ty.requestedAlignment(comp),
        .attributed => {
            var max_requested: ?u29 = null;
            for (ty.data.attributed.attributes) |attribute| {
                if (attribute.tag != .aligned) continue;
                const requested = if (attribute.args.aligned.alignment) |alignment|
                    alignment.requested
                else
                    comp.defaultAlignment();

                if (max_requested == null or max_requested.? < requested) {
                    max_requested = requested;
                }
            }
            return max_requested;
        },
        else => null,
    };
}

pub fn eql(a_param: Type, b_param: Type, comp: *const Compilation, check_qualifiers: bool) bool {
    const a = a_param.canonicalize(.standard);
    const b = b_param.canonicalize(.standard);

    if (a.alignof(comp) != b.alignof(comp)) return false;
    if (a.isPtr()) {
        if (!b.isPtr()) return false;
    } else if (a.isFunc()) {
        if (!b.isFunc()) return false;
    } else if (a.isArray()) {
        if (!b.isArray()) return false;
    } else if (a.specifier != b.specifier) return false;

    if (a.qual.atomic != b.qual.atomic) return false;
    if (check_qualifiers) {
        if (a.qual.@"const" != b.qual.@"const") return false;
        if (a.qual.@"volatile" != b.qual.@"volatile") return false;
    }

    switch (a.specifier) {
        .pointer,
        .decayed_array,
        .decayed_static_array,
        .decayed_incomplete_array,
        .decayed_variable_len_array,
        .decayed_unspecified_variable_len_array,
        => if (!a_param.elemType().eql(b_param.elemType(), comp, check_qualifiers)) return false,

        .func,
        .var_args_func,
        .old_style_func,
        => {
            // TODO validate this
            if (a.data.func.params.len != b.data.func.params.len) return false;
            // return type cannot have qualifiers
            if (!a.returnType().eql(b.returnType(), comp, false)) return false;
            for (a.data.func.params) |param, i| {
                var a_unqual = param.ty;
                a_unqual.qual.@"const" = false;
                a_unqual.qual.@"volatile" = false;
                var b_unqual = b.data.func.params[i].ty;
                b_unqual.qual.@"const" = false;
                b_unqual.qual.@"volatile" = false;
                if (!a_unqual.eql(b_unqual, comp, check_qualifiers)) return false;
            }
        },

        .array,
        .static_array,
        .incomplete_array,
        => {
            if (!std.meta.eql(a.arrayLen(), b.arrayLen())) return false;
            if (!a.elemType().eql(b.elemType(), comp, check_qualifiers)) return false;
        },
        .variable_len_array => if (!a.elemType().eql(b.elemType(), comp, check_qualifiers)) return false,

        .@"struct", .@"union" => if (a.data.record != b.data.record) return false,
        .@"enum" => if (a.data.@"enum" != b.data.@"enum") return false,

        else => {},
    }
    return true;
}

/// Decays an array to a pointer
pub fn decayArray(ty: *Type) void {
    // the decayed array type is the current specifier +1
    ty.specifier = @intToEnum(Type.Specifier, @enumToInt(ty.specifier) + 1);
}

pub fn combine(inner: *Type, outer: Type, p: *Parser, source_tok: TokenIndex) Parser.Error!void {
    switch (inner.specifier) {
        .pointer => return inner.data.sub_type.combine(outer, p, source_tok),
        .unspecified_variable_len_array => {
            try inner.data.sub_type.combine(outer, p, source_tok);
        },
        .variable_len_array => {
            try inner.data.expr.ty.combine(outer, p, source_tok);
        },
        .array, .static_array, .incomplete_array => {
            try inner.data.array.elem.combine(outer, p, source_tok);
        },
        .func, .var_args_func, .old_style_func => {
            try inner.data.func.return_type.combine(outer, p, source_tok);
        },
        .decayed_array,
        .decayed_static_array,
        .decayed_incomplete_array,
        .decayed_variable_len_array,
        .decayed_unspecified_variable_len_array,
        .decayed_typeof_type,
        .decayed_typeof_expr,
        => unreachable, // type should not be able to decay before being combined
        else => inner.* = outer,
    }
}

pub fn validateCombinedType(ty: Type, p: *Parser, source_tok: TokenIndex) Parser.Error!void {
    switch (ty.specifier) {
        .pointer => return ty.data.sub_type.validateCombinedType(p, source_tok),
        .unspecified_variable_len_array,
        .variable_len_array,
        .array,
        .static_array,
        .incomplete_array,
        => {
            const elem_ty = ty.elemType();
            if (elem_ty.hasIncompleteSize()) {
                try p.errStr(.array_incomplete_elem, source_tok, try p.typeStr(elem_ty));
                return error.ParsingFailed;
            }
            if (elem_ty.isFunc()) {
                try p.errTok(.array_func_elem, source_tok);
                return error.ParsingFailed;
            }
            if (elem_ty.specifier == .static_array and elem_ty.isArray()) {
                try p.errTok(.static_non_outermost_array, source_tok);
            }
            if (elem_ty.anyQual() and elem_ty.isArray()) {
                try p.errTok(.qualifier_non_outermost_array, source_tok);
            }
        },
        .func, .var_args_func, .old_style_func => {
            const ret_ty = &ty.data.func.return_type;
            if (ret_ty.isArray()) try p.errTok(.func_cannot_return_array, source_tok);
            if (ret_ty.isFunc()) try p.errTok(.func_cannot_return_func, source_tok);
            if (ret_ty.qual.@"const") {
                try p.errStr(.qual_on_ret_type, source_tok, "const");
                ret_ty.qual.@"const" = false;
            }
            if (ret_ty.qual.@"volatile") {
                try p.errStr(.qual_on_ret_type, source_tok, "volatile");
                ret_ty.qual.@"volatile" = false;
            }
            if (ret_ty.qual.atomic) {
                try p.errStr(.qual_on_ret_type, source_tok, "atomic");
                ret_ty.qual.atomic = false;
            }
        },
        .typeof_type, .decayed_typeof_type => return ty.data.sub_type.validateCombinedType(p, source_tok),
        .typeof_expr, .decayed_typeof_expr => return ty.data.expr.ty.validateCombinedType(p, source_tok),
        .attributed => return ty.data.attributed.base.validateCombinedType(p, source_tok),
        else => {},
    }
}

/// An unfinished Type
pub const Builder = struct {
    typedef: ?struct {
        tok: TokenIndex,
        ty: Type,
    } = null,
    specifier: Builder.Specifier = .none,
    qual: Qualifiers.Builder = .{},
    typeof: ?Type = null,
    /// When true an error is returned instead of adding a diagnostic message.
    /// Used for trying to combine typedef types.
    error_on_invalid: bool = false,

    pub const Specifier = union(enum) {
        none,
        void,
        bool,
        char,
        schar,
        uchar,

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

        float,
        double,
        long_double,
        complex,
        complex_long,
        complex_float,
        complex_double,
        complex_long_double,

        pointer: *Type,
        unspecified_variable_len_array: *Type,
        decayed_unspecified_variable_len_array: *Type,
        func: *Func,
        var_args_func: *Func,
        old_style_func: *Func,
        array: *Array,
        decayed_array: *Array,
        static_array: *Array,
        decayed_static_array: *Array,
        incomplete_array: *Array,
        decayed_incomplete_array: *Array,
        variable_len_array: *Expr,
        decayed_variable_len_array: *Expr,
        @"struct": *Record,
        @"union": *Record,
        @"enum": *Enum,
        typeof_type: *Type,
        decayed_typeof_type: *Type,
        typeof_expr: *Expr,
        decayed_typeof_expr: *Expr,

        attributed: *Attributed,

        pub fn str(spec: Builder.Specifier) ?[]const u8 {
            return switch (spec) {
                .none => unreachable,
                .void => "void",
                .bool => "_Bool",
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

                .float => "float",
                .double => "double",
                .long_double => "long double",
                .complex => "_Complex",
                .complex_long => "_Complex long",
                .complex_float => "_Complex float",
                .complex_double => "_Complex double",
                .complex_long_double => "_Complex long double",

                .attributed => |attributed| Builder.fromType(attributed.base).str(),

                else => null,
            };
        }
    };

    pub fn finish(b: Builder, p: *Parser, attr_buf_start: usize) Parser.Error!Type {
        var ty: Type = .{ .specifier = undefined };
        switch (b.specifier) {
            .none => {
                if (b.typeof) |typeof| {
                    ty = typeof;
                } else {
                    ty.specifier = .int;
                    try p.err(.missing_type_specifier);
                }
            },
            .void => ty.specifier = .void,
            .bool => ty.specifier = .bool,
            .char => ty.specifier = .char,
            .schar => ty.specifier = .schar,
            .uchar => ty.specifier = .uchar,

            .unsigned => ty.specifier = .uint,
            .signed => ty.specifier = .int,
            .short_int, .sshort_int, .short, .sshort => ty.specifier = .short,
            .ushort, .ushort_int => ty.specifier = .ushort,
            .int, .sint => ty.specifier = .int,
            .uint => ty.specifier = .uint,
            .long, .slong, .long_int, .slong_int => ty.specifier = .long,
            .ulong, .ulong_int => ty.specifier = .ulong,
            .long_long, .slong_long, .long_long_int, .slong_long_int => ty.specifier = .long_long,
            .ulong_long, .ulong_long_int => ty.specifier = .ulong_long,

            .float => ty.specifier = .float,
            .double => ty.specifier = .double,
            .long_double => ty.specifier = .long_double,
            .complex_float => ty.specifier = .complex_float,
            .complex_double => ty.specifier = .complex_double,
            .complex_long_double => ty.specifier = .complex_long_double,
            .complex => {
                try p.errTok(.plain_complex, p.tok_i - 1);
                ty.specifier = .complex_double;
            },
            .complex_long => {
                try p.errExtra(.type_is_invalid, p.tok_i, .{ .str = b.specifier.str().? });
                return error.ParsingFailed;
            },

            .pointer => |data| {
                ty.specifier = .pointer;
                ty.data = .{ .sub_type = data };
            },
            .unspecified_variable_len_array => |data| {
                ty.specifier = .unspecified_variable_len_array;
                ty.data = .{ .sub_type = data };
            },
            .decayed_unspecified_variable_len_array => |data| {
                ty.specifier = .decayed_unspecified_variable_len_array;
                ty.data = .{ .sub_type = data };
            },
            .func => |data| {
                ty.specifier = .func;
                ty.data = .{ .func = data };
            },
            .var_args_func => |data| {
                ty.specifier = .var_args_func;
                ty.data = .{ .func = data };
            },
            .old_style_func => |data| {
                ty.specifier = .old_style_func;
                ty.data = .{ .func = data };
            },
            .array => |data| {
                ty.specifier = .array;
                ty.data = .{ .array = data };
            },
            .decayed_array => |data| {
                ty.specifier = .decayed_array;
                ty.data = .{ .array = data };
            },
            .static_array => |data| {
                ty.specifier = .static_array;
                ty.data = .{ .array = data };
            },
            .decayed_static_array => |data| {
                ty.specifier = .decayed_static_array;
                ty.data = .{ .array = data };
            },
            .incomplete_array => |data| {
                ty.specifier = .incomplete_array;
                ty.data = .{ .array = data };
            },
            .decayed_incomplete_array => |data| {
                ty.specifier = .decayed_incomplete_array;
                ty.data = .{ .array = data };
            },
            .variable_len_array => |data| {
                ty.specifier = .variable_len_array;
                ty.data = .{ .expr = data };
            },
            .decayed_variable_len_array => |data| {
                ty.specifier = .decayed_variable_len_array;
                ty.data = .{ .expr = data };
            },
            .@"struct" => |data| {
                ty.specifier = .@"struct";
                ty.data = .{ .record = data };
            },
            .@"union" => |data| {
                ty.specifier = .@"union";
                ty.data = .{ .record = data };
            },
            .@"enum" => |data| {
                ty.specifier = .@"enum";
                ty.data = .{ .@"enum" = data };
            },
            .typeof_type => |data| {
                ty.specifier = .typeof_type;
                ty.data = .{ .sub_type = data };
            },
            .decayed_typeof_type => |data| {
                ty.specifier = .decayed_typeof_type;
                ty.data = .{ .sub_type = data };
            },
            .typeof_expr => |data| {
                ty.specifier = .typeof_expr;
                ty.data = .{ .expr = data };
            },
            .decayed_typeof_expr => |data| {
                ty.specifier = .decayed_typeof_expr;
                ty.data = .{ .expr = data };
            },
            .attributed => |data| {
                ty.specifier = .attributed;
                ty.data = .{ .attributed = data };
            },
        }
        try b.qual.finish(p, &ty);

        return p.withAttributes(ty, attr_buf_start);
    }

    fn cannotCombine(b: Builder, p: *Parser, source_tok: TokenIndex) !void {
        if (b.error_on_invalid) return error.CannotCombine;
        const ty_str = b.specifier.str() orelse try p.typeStr(try b.finish(p, p.attr_buf.len));
        try p.errExtra(.cannot_combine_spec, source_tok, .{ .str = ty_str });
        if (b.typedef) |some| try p.errStr(.spec_from_typedef, some.tok, try p.typeStr(some.ty));
    }

    fn duplicateSpec(b: *Builder, p: *Parser, spec: []const u8) !void {
        if (b.error_on_invalid) return error.CannotCombine;
        try p.errStr(.duplicate_decl_spec, p.tok_i, spec);
    }

    pub fn combineFromTypeof(b: *Builder, p: *Parser, new: Type, source_tok: TokenIndex) Compilation.Error!void {
        if (b.typeof != null) return p.errStr(.cannot_combine_spec, source_tok, "typeof");
        if (b.specifier != .none) return p.errStr(.invalid_typeof, source_tok, @tagName(b.specifier));
        const inner = switch (new.specifier) {
            .typeof_type => new.data.sub_type.*,
            .typeof_expr => new.data.expr.ty,
            else => unreachable,
        };

        b.typeof = switch (inner.specifier) {
            .attributed => inner.data.attributed.base,
            else => new,
        };
    }

    /// Try to combine type from typedef, returns true if successful.
    pub fn combineTypedef(b: *Builder, p: *Parser, typedef_ty: Type, name_tok: TokenIndex) bool {
        b.error_on_invalid = true;
        defer b.error_on_invalid = false;

        const new_spec = fromType(typedef_ty);
        b.combineExtra(p, new_spec, 0) catch |err| switch (err) {
            error.FatalError => unreachable, // we do not add any diagnostics
            error.OutOfMemory => unreachable, // we do not add any diagnostics
            error.ParsingFailed => unreachable, // we do not add any diagnostics
            error.CannotCombine => return false,
        };
        b.typedef = .{ .tok = name_tok, .ty = typedef_ty };
        return true;
    }

    pub fn combine(b: *Builder, p: *Parser, new: Builder.Specifier, source_tok: TokenIndex) !void {
        b.combineExtra(p, new, source_tok) catch |err| switch (err) {
            error.CannotCombine => unreachable,
            else => |e| return e,
        };
    }

    fn combineExtra(b: *Builder, p: *Parser, new: Builder.Specifier, source_tok: TokenIndex) !void {
        if (b.typeof != null) {
            if (b.error_on_invalid) return error.CannotCombine;
            try p.errStr(.invalid_typeof, source_tok, @tagName(new));
        }

        switch (new) {
            else => switch (b.specifier) {
                .none => b.specifier = new,
                else => return b.cannotCombine(p, source_tok),
            },
            .signed => b.specifier = switch (b.specifier) {
                .none => .signed,
                .char => .schar,
                .short => .sshort,
                .short_int => .sshort_int,
                .int => .sint,
                .long => .slong,
                .long_int => .slong_int,
                .long_long => .slong_long,
                .long_long_int => .slong_long_int,
                .sshort,
                .sshort_int,
                .sint,
                .slong,
                .slong_int,
                .slong_long,
                .slong_long_int,
                => return b.duplicateSpec(p, "signed"),
                else => return b.cannotCombine(p, source_tok),
            },
            .unsigned => b.specifier = switch (b.specifier) {
                .none => .unsigned,
                .char => .uchar,
                .short => .ushort,
                .short_int => .ushort_int,
                .int => .uint,
                .long => .ulong,
                .long_int => .ulong_int,
                .long_long => .ulong_long,
                .long_long_int => .ulong_long_int,
                .ushort,
                .ushort_int,
                .uint,
                .ulong,
                .ulong_int,
                .ulong_long,
                .ulong_long_int,
                => return b.duplicateSpec(p, "unsigned"),
                else => return b.cannotCombine(p, source_tok),
            },
            .char => b.specifier = switch (b.specifier) {
                .none => .char,
                .unsigned => .uchar,
                .signed => .schar,
                .char, .schar, .uchar => return b.duplicateSpec(p, "char"),
                else => return b.cannotCombine(p, source_tok),
            },
            .short => b.specifier = switch (b.specifier) {
                .none => .short,
                .unsigned => .ushort,
                .signed => .sshort,
                else => return b.cannotCombine(p, source_tok),
            },
            .int => b.specifier = switch (b.specifier) {
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
                .int,
                .sint,
                .uint,
                .short_int,
                .sshort_int,
                .ushort_int,
                .long_int,
                .slong_int,
                .ulong_int,
                .long_long_int,
                .slong_long_int,
                .ulong_long_int,
                => return b.duplicateSpec(p, "int"),
                else => return b.cannotCombine(p, source_tok),
            },
            .long => b.specifier = switch (b.specifier) {
                .none => .long,
                .long => .long_long,
                .unsigned => .ulong,
                .signed => .long,
                .int => .long_int,
                .sint => .slong_int,
                .ulong => .ulong_long,
                .long_long, .ulong_long => return b.duplicateSpec(p, "long"),
                .complex => .complex_long,
                else => return b.cannotCombine(p, source_tok),
            },
            .float => b.specifier = switch (b.specifier) {
                .none => .float,
                .complex => .complex_float,
                .complex_float, .float => return b.duplicateSpec(p, "float"),
                else => return b.cannotCombine(p, source_tok),
            },
            .double => b.specifier = switch (b.specifier) {
                .none => .double,
                .long => .long_double,
                .complex_long => .complex_long_double,
                .complex => .complex_double,
                .long_double,
                .complex_long_double,
                .complex_double,
                .double,
                => return b.duplicateSpec(p, "double"),
                else => return b.cannotCombine(p, source_tok),
            },
            .complex => b.specifier = switch (b.specifier) {
                .none => .complex,
                .long => .complex_long,
                .float => .complex_float,
                .double => .complex_double,
                .long_double => .complex_long_double,
                .complex,
                .complex_long,
                .complex_float,
                .complex_double,
                .complex_long_double,
                => return b.duplicateSpec(p, "_Complex"),
                else => return b.cannotCombine(p, source_tok),
            },
        }
    }

    pub fn fromType(ty: Type) Builder.Specifier {
        return switch (ty.specifier) {
            .void => .void,
            .bool => .bool,
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
            .float => .float,
            .double => .double,
            .long_double => .long_double,
            .complex_float => .complex_float,
            .complex_double => .complex_double,
            .complex_long_double => .complex_long_double,

            .pointer => .{ .pointer = ty.data.sub_type },
            .unspecified_variable_len_array => .{ .unspecified_variable_len_array = ty.data.sub_type },
            .decayed_unspecified_variable_len_array => .{ .decayed_unspecified_variable_len_array = ty.data.sub_type },
            .func => .{ .func = ty.data.func },
            .var_args_func => .{ .var_args_func = ty.data.func },
            .old_style_func => .{ .old_style_func = ty.data.func },
            .array => .{ .array = ty.data.array },
            .decayed_array => .{ .decayed_array = ty.data.array },
            .static_array => .{ .static_array = ty.data.array },
            .decayed_static_array => .{ .decayed_static_array = ty.data.array },
            .incomplete_array => .{ .incomplete_array = ty.data.array },
            .decayed_incomplete_array => .{ .decayed_incomplete_array = ty.data.array },
            .variable_len_array => .{ .variable_len_array = ty.data.expr },
            .decayed_variable_len_array => .{ .decayed_variable_len_array = ty.data.expr },
            .@"struct" => .{ .@"struct" = ty.data.record },
            .@"union" => .{ .@"union" = ty.data.record },
            .@"enum" => .{ .@"enum" = ty.data.@"enum" },

            .typeof_type => .{ .typeof_type = ty.data.sub_type },
            .decayed_typeof_type => .{ .decayed_typeof_type = ty.data.sub_type },
            .typeof_expr => .{ .typeof_expr = ty.data.expr },
            .decayed_typeof_expr => .{ .decayed_typeof_expr = ty.data.expr },

            .attributed => .{ .attributed = ty.data.attributed },
            else => unreachable,
        };
    }
};

pub fn getAttribute(ty: Type, comptime tag: Attribute.Tag) ?Attribute.ArgumentsForTag(tag) {
    switch (ty.specifier) {
        .typeof_type => return ty.data.sub_type.getAttribute(tag),
        .typeof_expr => return ty.data.expr.ty.getAttribute(tag),
        .attributed => {
            for (ty.data.attributed.attributes) |attribute| {
                if (attribute.tag == tag) return @field(attribute.args, @tagName(tag));
            }
            return null;
        },
        else => return null,
    }
}

/// Print type in C style
pub fn print(ty: Type, w: anytype) @TypeOf(w).Error!void {
    _ = try ty.printPrologue(w);
    try ty.printEpilogue(w);
}

pub fn printNamed(ty: Type, name: []const u8, w: anytype) @TypeOf(w).Error!void {
    const simple = try ty.printPrologue(w);
    if (simple) try w.writeByte(' ');
    try w.writeAll(name);
    try ty.printEpilogue(w);
}

/// return true if `ty` is simple
fn printPrologue(ty: Type, w: anytype) @TypeOf(w).Error!bool {
    if (ty.qual.atomic) {
        var non_atomic_ty = ty;
        non_atomic_ty.qual.atomic = false;
        try w.writeAll("_Atomic(");
        try non_atomic_ty.print(w);
        try w.writeAll(")");
        return true;
    }
    switch (ty.specifier) {
        .pointer,
        .decayed_array,
        .decayed_static_array,
        .decayed_incomplete_array,
        .decayed_variable_len_array,
        .decayed_unspecified_variable_len_array,
        .decayed_typeof_type,
        .decayed_typeof_expr,
        => {
            const elem_ty = ty.elemType();
            const simple = try elem_ty.printPrologue(w);
            if (simple) try w.writeByte(' ');
            if (elem_ty.isFunc() or elem_ty.isArray()) try w.writeByte('(');
            try w.writeByte('*');
            try ty.qual.dump(w);
            return false;
        },
        .func, .var_args_func, .old_style_func => {
            const ret_ty = ty.data.func.return_type;
            const simple = try ret_ty.printPrologue(w);
            if (simple) try w.writeByte(' ');
            return false;
        },
        .array, .static_array, .incomplete_array, .unspecified_variable_len_array, .variable_len_array => {
            const elem_ty = ty.elemType();
            const simple = try elem_ty.printPrologue(w);
            if (simple) try w.writeByte(' ');
            return false;
        },
        .typeof_type, .typeof_expr => {
            const actual = ty.canonicalize(.standard);
            return actual.printPrologue(w);
        },
        .attributed => {
            const actual = ty.canonicalize(.standard);
            return actual.printPrologue(w);
        },
        else => {},
    }
    try ty.qual.dump(w);

    switch (ty.specifier) {
        .@"enum" => try w.print("enum {s}", .{ty.data.@"enum".name}),
        .@"struct" => try w.print("struct {s}", .{ty.data.record.name}),
        .@"union" => try w.print("union {s}", .{ty.data.record.name}),
        else => try w.writeAll(Builder.fromType(ty).str().?),
    }
    return true;
}

fn printEpilogue(ty: Type, w: anytype) @TypeOf(w).Error!void {
    if (ty.qual.atomic) return;
    switch (ty.specifier) {
        .pointer,
        .decayed_array,
        .decayed_static_array,
        .decayed_incomplete_array,
        .decayed_variable_len_array,
        .decayed_unspecified_variable_len_array,
        .decayed_typeof_type,
        .decayed_typeof_expr,
        => {
            const elem_ty = ty.elemType();
            if (elem_ty.isFunc() or elem_ty.isArray()) try w.writeByte(')');
            try elem_ty.printEpilogue(w);
        },
        .func, .var_args_func, .old_style_func => {
            try w.writeByte('(');
            for (ty.data.func.params) |param, i| {
                if (i != 0) try w.writeAll(", ");
                _ = try param.ty.printPrologue(w);
                try param.ty.printEpilogue(w);
            }
            if (ty.specifier != .func) {
                if (ty.data.func.params.len != 0) try w.writeAll(", ");
                try w.writeAll("...");
            } else if (ty.data.func.params.len == 0) {
                try w.writeAll("void");
            }
            try w.writeByte(')');
            try ty.data.func.return_type.printEpilogue(w);
        },
        .array, .static_array => {
            try w.writeByte('[');
            if (ty.specifier == .static_array) try w.writeAll("static ");
            try ty.qual.dump(w);
            try w.print("{d}]", .{ty.data.array.len});
            try ty.data.array.elem.printEpilogue(w);
        },
        .incomplete_array => {
            try w.writeByte('[');
            try ty.qual.dump(w);
            try w.writeByte(']');
            try ty.data.array.elem.printEpilogue(w);
        },
        .unspecified_variable_len_array => {
            try w.writeByte('[');
            try ty.qual.dump(w);
            try w.writeAll("*]");
            try ty.data.sub_type.printEpilogue(w);
        },
        .variable_len_array => {
            try w.writeByte('[');
            try ty.qual.dump(w);
            try w.writeAll("<expr>]");
            try ty.data.expr.ty.printEpilogue(w);
        },
        else => {},
    }
}

/// Useful for debugging, too noisy to be enabled by default.
const dump_detailed_containers = false;

// Print as Zig types since those are actually readable
pub fn dump(ty: Type, w: anytype) @TypeOf(w).Error!void {
    try ty.qual.dump(w);
    switch (ty.specifier) {
        .pointer => {
            try w.writeAll("*");
            try ty.data.sub_type.dump(w);
        },
        .func, .var_args_func, .old_style_func => {
            try w.writeAll("fn (");
            for (ty.data.func.params) |param, i| {
                if (i != 0) try w.writeAll(", ");
                if (param.name.len != 0) try w.print("{s}: ", .{param.name});
                try param.ty.dump(w);
            }
            if (ty.specifier != .func) {
                if (ty.data.func.params.len != 0) try w.writeAll(", ");
                try w.writeAll("...");
            }
            try w.writeAll(") ");
            try ty.data.func.return_type.dump(w);
        },
        .array, .static_array, .decayed_array, .decayed_static_array => {
            if (ty.specifier == .decayed_array or ty.specifier == .decayed_static_array) try w.writeByte('d');
            try w.writeByte('[');
            if (ty.specifier == .static_array or ty.specifier == .decayed_static_array) try w.writeAll("static ");
            try w.print("{d}]", .{ty.data.array.len});
            try ty.data.array.elem.dump(w);
        },
        .incomplete_array, .decayed_incomplete_array => {
            if (ty.specifier == .decayed_incomplete_array) try w.writeByte('d');
            try w.writeAll("[]");
            try ty.data.array.elem.dump(w);
        },
        .@"enum" => {
            try w.print("enum {s}", .{ty.data.@"enum".name});
            if (dump_detailed_containers) try dumpEnum(ty.data.@"enum", w);
        },
        .@"struct" => {
            try w.print("struct {s}", .{ty.data.record.name});
            if (dump_detailed_containers) try dumpRecord(ty.data.record, w);
        },
        .@"union" => {
            try w.print("union {s}", .{ty.data.record.name});
            if (dump_detailed_containers) try dumpRecord(ty.data.record, w);
        },
        .unspecified_variable_len_array, .decayed_unspecified_variable_len_array => {
            if (ty.specifier == .decayed_unspecified_variable_len_array) try w.writeByte('d');
            try w.writeAll("[*]");
            try ty.data.sub_type.dump(w);
        },
        .variable_len_array, .decayed_variable_len_array => {
            if (ty.specifier == .decayed_variable_len_array) try w.writeByte('d');
            try w.writeAll("[<expr>]");
            try ty.data.expr.ty.dump(w);
        },
        .typeof_type, .decayed_typeof_type => {
            try w.writeAll("typeof(");
            try ty.data.sub_type.dump(w);
            try w.writeAll(")");
        },
        .typeof_expr, .decayed_typeof_expr => {
            try w.writeAll("typeof(<expr>: ");
            try ty.data.expr.ty.dump(w);
            try w.writeAll(")");
        },
        .attributed => {
            try w.writeAll("attributed(");
            try ty.data.attributed.base.dump(w);
            try w.writeAll(")");
        },
        .special_va_start => try w.writeAll("(va start param)"),
        else => try w.writeAll(Builder.fromType(ty).str().?),
    }
}

fn dumpEnum(@"enum": *Enum, w: anytype) @TypeOf(w).Error!void {
    try w.writeAll(" {");
    for (@"enum".fields) |field| {
        try w.print(" {s} = {d},", .{ field.name, field.value });
    }
    try w.writeAll(" }");
}

fn dumpRecord(record: *Record, w: anytype) @TypeOf(w).Error!void {
    try w.writeAll(" {");
    for (record.fields) |field| {
        try w.writeByte(' ');
        try field.ty.dump(w);
        try w.print(" {s}: {d};", .{ field.name, field.bit_width });
    }
    try w.writeAll(" }");
}
