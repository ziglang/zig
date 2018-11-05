const std = @import("../index.zig");
const builtin = @import("builtin");
const debug = std.debug;
const mem = std.mem;
const math = std.math;

pub const trait = @import("trait.zig");

const TypeId = builtin.TypeId;
const TypeInfo = builtin.TypeInfo;

pub fn tagName(v: var) []const u8 {
    const T = @typeOf(v);
    switch (@typeInfo(T)) {
        TypeId.Enum => |info| {
            const Tag = info.tag_type;
            inline for (info.fields) |field| {
                if (field.value == @enumToInt(v)) return field.name;
            }

            unreachable;
        },
        TypeId.Union => |info| {
            const UnionTag = if (info.tag_type) |UT| UT else @compileError("union is untagged");
            const Tag = @typeInfo(UnionTag).Enum.tag_type;
            inline for (info.fields) |field| {
                if (field.enum_field.?.value == @enumToInt(UnionTag(v)))
                    return field.name;
            }

            unreachable;
        },
        TypeId.ErrorSet => |info| {
            inline for (info.errors) |err| {
                if (err.value == @errorToInt(v)) return err.name;
            }

            unreachable;
        },
        else => @compileError("expected enum, error set or union type, found '" ++ @typeName(T) ++ "'"),
    }
}

test "std.meta.tagName" {
    const E1 = enum.{
        A,
        B,
    };
    const E2 = enum(u8).{
        C = 33,
        D,
    };
    const U1 = union(enum).{
        G: u8,
        H: u16,
    };
    const U2 = union(E2).{
        C: u8,
        D: u16,
    };

    var u1g = U1.{ .G = 0 };
    var u1h = U1.{ .H = 0 };
    var u2a = U2.{ .C = 0 };
    var u2b = U2.{ .D = 0 };

    debug.assert(mem.eql(u8, tagName(E1.A), "A"));
    debug.assert(mem.eql(u8, tagName(E1.B), "B"));
    debug.assert(mem.eql(u8, tagName(E2.C), "C"));
    debug.assert(mem.eql(u8, tagName(E2.D), "D"));
    debug.assert(mem.eql(u8, tagName(error.E), "E"));
    debug.assert(mem.eql(u8, tagName(error.F), "F"));
    debug.assert(mem.eql(u8, tagName(u1g), "G"));
    debug.assert(mem.eql(u8, tagName(u1h), "H"));
    debug.assert(mem.eql(u8, tagName(u2a), "C"));
    debug.assert(mem.eql(u8, tagName(u2b), "D"));
}

pub fn bitCount(comptime T: type) u32 {
    return switch (@typeInfo(T)) {
        TypeId.Int => |info| info.bits,
        TypeId.Float => |info| info.bits,
        else => @compileError("Expected int or float type, found '" ++ @typeName(T) ++ "'"),
    };
}

test "std.meta.bitCount" {
    debug.assert(bitCount(u8) == 8);
    debug.assert(bitCount(f32) == 32);
}

pub fn alignment(comptime T: type) u29 {
    //@alignOf works on non-pointer types
    const P = if (comptime trait.is(TypeId.Pointer)(T)) T else *T;
    return @typeInfo(P).Pointer.alignment;
}

test "std.meta.alignment" {
    debug.assert(alignment(u8) == 1);
    debug.assert(alignment(*align(1) u8) == 1);
    debug.assert(alignment(*align(2) u8) == 2);
    debug.assert(alignment([]align(1) u8) == 1);
    debug.assert(alignment([]align(2) u8) == 2);
}

pub fn Child(comptime T: type) type {
    return switch (@typeInfo(T)) {
        TypeId.Array => |info| info.child,
        TypeId.Pointer => |info| info.child,
        TypeId.Optional => |info| info.child,
        TypeId.Promise => |info| if (info.child) |child| child else null,
        else => @compileError("Expected promise, pointer, optional, or array type, " ++ "found '" ++ @typeName(T) ++ "'"),
    };
}

test "std.meta.Child" {
    debug.assert(Child([1]u8) == u8);
    debug.assert(Child(*u8) == u8);
    debug.assert(Child([]u8) == u8);
    debug.assert(Child(?u8) == u8);
    debug.assert(Child(promise->u8) == u8);
}

pub fn containerLayout(comptime T: type) TypeInfo.ContainerLayout {
    return switch (@typeInfo(T)) {
        TypeId.Struct => |info| info.layout,
        TypeId.Enum => |info| info.layout,
        TypeId.Union => |info| info.layout,
        else => @compileError("Expected struct, enum or union type, found '" ++ @typeName(T) ++ "'"),
    };
}

test "std.meta.containerLayout" {
    const E1 = enum.{
        A,
    };
    const E2 = packed enum.{
        A,
    };
    const E3 = extern enum.{
        A,
    };
    const S1 = struct.{};
    const S2 = packed struct.{};
    const S3 = extern struct.{};
    const U1 = union.{
        a: u8,
    };
    const U2 = packed union.{
        a: u8,
    };
    const U3 = extern union.{
        a: u8,
    };

    debug.assert(containerLayout(E1) == TypeInfo.ContainerLayout.Auto);
    debug.assert(containerLayout(E2) == TypeInfo.ContainerLayout.Packed);
    debug.assert(containerLayout(E3) == TypeInfo.ContainerLayout.Extern);
    debug.assert(containerLayout(S1) == TypeInfo.ContainerLayout.Auto);
    debug.assert(containerLayout(S2) == TypeInfo.ContainerLayout.Packed);
    debug.assert(containerLayout(S3) == TypeInfo.ContainerLayout.Extern);
    debug.assert(containerLayout(U1) == TypeInfo.ContainerLayout.Auto);
    debug.assert(containerLayout(U2) == TypeInfo.ContainerLayout.Packed);
    debug.assert(containerLayout(U3) == TypeInfo.ContainerLayout.Extern);
}

pub fn definitions(comptime T: type) []TypeInfo.Definition {
    return switch (@typeInfo(T)) {
        TypeId.Struct => |info| info.defs,
        TypeId.Enum => |info| info.defs,
        TypeId.Union => |info| info.defs,
        else => @compileError("Expected struct, enum or union type, found '" ++ @typeName(T) ++ "'"),
    };
}

test "std.meta.definitions" {
    const E1 = enum.{
        A,

        fn a() void {}
    };
    const S1 = struct.{
        fn a() void {}
    };
    const U1 = union.{
        a: u8,

        fn a() void {}
    };

    const defs = comptime [][]TypeInfo.Definition.{
        definitions(E1),
        definitions(S1),
        definitions(U1),
    };

    inline for (defs) |def| {
        debug.assert(def.len == 1);
        debug.assert(comptime mem.eql(u8, def[0].name, "a"));
    }
}

pub fn definitionInfo(comptime T: type, comptime def_name: []const u8) TypeInfo.Definition {
    inline for (comptime definitions(T)) |def| {
        if (comptime mem.eql(u8, def.name, def_name))
            return def;
    }

    @compileError("'" ++ @typeName(T) ++ "' has no definition '" ++ def_name ++ "'");
}

test "std.meta.definitionInfo" {
    const E1 = enum.{
        A,

        fn a() void {}
    };
    const S1 = struct.{
        fn a() void {}
    };
    const U1 = union.{
        a: u8,

        fn a() void {}
    };

    const infos = comptime []TypeInfo.Definition.{
        definitionInfo(E1, "a"),
        definitionInfo(S1, "a"),
        definitionInfo(U1, "a"),
    };

    inline for (infos) |info| {
        debug.assert(comptime mem.eql(u8, info.name, "a"));
        debug.assert(!info.is_pub);
    }
}

pub fn fields(comptime T: type) switch (@typeInfo(T)) {
    TypeId.Struct => []TypeInfo.StructField,
    TypeId.Union => []TypeInfo.UnionField,
    TypeId.ErrorSet => []TypeInfo.Error,
    TypeId.Enum => []TypeInfo.EnumField,
    else => @compileError("Expected struct, union, error set or enum type, found '" ++ @typeName(T) ++ "'"),
} {
    return switch (@typeInfo(T)) {
        TypeId.Struct => |info| info.fields,
        TypeId.Union => |info| info.fields,
        TypeId.Enum => |info| info.fields,
        TypeId.ErrorSet => |info| info.errors,
        else => @compileError("Expected struct, union, error set or enum type, found '" ++ @typeName(T) ++ "'"),
    };
}

test "std.meta.fields" {
    const E1 = enum.{
        A,
    };
    const E2 = error.{A};
    const S1 = struct.{
        a: u8,
    };
    const U1 = union.{
        a: u8,
    };

    const e1f = comptime fields(E1);
    const e2f = comptime fields(E2);
    const sf = comptime fields(S1);
    const uf = comptime fields(U1);

    debug.assert(e1f.len == 1);
    debug.assert(e2f.len == 1);
    debug.assert(sf.len == 1);
    debug.assert(uf.len == 1);
    debug.assert(mem.eql(u8, e1f[0].name, "A"));
    debug.assert(mem.eql(u8, e2f[0].name, "A"));
    debug.assert(mem.eql(u8, sf[0].name, "a"));
    debug.assert(mem.eql(u8, uf[0].name, "a"));
    debug.assert(comptime sf[0].field_type == u8);
    debug.assert(comptime uf[0].field_type == u8);
}

pub fn fieldInfo(comptime T: type, comptime field_name: []const u8) switch (@typeInfo(T)) {
    TypeId.Struct => TypeInfo.StructField,
    TypeId.Union => TypeInfo.UnionField,
    TypeId.ErrorSet => TypeInfo.Error,
    TypeId.Enum => TypeInfo.EnumField,
    else => @compileError("Expected struct, union, error set or enum type, found '" ++ @typeName(T) ++ "'"),
} {
    inline for (comptime fields(T)) |field| {
        if (comptime mem.eql(u8, field.name, field_name))
            return field;
    }

    @compileError("'" ++ @typeName(T) ++ "' has no field '" ++ field_name ++ "'");
}

test "std.meta.fieldInfo" {
    const E1 = enum.{
        A,
    };
    const E2 = error.{A};
    const S1 = struct.{
        a: u8,
    };
    const U1 = union.{
        a: u8,
    };

    const e1f = comptime fieldInfo(E1, "A");
    const e2f = comptime fieldInfo(E2, "A");
    const sf = comptime fieldInfo(S1, "a");
    const uf = comptime fieldInfo(U1, "a");

    debug.assert(mem.eql(u8, e1f.name, "A"));
    debug.assert(mem.eql(u8, e2f.name, "A"));
    debug.assert(mem.eql(u8, sf.name, "a"));
    debug.assert(mem.eql(u8, uf.name, "a"));
    debug.assert(comptime sf.field_type == u8);
    debug.assert(comptime uf.field_type == u8);
}

pub fn TagType(comptime T: type) type {
    return switch (@typeInfo(T)) {
        TypeId.Enum => |info| info.tag_type,
        TypeId.Union => |info| if (info.tag_type) |Tag| Tag else null,
        else => @compileError("expected enum or union type, found '" ++ @typeName(T) ++ "'"),
    };
}

test "std.meta.TagType" {
    const E = enum(u8).{
        C = 33,
        D,
    };
    const U = union(E).{
        C: u8,
        D: u16,
    };

    debug.assert(TagType(E) == u8);
    debug.assert(TagType(U) == E);
}

///Returns the active tag of a tagged union
pub fn activeTag(u: var) @TagType(@typeOf(u)) {
    const T = @typeOf(u);
    return @TagType(T)(u);
}

test "std.meta.activeTag" {
    const UE = enum.{
        Int,
        Float,
    };

    const U = union(UE).{
        Int: u32,
        Float: f32,
    };

    var u = U.{ .Int = 32 };
    debug.assert(activeTag(u) == UE.Int);

    u = U.{ .Float = 112.9876 };
    debug.assert(activeTag(u) == UE.Float);
}

///Compares two of any type for equality. Containers are compared on a field-by-field basis,
/// where possible. Pointers are not followed.
pub fn eql(a: var, b: @typeOf(a)) bool {
    const T = @typeOf(a);

    switch (@typeId(T)) {
        builtin.TypeId.Struct => {
            const info = @typeInfo(T).Struct;

            inline for (info.fields) |field_info| {
                if (!eql(@field(a, field_info.name), @field(b, field_info.name))) return false;
            }
            return true;
        },
        builtin.TypeId.ErrorUnion => {
            if (a) |a_p| {
                if (b) |b_p| return eql(a_p, b_p) else |_| return false;
            } else |a_e| {
                if (b) |_| return false else |b_e| return a_e == b_e;
            }
        },
        builtin.TypeId.Union => {
            const info = @typeInfo(T).Union;

            if (info.tag_type) |_| {
                const tag_a = activeTag(a);
                const tag_b = activeTag(b);
                if (tag_a != tag_b) return false;

                inline for (info.fields) |field_info| {
                    const enum_field = field_info.enum_field.?;
                    if (enum_field.value == @enumToInt(tag_a)) {
                        return eql(@field(a, enum_field.name), @field(b, enum_field.name));
                    }
                }
                return false;
            }

            @compileError("cannot compare untagged union type " ++ @typeName(T));
        },
        builtin.TypeId.Array => {
            if (a.len != b.len) return false;
            for (a) |e, i|
                if (!eql(e, b[i])) return false;
            return true;
        },
        builtin.TypeId.Pointer => {
            const info = @typeInfo(T).Pointer;
            switch (info.size) {
                builtin.TypeInfo.Pointer.Size.One, builtin.TypeInfo.Pointer.Size.Many => return a == b,
                builtin.TypeInfo.Pointer.Size.Slice => return a.ptr == b.ptr and a.len == b.len,
            }
        },
        else => return a == b,
    }
}

test "std.meta.eql" {
    const S = struct.{
        a: u32,
        b: f64,
        c: [5]u8,
    };

    const U = union(enum).{
        s: S,
        f: f32,
    };

    const s_1 = S.{
        .a = 134,
        .b = 123.3,
        .c = "12345",
    };

    const s_2 = S.{
        .a = 1,
        .b = 123.3,
        .c = "54321",
    };

    const s_3 = S.{
        .a = 134,
        .b = 123.3,
        .c = "12345",
    };

    const u_1 = U.{ .f = 24 };
    const u_2 = U.{ .s = s_1 };
    const u_3 = U.{ .f = 24 };

    debug.assert(eql(s_1, s_3));
    debug.assert(eql(&s_1, &s_1));
    debug.assert(!eql(&s_1, &s_3));
    debug.assert(eql(u_1, u_3));
    debug.assert(!eql(u_1, u_2));

    var a1 = "abcdef";
    var a2 = "abcdef";
    var a3 = "ghijkl";

    debug.assert(eql(a1, a2));
    debug.assert(!eql(a1, a3));
    debug.assert(!eql(a1[0..], a2[0..]));

    const EU = struct.{
        fn tst(err: bool) !u8 {
            if (err) return error.Error;
            return u8(5);
        }
    };

    debug.assert(eql(EU.tst(true), EU.tst(true)));
    debug.assert(eql(EU.tst(false), EU.tst(false)));
    debug.assert(!eql(EU.tst(false), EU.tst(true)));
}
