// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std.zig");
const builtin = @import("builtin");
const debug = std.debug;
const mem = std.mem;
const math = std.math;
const testing = std.testing;
const root = @import("root");

pub const trait = @import("meta/trait.zig");
pub const TrailerFlags = @import("meta/trailer_flags.zig").TrailerFlags;

const TypeInfo = builtin.TypeInfo;

pub fn tagName(v: anytype) []const u8 {
    const T = @TypeOf(v);
    switch (@typeInfo(T)) {
        .ErrorSet => return @errorName(v),
        else => return @tagName(v),
    }
}

test "std.meta.tagName" {
    const E1 = enum {
        A,
        B,
    };
    const E2 = enum(u8) {
        C = 33,
        D,
    };
    const U1 = union(enum) {
        G: u8,
        H: u16,
    };
    const U2 = union(E2) {
        C: u8,
        D: u16,
    };

    var u1g = U1{ .G = 0 };
    var u1h = U1{ .H = 0 };
    var u2a = U2{ .C = 0 };
    var u2b = U2{ .D = 0 };

    testing.expect(mem.eql(u8, tagName(E1.A), "A"));
    testing.expect(mem.eql(u8, tagName(E1.B), "B"));
    testing.expect(mem.eql(u8, tagName(E2.C), "C"));
    testing.expect(mem.eql(u8, tagName(E2.D), "D"));
    testing.expect(mem.eql(u8, tagName(error.E), "E"));
    testing.expect(mem.eql(u8, tagName(error.F), "F"));
    testing.expect(mem.eql(u8, tagName(u1g), "G"));
    testing.expect(mem.eql(u8, tagName(u1h), "H"));
    testing.expect(mem.eql(u8, tagName(u2a), "C"));
    testing.expect(mem.eql(u8, tagName(u2b), "D"));
}

pub fn stringToEnum(comptime T: type, str: []const u8) ?T {
    // Using ComptimeStringMap here is more performant, but it will start to take too
    // long to compile if the enum is large enough, due to the current limits of comptime
    // performance when doing things like constructing lookup maps at comptime.
    // TODO The '100' here is arbitrary and should be increased when possible:
    // - https://github.com/ziglang/zig/issues/4055
    // - https://github.com/ziglang/zig/issues/3863
    if (@typeInfo(T).Enum.fields.len <= 100) {
        const kvs = comptime build_kvs: {
            // In order to generate an array of structs that play nice with anonymous
            // list literals, we need to give them "0" and "1" field names.
            // TODO https://github.com/ziglang/zig/issues/4335
            const EnumKV = struct {
                @"0": []const u8,
                @"1": T,
            };
            var kvs_array: [@typeInfo(T).Enum.fields.len]EnumKV = undefined;
            inline for (@typeInfo(T).Enum.fields) |enumField, i| {
                kvs_array[i] = .{ .@"0" = enumField.name, .@"1" = @field(T, enumField.name) };
            }
            break :build_kvs kvs_array[0..];
        };
        const map = std.ComptimeStringMap(T, kvs);
        return map.get(str);
    } else {
        inline for (@typeInfo(T).Enum.fields) |enumField| {
            if (mem.eql(u8, str, enumField.name)) {
                return @field(T, enumField.name);
            }
        }
        return null;
    }
}

test "std.meta.stringToEnum" {
    const E1 = enum {
        A,
        B,
    };
    testing.expect(E1.A == stringToEnum(E1, "A").?);
    testing.expect(E1.B == stringToEnum(E1, "B").?);
    testing.expect(null == stringToEnum(E1, "C"));
}

pub fn bitCount(comptime T: type) comptime_int {
    return switch (@typeInfo(T)) {
        .Bool => 1,
        .Int => |info| info.bits,
        .Float => |info| info.bits,
        else => @compileError("Expected bool, int or float type, found '" ++ @typeName(T) ++ "'"),
    };
}

test "std.meta.bitCount" {
    testing.expect(bitCount(u8) == 8);
    testing.expect(bitCount(f32) == 32);
}

pub fn alignment(comptime T: type) comptime_int {
    //@alignOf works on non-pointer types
    const P = if (comptime trait.is(.Pointer)(T)) T else *T;
    return @typeInfo(P).Pointer.alignment;
}

test "std.meta.alignment" {
    testing.expect(alignment(u8) == 1);
    testing.expect(alignment(*align(1) u8) == 1);
    testing.expect(alignment(*align(2) u8) == 2);
    testing.expect(alignment([]align(1) u8) == 1);
    testing.expect(alignment([]align(2) u8) == 2);
}

pub fn Child(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .Array => |info| info.child,
        .Vector => |info| info.child,
        .Pointer => |info| info.child,
        .Optional => |info| info.child,
        else => @compileError("Expected pointer, optional, array or vector type, found '" ++ @typeName(T) ++ "'"),
    };
}

test "std.meta.Child" {
    testing.expect(Child([1]u8) == u8);
    testing.expect(Child(*u8) == u8);
    testing.expect(Child([]u8) == u8);
    testing.expect(Child(?u8) == u8);
    testing.expect(Child(Vector(2, u8)) == u8);
}

/// Given a "memory span" type, returns the "element type".
pub fn Elem(comptime T: type) type {
    switch (@typeInfo(T)) {
        .Array => |info| return info.child,
        .Vector => |info| return info.child,
        .Pointer => |info| switch (info.size) {
            .One => switch (@typeInfo(info.child)) {
                .Array => |array_info| return array_info.child,
                .Vector => |vector_info| return vector_info.child,
                else => {},
            },
            .Many, .C, .Slice => return info.child,
        },
        .Optional => |info| switch (@typeInfo(info.child)) {
            .Pointer => |ptr_info| switch (ptr_info.size) {
                .Many => return ptr_info.child,
                else => {},
            },
            else => {},
        },
        else => {},
    }
    @compileError("Expected pointer, slice, array or vector type, found '" ++ @typeName(T) ++ "'");
}

test "std.meta.Elem" {
    testing.expect(Elem([1]u8) == u8);
    testing.expect(Elem([*]u8) == u8);
    testing.expect(Elem([]u8) == u8);
    testing.expect(Elem(*[10]u8) == u8);
    testing.expect(Elem(Vector(2, u8)) == u8);
    testing.expect(Elem(*Vector(2, u8)) == u8);
    testing.expect(Elem(?[*]u8) == u8);
}

/// Given a type which can have a sentinel e.g. `[:0]u8`, returns the sentinel value,
/// or `null` if there is not one.
/// Types which cannot possibly have a sentinel will be a compile error.
pub fn sentinel(comptime T: type) ?Elem(T) {
    switch (@typeInfo(T)) {
        .Array => |info| return info.sentinel,
        .Pointer => |info| {
            switch (info.size) {
                .Many, .Slice => return info.sentinel,
                .One => switch (@typeInfo(info.child)) {
                    .Array => |array_info| return array_info.sentinel,
                    else => {},
                },
                else => {},
            }
        },
        else => {},
    }
    @compileError("type '" ++ @typeName(T) ++ "' cannot possibly have a sentinel");
}

test "std.meta.sentinel" {
    testSentinel();
    comptime testSentinel();
}

fn testSentinel() void {
    testing.expectEqual(@as(u8, 0), sentinel([:0]u8).?);
    testing.expectEqual(@as(u8, 0), sentinel([*:0]u8).?);
    testing.expectEqual(@as(u8, 0), sentinel([5:0]u8).?);
    testing.expectEqual(@as(u8, 0), sentinel(*const [5:0]u8).?);

    testing.expect(sentinel([]u8) == null);
    testing.expect(sentinel([*]u8) == null);
    testing.expect(sentinel([5]u8) == null);
    testing.expect(sentinel(*const [5]u8) == null);
}

/// Given a "memory span" type, returns the same type except with the given sentinel value.
pub fn Sentinel(comptime T: type, comptime sentinel_val: Elem(T)) type {
    switch (@typeInfo(T)) {
        .Pointer => |info| switch (info.size) {
            .One => switch (@typeInfo(info.child)) {
                .Array => |array_info| return @Type(.{
                    .Pointer = .{
                        .size = info.size,
                        .is_const = info.is_const,
                        .is_volatile = info.is_volatile,
                        .alignment = info.alignment,
                        .child = @Type(.{
                            .Array = .{
                                .len = array_info.len,
                                .child = array_info.child,
                                .sentinel = sentinel_val,
                            },
                        }),
                        .is_allowzero = info.is_allowzero,
                        .sentinel = info.sentinel,
                    },
                }),
                else => {},
            },
            .Many, .Slice => return @Type(.{
                .Pointer = .{
                    .size = info.size,
                    .is_const = info.is_const,
                    .is_volatile = info.is_volatile,
                    .alignment = info.alignment,
                    .child = info.child,
                    .is_allowzero = info.is_allowzero,
                    .sentinel = sentinel_val,
                },
            }),
            else => {},
        },
        .Optional => |info| switch (@typeInfo(info.child)) {
            .Pointer => |ptr_info| switch (ptr_info.size) {
                .Many => return @Type(.{
                    .Optional = .{
                        .child = @Type(.{
                            .Pointer = .{
                                .size = ptr_info.size,
                                .is_const = ptr_info.is_const,
                                .is_volatile = ptr_info.is_volatile,
                                .alignment = ptr_info.alignment,
                                .child = ptr_info.child,
                                .is_allowzero = ptr_info.is_allowzero,
                                .sentinel = sentinel_val,
                            },
                        }),
                    },
                }),
                else => {},
            },
            else => {},
        },
        else => {},
    }
    @compileError("Unable to derive a sentinel pointer type from " ++ @typeName(T));
}

/// Takes a Slice or Many Pointer and returns it with the Type modified to have the given sentinel value.
/// This function assumes the caller has verified the memory contains the sentinel value.
pub fn assumeSentinel(p: anytype, comptime sentinel_val: Elem(@TypeOf(p))) Sentinel(@TypeOf(p), sentinel_val) {
    const T = @TypeOf(p);
    const ReturnType = Sentinel(T, sentinel_val);
    switch (@typeInfo(T)) {
        .Pointer => |info| switch (info.size) {
            .Slice => return @bitCast(ReturnType, p),
            .Many, .One => return @ptrCast(ReturnType, p),
            .C => {},
        },
        .Optional => |info| switch (@typeInfo(info.child)) {
            .Pointer => |ptr_info| switch (ptr_info.size) {
                .Many => return @ptrCast(ReturnType, p),
                else => {},
            },
            else => {},
        },
        else => {},
    }
    @compileError("Unable to derive a sentinel pointer type from " ++ @typeName(T));
}

test "std.meta.assumeSentinel" {
    testing.expect([*:0]u8 == @TypeOf(assumeSentinel(@as([*]u8, undefined), 0)));
    testing.expect([:0]u8 == @TypeOf(assumeSentinel(@as([]u8, undefined), 0)));
    testing.expect([*:0]const u8 == @TypeOf(assumeSentinel(@as([*]const u8, undefined), 0)));
    testing.expect([:0]const u8 == @TypeOf(assumeSentinel(@as([]const u8, undefined), 0)));
    testing.expect([*:0]u16 == @TypeOf(assumeSentinel(@as([*]u16, undefined), 0)));
    testing.expect([:0]const u16 == @TypeOf(assumeSentinel(@as([]const u16, undefined), 0)));
    testing.expect([*:3]u8 == @TypeOf(assumeSentinel(@as([*:1]u8, undefined), 3)));
    testing.expect([:null]?[*]u8 == @TypeOf(assumeSentinel(@as([]?[*]u8, undefined), null)));
    testing.expect([*:null]?[*]u8 == @TypeOf(assumeSentinel(@as([*]?[*]u8, undefined), null)));
    testing.expect(*[10:0]u8 == @TypeOf(assumeSentinel(@as(*[10]u8, undefined), 0)));
    testing.expect(?[*:0]u8 == @TypeOf(assumeSentinel(@as(?[*]u8, undefined), 0)));
}

pub fn containerLayout(comptime T: type) TypeInfo.ContainerLayout {
    return switch (@typeInfo(T)) {
        .Struct => |info| info.layout,
        .Enum => |info| info.layout,
        .Union => |info| info.layout,
        else => @compileError("Expected struct, enum or union type, found '" ++ @typeName(T) ++ "'"),
    };
}

test "std.meta.containerLayout" {
    const E1 = enum {
        A,
    };
    const E2 = packed enum {
        A,
    };
    const E3 = extern enum {
        A,
    };
    const S1 = struct {};
    const S2 = packed struct {};
    const S3 = extern struct {};
    const U1 = union {
        a: u8,
    };
    const U2 = packed union {
        a: u8,
    };
    const U3 = extern union {
        a: u8,
    };

    testing.expect(containerLayout(E1) == .Auto);
    testing.expect(containerLayout(E2) == .Packed);
    testing.expect(containerLayout(E3) == .Extern);
    testing.expect(containerLayout(S1) == .Auto);
    testing.expect(containerLayout(S2) == .Packed);
    testing.expect(containerLayout(S3) == .Extern);
    testing.expect(containerLayout(U1) == .Auto);
    testing.expect(containerLayout(U2) == .Packed);
    testing.expect(containerLayout(U3) == .Extern);
}

pub fn declarations(comptime T: type) []const TypeInfo.Declaration {
    return switch (@typeInfo(T)) {
        .Struct => |info| info.decls,
        .Enum => |info| info.decls,
        .Union => |info| info.decls,
        .Opaque => |info| info.decls,
        else => @compileError("Expected struct, enum, union, or opaque type, found '" ++ @typeName(T) ++ "'"),
    };
}

test "std.meta.declarations" {
    const E1 = enum {
        A,

        fn a() void {}
    };
    const S1 = struct {
        fn a() void {}
    };
    const U1 = union {
        a: u8,

        fn a() void {}
    };
    const O1 = opaque {
        fn a() void {}
    };

    const decls = comptime [_][]const TypeInfo.Declaration{
        declarations(E1),
        declarations(S1),
        declarations(U1),
        declarations(O1),
    };

    inline for (decls) |decl| {
        testing.expect(decl.len == 1);
        testing.expect(comptime mem.eql(u8, decl[0].name, "a"));
    }
}

pub fn declarationInfo(comptime T: type, comptime decl_name: []const u8) TypeInfo.Declaration {
    inline for (comptime declarations(T)) |decl| {
        if (comptime mem.eql(u8, decl.name, decl_name))
            return decl;
    }

    @compileError("'" ++ @typeName(T) ++ "' has no declaration '" ++ decl_name ++ "'");
}

test "std.meta.declarationInfo" {
    const E1 = enum {
        A,

        fn a() void {}
    };
    const S1 = struct {
        fn a() void {}
    };
    const U1 = union {
        a: u8,

        fn a() void {}
    };

    const infos = comptime [_]TypeInfo.Declaration{
        declarationInfo(E1, "a"),
        declarationInfo(S1, "a"),
        declarationInfo(U1, "a"),
    };

    inline for (infos) |info| {
        testing.expect(comptime mem.eql(u8, info.name, "a"));
        testing.expect(!info.is_pub);
    }
}

pub fn fields(comptime T: type) switch (@typeInfo(T)) {
    .Struct => []const TypeInfo.StructField,
    .Union => []const TypeInfo.UnionField,
    .ErrorSet => []const TypeInfo.Error,
    .Enum => []const TypeInfo.EnumField,
    else => @compileError("Expected struct, union, error set or enum type, found '" ++ @typeName(T) ++ "'"),
} {
    return switch (@typeInfo(T)) {
        .Struct => |info| info.fields,
        .Union => |info| info.fields,
        .Enum => |info| info.fields,
        .ErrorSet => |errors| errors.?, // must be non global error set
        else => @compileError("Expected struct, union, error set or enum type, found '" ++ @typeName(T) ++ "'"),
    };
}

test "std.meta.fields" {
    const E1 = enum {
        A,
    };
    const E2 = error{A};
    const S1 = struct {
        a: u8,
    };
    const U1 = union {
        a: u8,
    };

    const e1f = comptime fields(E1);
    const e2f = comptime fields(E2);
    const sf = comptime fields(S1);
    const uf = comptime fields(U1);

    testing.expect(e1f.len == 1);
    testing.expect(e2f.len == 1);
    testing.expect(sf.len == 1);
    testing.expect(uf.len == 1);
    testing.expect(mem.eql(u8, e1f[0].name, "A"));
    testing.expect(mem.eql(u8, e2f[0].name, "A"));
    testing.expect(mem.eql(u8, sf[0].name, "a"));
    testing.expect(mem.eql(u8, uf[0].name, "a"));
    testing.expect(comptime sf[0].field_type == u8);
    testing.expect(comptime uf[0].field_type == u8);
}

pub fn fieldInfo(comptime T: type, comptime field: FieldEnum(T)) switch (@typeInfo(T)) {
    .Struct => TypeInfo.StructField,
    .Union => TypeInfo.UnionField,
    .ErrorSet => TypeInfo.Error,
    .Enum => TypeInfo.EnumField,
    else => @compileError("Expected struct, union, error set or enum type, found '" ++ @typeName(T) ++ "'"),
} {
    return fields(T)[@enumToInt(field)];
}

test "std.meta.fieldInfo" {
    const E1 = enum {
        A,
    };
    const E2 = error{A};
    const S1 = struct {
        a: u8,
    };
    const U1 = union {
        a: u8,
    };

    const e1f = fieldInfo(E1, .A);
    const e2f = fieldInfo(E2, .A);
    const sf = fieldInfo(S1, .a);
    const uf = fieldInfo(U1, .a);

    testing.expect(mem.eql(u8, e1f.name, "A"));
    testing.expect(mem.eql(u8, e2f.name, "A"));
    testing.expect(mem.eql(u8, sf.name, "a"));
    testing.expect(mem.eql(u8, uf.name, "a"));
    testing.expect(comptime sf.field_type == u8);
    testing.expect(comptime uf.field_type == u8);
}

pub fn fieldNames(comptime T: type) *const [fields(T).len][]const u8 {
    comptime {
        const fieldInfos = fields(T);
        var names: [fieldInfos.len][]const u8 = undefined;
        for (fieldInfos) |field, i| {
            names[i] = field.name;
        }
        return &names;
    }
}

test "std.meta.fieldNames" {
    const E1 = enum { A, B };
    const E2 = error{A};
    const S1 = struct {
        a: u8,
    };
    const U1 = union {
        a: u8,
        b: void,
    };

    const e1names = fieldNames(E1);
    const e2names = fieldNames(E2);
    const s1names = fieldNames(S1);
    const u1names = fieldNames(U1);

    testing.expect(e1names.len == 2);
    testing.expectEqualSlices(u8, e1names[0], "A");
    testing.expectEqualSlices(u8, e1names[1], "B");
    testing.expect(e2names.len == 1);
    testing.expectEqualSlices(u8, e2names[0], "A");
    testing.expect(s1names.len == 1);
    testing.expectEqualSlices(u8, s1names[0], "a");
    testing.expect(u1names.len == 2);
    testing.expectEqualSlices(u8, u1names[0], "a");
    testing.expectEqualSlices(u8, u1names[1], "b");
}

pub fn FieldEnum(comptime T: type) type {
    const fieldInfos = fields(T);
    var enumFields: [fieldInfos.len]std.builtin.TypeInfo.EnumField = undefined;
    var decls = [_]std.builtin.TypeInfo.Declaration{};
    inline for (fieldInfos) |field, i| {
        enumFields[i] = .{
            .name = field.name,
            .value = i,
        };
    }
    return @Type(.{
        .Enum = .{
            .layout = .Auto,
            .tag_type = std.math.IntFittingRange(0, fieldInfos.len - 1),
            .fields = &enumFields,
            .decls = &decls,
            .is_exhaustive = true,
        },
    });
}

fn expectEqualEnum(expected: anytype, actual: @TypeOf(expected)) void {
    // TODO: https://github.com/ziglang/zig/issues/7419
    // testing.expectEqual(@typeInfo(expected).Enum, @typeInfo(actual).Enum);
    testing.expectEqual(@typeInfo(expected).Enum.layout, @typeInfo(actual).Enum.layout);
    testing.expectEqual(@typeInfo(expected).Enum.tag_type, @typeInfo(actual).Enum.tag_type);
    comptime testing.expectEqualSlices(std.builtin.TypeInfo.EnumField, @typeInfo(expected).Enum.fields, @typeInfo(actual).Enum.fields);
    comptime testing.expectEqualSlices(std.builtin.TypeInfo.Declaration, @typeInfo(expected).Enum.decls, @typeInfo(actual).Enum.decls);
    testing.expectEqual(@typeInfo(expected).Enum.is_exhaustive, @typeInfo(actual).Enum.is_exhaustive);
}

test "std.meta.FieldEnum" {
    expectEqualEnum(enum { a }, FieldEnum(struct { a: u8 }));
    expectEqualEnum(enum { a, b, c }, FieldEnum(struct { a: u8, b: void, c: f32 }));
    expectEqualEnum(enum { a, b, c }, FieldEnum(union { a: u8, b: void, c: f32 }));
}

// Deprecated: use Tag
pub const TagType = Tag;

pub fn Tag(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .Enum => |info| info.tag_type,
        .Union => |info| info.tag_type orelse @compileError(@typeName(T) ++ " has no tag type"),
        else => @compileError("expected enum or union type, found '" ++ @typeName(T) ++ "'"),
    };
}

test "std.meta.Tag" {
    const E = enum(u8) {
        C = 33,
        D,
    };
    const U = union(E) {
        C: u8,
        D: u16,
    };

    testing.expect(Tag(E) == u8);
    testing.expect(Tag(U) == E);
}

///Returns the active tag of a tagged union
pub fn activeTag(u: anytype) Tag(@TypeOf(u)) {
    const T = @TypeOf(u);
    return @as(Tag(T), u);
}

test "std.meta.activeTag" {
    const UE = enum {
        Int,
        Float,
    };

    const U = union(UE) {
        Int: u32,
        Float: f32,
    };

    var u = U{ .Int = 32 };
    testing.expect(activeTag(u) == UE.Int);

    u = U{ .Float = 112.9876 };
    testing.expect(activeTag(u) == UE.Float);
}

const TagPayloadType = TagPayload;

///Given a tagged union type, and an enum, return the type of the union
/// field corresponding to the enum tag.
pub fn TagPayload(comptime U: type, tag: Tag(U)) type {
    testing.expect(trait.is(.Union)(U));

    const info = @typeInfo(U).Union;
    const tag_info = @typeInfo(Tag(U)).Enum;

    inline for (info.fields) |field_info| {
        if (comptime mem.eql(u8, field_info.name, @tagName(tag)))
            return field_info.field_type;
    }

    unreachable;
}

test "std.meta.TagPayload" {
    const Event = union(enum) {
        Moved: struct {
            from: i32,
            to: i32,
        },
    };
    const MovedEvent = TagPayload(Event, Event.Moved);
    var e: Event = undefined;
    testing.expect(MovedEvent == @TypeOf(e.Moved));
}

/// Compares two of any type for equality. Containers are compared on a field-by-field basis,
/// where possible. Pointers are not followed.
pub fn eql(a: anytype, b: @TypeOf(a)) bool {
    const T = @TypeOf(a);

    switch (@typeInfo(T)) {
        .Struct => |info| {
            inline for (info.fields) |field_info| {
                if (!eql(@field(a, field_info.name), @field(b, field_info.name))) return false;
            }
            return true;
        },
        .ErrorUnion => {
            if (a) |a_p| {
                if (b) |b_p| return eql(a_p, b_p) else |_| return false;
            } else |a_e| {
                if (b) |_| return false else |b_e| return a_e == b_e;
            }
        },
        .Union => |info| {
            if (info.tag_type) |UnionTag| {
                const tag_a = activeTag(a);
                const tag_b = activeTag(b);
                if (tag_a != tag_b) return false;

                inline for (info.fields) |field_info| {
                    if (@field(UnionTag, field_info.name) == tag_a) {
                        return eql(@field(a, field_info.name), @field(b, field_info.name));
                    }
                }
                return false;
            }

            @compileError("cannot compare untagged union type " ++ @typeName(T));
        },
        .Array => {
            if (a.len != b.len) return false;
            for (a) |e, i|
                if (!eql(e, b[i])) return false;
            return true;
        },
        .Vector => |info| {
            var i: usize = 0;
            while (i < info.len) : (i += 1) {
                if (!eql(a[i], b[i])) return false;
            }
            return true;
        },
        .Pointer => |info| {
            return switch (info.size) {
                .One, .Many, .C => a == b,
                .Slice => a.ptr == b.ptr and a.len == b.len,
            };
        },
        .Optional => {
            if (a == null and b == null) return true;
            if (a == null or b == null) return false;
            return eql(a.?, b.?);
        },
        else => return a == b,
    }
}

test "std.meta.eql" {
    const S = struct {
        a: u32,
        b: f64,
        c: [5]u8,
    };

    const U = union(enum) {
        s: S,
        f: ?f32,
    };

    const s_1 = S{
        .a = 134,
        .b = 123.3,
        .c = "12345".*,
    };

    const s_2 = S{
        .a = 1,
        .b = 123.3,
        .c = "54321".*,
    };

    var s_3 = S{
        .a = 134,
        .b = 123.3,
        .c = "12345".*,
    };

    const u_1 = U{ .f = 24 };
    const u_2 = U{ .s = s_1 };
    const u_3 = U{ .f = 24 };

    testing.expect(eql(s_1, s_3));
    testing.expect(eql(&s_1, &s_1));
    testing.expect(!eql(&s_1, &s_3));
    testing.expect(eql(u_1, u_3));
    testing.expect(!eql(u_1, u_2));

    var a1 = "abcdef".*;
    var a2 = "abcdef".*;
    var a3 = "ghijkl".*;

    testing.expect(eql(a1, a2));
    testing.expect(!eql(a1, a3));
    testing.expect(!eql(a1[0..], a2[0..]));

    const EU = struct {
        fn tst(err: bool) !u8 {
            if (err) return error.Error;
            return @as(u8, 5);
        }
    };

    testing.expect(eql(EU.tst(true), EU.tst(true)));
    testing.expect(eql(EU.tst(false), EU.tst(false)));
    testing.expect(!eql(EU.tst(false), EU.tst(true)));

    var v1 = @splat(4, @as(u32, 1));
    var v2 = @splat(4, @as(u32, 1));
    var v3 = @splat(4, @as(u32, 2));

    testing.expect(eql(v1, v2));
    testing.expect(!eql(v1, v3));
}

test "intToEnum with error return" {
    const E1 = enum {
        A,
    };
    const E2 = enum {
        A,
        B,
    };

    var zero: u8 = 0;
    var one: u16 = 1;
    testing.expect(intToEnum(E1, zero) catch unreachable == E1.A);
    testing.expect(intToEnum(E2, one) catch unreachable == E2.B);
    testing.expectError(error.InvalidEnumTag, intToEnum(E1, one));
}

pub const IntToEnumError = error{InvalidEnumTag};

pub fn intToEnum(comptime EnumTag: type, tag_int: anytype) IntToEnumError!EnumTag {
    inline for (@typeInfo(EnumTag).Enum.fields) |f| {
        const this_tag_value = @field(EnumTag, f.name);
        if (tag_int == @enumToInt(this_tag_value)) {
            return this_tag_value;
        }
    }
    return error.InvalidEnumTag;
}

/// Given a type and a name, return the field index according to source order.
/// Returns `null` if the field is not found.
pub fn fieldIndex(comptime T: type, comptime name: []const u8) ?comptime_int {
    inline for (fields(T)) |field, i| {
        if (mem.eql(u8, field.name, name))
            return i;
    }
    return null;
}

pub const refAllDecls = @compileError("refAllDecls has been moved from std.meta to std.testing");

/// Returns a slice of pointers to public declarations of a namespace.
pub fn declList(comptime Namespace: type, comptime Decl: type) []const *const Decl {
    const S = struct {
        fn declNameLessThan(context: void, lhs: *const Decl, rhs: *const Decl) bool {
            return mem.lessThan(u8, lhs.name, rhs.name);
        }
    };
    comptime {
        const decls = declarations(Namespace);
        var array: [decls.len]*const Decl = undefined;
        for (decls) |decl, i| {
            array[i] = &@field(Namespace, decl.name);
        }
        std.sort.sort(*const Decl, &array, {}, S.declNameLessThan);
        return &array;
    }
}

pub const IntType = @compileError("replaced by std.meta.Int");

pub fn Int(comptime signedness: builtin.Signedness, comptime bit_count: u16) type {
    return @Type(TypeInfo{
        .Int = .{
            .signedness = signedness,
            .bits = bit_count,
        },
    });
}

pub fn Vector(comptime len: u32, comptime child: type) type {
    return @Type(TypeInfo{
        .Vector = .{
            .len = len,
            .child = child,
        },
    });
}

/// Given a type and value, cast the value to the type as c would.
/// This is for translate-c and is not intended for general use.
pub fn cast(comptime DestType: type, target: anytype) DestType {
    // this function should behave like transCCast in translate-c, except it's for macros and enums
    const SourceType = @TypeOf(target);
    switch (@typeInfo(DestType)) {
        .Pointer => {
            switch (@typeInfo(SourceType)) {
                .Int, .ComptimeInt => {
                    return @intToPtr(DestType, target);
                },
                .Pointer => {
                    return castPtr(DestType, target);
                },
                .Optional => |opt| {
                    if (@typeInfo(opt.child) == .Pointer) {
                        return castPtr(DestType, target);
                    }
                },
                else => {},
            }
        },
        .Optional => |dest_opt| {
            if (@typeInfo(dest_opt.child) == .Pointer) {
                switch (@typeInfo(SourceType)) {
                    .Int, .ComptimeInt => {
                        return @intToPtr(DestType, target);
                    },
                    .Pointer => {
                        return castPtr(DestType, target);
                    },
                    .Optional => |target_opt| {
                        if (@typeInfo(target_opt.child) == .Pointer) {
                            return castPtr(DestType, target);
                        }
                    },
                    else => {},
                }
            }
        },
        .Enum => |enum_type| {
            if (@typeInfo(SourceType) == .Int or @typeInfo(SourceType) == .ComptimeInt) {
                const intermediate = cast(enum_type.tag_type, target);
                return @intToEnum(DestType, intermediate);
            }
        },
        .Int => {
            switch (@typeInfo(SourceType)) {
                .Pointer => {
                    return castInt(DestType, @ptrToInt(target));
                },
                .Optional => |opt| {
                    if (@typeInfo(opt.child) == .Pointer) {
                        return castInt(DestType, @ptrToInt(target));
                    }
                },
                .Enum => {
                    return castInt(DestType, @enumToInt(target));
                },
                .Int => {
                    return castInt(DestType, target);
                },
                else => {},
            }
        },
        else => {},
    }
    return @as(DestType, target);
}

fn castInt(comptime DestType: type, target: anytype) DestType {
    const dest = @typeInfo(DestType).Int;
    const source = @typeInfo(@TypeOf(target)).Int;

    if (dest.bits < source.bits)
        return @bitCast(DestType, @truncate(Int(source.signedness, dest.bits), target))
    else
        return @bitCast(DestType, @as(Int(source.signedness, dest.bits), target));
}

fn castPtr(comptime DestType: type, target: anytype) DestType {
    const dest = ptrInfo(DestType);
    const source = ptrInfo(@TypeOf(target));

    if (source.is_const and !dest.is_const or source.is_volatile and !dest.is_volatile)
        return @intToPtr(DestType, @ptrToInt(target))
    else if (@typeInfo(dest.child) == .Opaque)
        // dest.alignment would error out
        return @ptrCast(DestType, target)
    else
        return @ptrCast(DestType, @alignCast(dest.alignment, target));
}

fn ptrInfo(comptime PtrType: type) TypeInfo.Pointer {
    return switch (@typeInfo(PtrType)) {
        .Optional => |opt_info| @typeInfo(opt_info.child).Pointer,
        .Pointer => |ptr_info| ptr_info,
        else => unreachable,
    };
}

test "std.meta.cast" {
    const E = enum(u2) {
        Zero,
        One,
        Two,
    };

    var i = @as(i64, 10);

    testing.expect(cast(*u8, 16) == @intToPtr(*u8, 16));
    testing.expect(cast(*u64, &i).* == @as(u64, 10));
    testing.expect(cast(*i64, @as(?*align(1) i64, &i)) == &i);

    testing.expect(cast(?*u8, 2) == @intToPtr(*u8, 2));
    testing.expect(cast(?*i64, @as(*align(1) i64, &i)) == &i);
    testing.expect(cast(?*i64, @as(?*align(1) i64, &i)) == &i);

    testing.expect(cast(E, 1) == .One);

    testing.expectEqual(@as(u32, 4), cast(u32, @intToPtr(*u32, 4)));
    testing.expectEqual(@as(u32, 4), cast(u32, @intToPtr(?*u32, 4)));
    testing.expectEqual(@as(u32, 10), cast(u32, @as(u64, 10)));
    testing.expectEqual(@as(u8, 2), cast(u8, E.Two));

    testing.expectEqual(@bitCast(i32, @as(u32, 0x8000_0000)), cast(i32, @as(u32, 0x8000_0000)));

    testing.expectEqual(@intToPtr(*u8, 2), cast(*u8, @intToPtr(*const u8, 2)));
    testing.expectEqual(@intToPtr(*u8, 2), cast(*u8, @intToPtr(*volatile u8, 2)));

    testing.expectEqual(@intToPtr(?*c_void, 2), cast(?*c_void, @intToPtr(*u8, 2)));

    const C_ENUM = extern enum(c_int) {
        A = 0,
        B,
        C,
        _,
    };
    testing.expectEqual(cast(C_ENUM, @as(i64, -1)), @intToEnum(C_ENUM, -1));
    testing.expectEqual(cast(C_ENUM, @as(i8, 1)), .B);
    testing.expectEqual(cast(C_ENUM, @as(u64, 1)), .B);
    testing.expectEqual(cast(C_ENUM, @as(u64, 42)), @intToEnum(C_ENUM, 42));
}

/// Given a value returns its size as C's sizeof operator would.
/// This is for translate-c and is not intended for general use.
pub fn sizeof(target: anytype) usize {
    const T: type = if (@TypeOf(target) == type) target else @TypeOf(target);
    switch (@typeInfo(T)) {
        .Float, .Int, .Struct, .Union, .Enum, .Array, .Bool, .Vector => return @sizeOf(T),
        .Fn => {
            // sizeof(main) returns 1, sizeof(&main) returns pointer size.
            // We cannot distinguish those types in Zig, so use pointer size.
            return @sizeOf(T);
        },
        .Null => return @sizeOf(*c_void),
        .Void => {
            // Note: sizeof(void) is 1 on clang/gcc and 0 on MSVC.
            return 1;
        },
        .Opaque => {
            if (T == c_void) {
                // Note: sizeof(void) is 1 on clang/gcc and 0 on MSVC.
                return 1;
            } else {
                @compileError("Cannot use C sizeof on opaque type " ++ @typeName(T));
            }
        },
        .Optional => |opt| {
            if (@typeInfo(opt.child) == .Pointer) {
                return sizeof(opt.child);
            } else {
                @compileError("Cannot use C sizeof on non-pointer optional " ++ @typeName(T));
            }
        },
        .Pointer => |ptr| {
            if (ptr.size == .Slice) {
                @compileError("Cannot use C sizeof on slice type " ++ @typeName(T));
            }
            // for strings, sizeof("a") returns 2.
            // normal pointer decay scenarios from C are handled
            // in the .Array case above, but strings remain literals
            // and are therefore always pointers, so they need to be
            // specially handled here.
            if (ptr.size == .One and ptr.is_const and @typeInfo(ptr.child) == .Array) {
                const array_info = @typeInfo(ptr.child).Array;
                if ((array_info.child == u8 or array_info.child == u16) and
                    array_info.sentinel != null and
                    array_info.sentinel.? == 0)
                {
                    // length of the string plus one for the null terminator.
                    return (array_info.len + 1) * @sizeOf(array_info.child);
                }
            }
            // When zero sized pointers are removed, this case will no
            // longer be reachable and can be deleted.
            if (@sizeOf(T) == 0) {
                return @sizeOf(*c_void);
            }
            return @sizeOf(T);
        },
        .ComptimeFloat => return @sizeOf(f64), // TODO c_double #3999
        .ComptimeInt => {
            // TODO to get the correct result we have to translate
            // `1073741824 * 4` as `int(1073741824) *% int(4)` since
            // sizeof(1073741824 * 4) != sizeof(4294967296).

            // TODO test if target fits in int, long or long long
            return @sizeOf(c_int);
        },
        else => @compileError("std.meta.sizeof does not support type " ++ @typeName(T)),
    }
}

test "sizeof" {
    const E = extern enum(c_int) { One, _ };
    const S = extern struct { a: u32 };

    const ptr_size = @sizeOf(*c_void);

    testing.expect(sizeof(u32) == 4);
    testing.expect(sizeof(@as(u32, 2)) == 4);
    testing.expect(sizeof(2) == @sizeOf(c_int));

    testing.expect(sizeof(2.0) == @sizeOf(f64));

    testing.expect(sizeof(E) == @sizeOf(c_int));
    testing.expect(sizeof(E.One) == @sizeOf(c_int));

    testing.expect(sizeof(S) == 4);

    testing.expect(sizeof([_]u32{ 4, 5, 6 }) == 12);
    testing.expect(sizeof([3]u32) == 12);
    testing.expect(sizeof([3:0]u32) == 16);
    testing.expect(sizeof(&[_]u32{ 4, 5, 6 }) == ptr_size);

    testing.expect(sizeof(*u32) == ptr_size);
    testing.expect(sizeof([*]u32) == ptr_size);
    testing.expect(sizeof([*c]u32) == ptr_size);
    testing.expect(sizeof(?*u32) == ptr_size);
    testing.expect(sizeof(?[*]u32) == ptr_size);
    testing.expect(sizeof(*c_void) == ptr_size);
    testing.expect(sizeof(*void) == ptr_size);
    testing.expect(sizeof(null) == ptr_size);

    testing.expect(sizeof("foobar") == 7);
    testing.expect(sizeof(&[_:0]u16{ 'f', 'o', 'o', 'b', 'a', 'r' }) == 14);
    testing.expect(sizeof(*const [4:0]u8) == 5);
    testing.expect(sizeof(*[4:0]u8) == ptr_size);
    testing.expect(sizeof([*]const [4:0]u8) == ptr_size);
    testing.expect(sizeof(*const *const [4:0]u8) == ptr_size);
    testing.expect(sizeof(*const [4]u8) == ptr_size);

    testing.expect(sizeof(sizeof) == @sizeOf(@TypeOf(sizeof)));

    testing.expect(sizeof(void) == 1);
    testing.expect(sizeof(c_void) == 1);
}

pub const CIntLiteralRadix = enum { decimal, octal, hexadecimal };

fn PromoteIntLiteralReturnType(comptime SuffixType: type, comptime number: comptime_int, comptime radix: CIntLiteralRadix) type {
    const signed_decimal = [_]type{ c_int, c_long, c_longlong };
    const signed_oct_hex = [_]type{ c_int, c_uint, c_long, c_ulong, c_longlong, c_ulonglong };
    const unsigned = [_]type{ c_uint, c_ulong, c_ulonglong };

    const list: []const type = if (@typeInfo(SuffixType).Int.signedness == .unsigned)
        &unsigned
    else if (radix == .decimal)
        &signed_decimal
    else
        &signed_oct_hex;

    var pos = mem.indexOfScalar(type, list, SuffixType).?;

    while (pos < list.len) : (pos += 1) {
        if (number >= math.minInt(list[pos]) and number <= math.maxInt(list[pos])) {
            return list[pos];
        }
    }
    @compileError("Integer literal is too large");
}

/// Promote the type of an integer literal until it fits as C would.
/// This is for translate-c and is not intended for general use.
pub fn promoteIntLiteral(
    comptime SuffixType: type,
    comptime number: comptime_int,
    comptime radix: CIntLiteralRadix,
) PromoteIntLiteralReturnType(SuffixType, number, radix) {
    return number;
}

test "promoteIntLiteral" {
    const signed_hex = promoteIntLiteral(c_int, math.maxInt(c_int) + 1, .hexadecimal);
    testing.expectEqual(c_uint, @TypeOf(signed_hex));

    if (math.maxInt(c_longlong) == math.maxInt(c_int)) return;

    const signed_decimal = promoteIntLiteral(c_int, math.maxInt(c_int) + 1, .decimal);
    const unsigned = promoteIntLiteral(c_uint, math.maxInt(c_uint) + 1, .hexadecimal);

    if (math.maxInt(c_long) > math.maxInt(c_int)) {
        testing.expectEqual(c_long, @TypeOf(signed_decimal));
        testing.expectEqual(c_ulong, @TypeOf(unsigned));
    } else {
        testing.expectEqual(c_longlong, @TypeOf(signed_decimal));
        testing.expectEqual(c_ulonglong, @TypeOf(unsigned));
    }
}

/// For a given function type, returns a tuple type which fields will
/// correspond to the argument types.
///
/// Examples:
/// - `ArgsTuple(fn() void)` ⇒ `tuple { }`
/// - `ArgsTuple(fn(a: u32) u32)` ⇒ `tuple { u32 }`
/// - `ArgsTuple(fn(a: u32, b: f16) noreturn)` ⇒ `tuple { u32, f16 }`
pub fn ArgsTuple(comptime Function: type) type {
    const info = @typeInfo(Function);
    if (info != .Fn)
        @compileError("ArgsTuple expects a function type");

    const function_info = info.Fn;
    if (function_info.is_generic)
        @compileError("Cannot create ArgsTuple for generic function");
    if (function_info.is_var_args)
        @compileError("Cannot create ArgsTuple for variadic function");

    var argument_field_list: [function_info.args.len]std.builtin.TypeInfo.StructField = undefined;
    inline for (function_info.args) |arg, i| {
        const T = arg.arg_type.?;
        @setEvalBranchQuota(10_000);
        var num_buf: [128]u8 = undefined;
        argument_field_list[i] = std.builtin.TypeInfo.StructField{
            .name = std.fmt.bufPrint(&num_buf, "{d}", .{i}) catch unreachable,
            .field_type = T,
            .default_value = @as(?T, null),
            .is_comptime = false,
            .alignment = if (@sizeOf(T) > 0) @alignOf(T) else 0,
        };
    }

    return @Type(std.builtin.TypeInfo{
        .Struct = std.builtin.TypeInfo.Struct{
            .is_tuple = true,
            .layout = .Auto,
            .decls = &[_]std.builtin.TypeInfo.Declaration{},
            .fields = &argument_field_list,
        },
    });
}

/// For a given anonymous list of types, returns a new tuple type
/// with those types as fields.
///
/// Examples:
/// - `Tuple(&[_]type {})` ⇒ `tuple { }`
/// - `Tuple(&[_]type {f32})` ⇒ `tuple { f32 }`
/// - `Tuple(&[_]type {f32,u32})` ⇒ `tuple { f32, u32 }`
pub fn Tuple(comptime types: []const type) type {
    var tuple_fields: [types.len]std.builtin.TypeInfo.StructField = undefined;
    inline for (types) |T, i| {
        @setEvalBranchQuota(10_000);
        var num_buf: [128]u8 = undefined;
        tuple_fields[i] = std.builtin.TypeInfo.StructField{
            .name = std.fmt.bufPrint(&num_buf, "{d}", .{i}) catch unreachable,
            .field_type = T,
            .default_value = @as(?T, null),
            .is_comptime = false,
            .alignment = if (@sizeOf(T) > 0) @alignOf(T) else 0,
        };
    }

    return @Type(std.builtin.TypeInfo{
        .Struct = std.builtin.TypeInfo.Struct{
            .is_tuple = true,
            .layout = .Auto,
            .decls = &[_]std.builtin.TypeInfo.Declaration{},
            .fields = &tuple_fields,
        },
    });
}

const TupleTester = struct {
    fn assertTypeEqual(comptime Expected: type, comptime Actual: type) void {
        if (Expected != Actual)
            @compileError("Expected type " ++ @typeName(Expected) ++ ", but got type " ++ @typeName(Actual));
    }

    fn assertTuple(comptime expected: anytype, comptime Actual: type) void {
        const info = @typeInfo(Actual);
        if (info != .Struct)
            @compileError("Expected struct type");
        if (!info.Struct.is_tuple)
            @compileError("Struct type must be a tuple type");

        const fields_list = std.meta.fields(Actual);
        if (expected.len != fields_list.len)
            @compileError("Argument count mismatch");

        inline for (fields_list) |fld, i| {
            if (expected[i] != fld.field_type) {
                @compileError("Field " ++ fld.name ++ " expected to be type " ++ @typeName(expected[i]) ++ ", but was type " ++ @typeName(fld.field_type));
            }
        }
    }
};

test "ArgsTuple" {
    TupleTester.assertTuple(.{}, ArgsTuple(fn () void));
    TupleTester.assertTuple(.{u32}, ArgsTuple(fn (a: u32) []const u8));
    TupleTester.assertTuple(.{ u32, f16 }, ArgsTuple(fn (a: u32, b: f16) noreturn));
    TupleTester.assertTuple(.{ u32, f16, []const u8, void }, ArgsTuple(fn (a: u32, b: f16, c: []const u8, void) noreturn));
}

test "Tuple" {
    TupleTester.assertTuple(.{}, Tuple(&[_]type{}));
    TupleTester.assertTuple(.{u32}, Tuple(&[_]type{u32}));
    TupleTester.assertTuple(.{ u32, f16 }, Tuple(&[_]type{ u32, f16 }));
    TupleTester.assertTuple(.{ u32, f16, []const u8, void }, Tuple(&[_]type{ u32, f16, []const u8, void }));
}

/// TODO: https://github.com/ziglang/zig/issues/425
pub fn globalOption(comptime name: []const u8, comptime T: type) ?T {
    if (!@hasDecl(root, name))
        return null;
    return @as(T, @field(root, name));
}

/// This function is for translate-c and is not intended for general use.
/// Convert from clang __builtin_shufflevector index to Zig @shuffle index
/// clang requires __builtin_shufflevector index arguments to be integer constants.
/// negative values for `this_index` indicate "don't care" so we arbitrarily choose 0
/// clang enforces that `this_index` is less than the total number of vector elements
/// See https://ziglang.org/documentation/master/#shuffle
/// See https://clang.llvm.org/docs/LanguageExtensions.html#langext-builtin-shufflevector
pub fn shuffleVectorIndex(comptime this_index: c_int, comptime source_vector_len: usize) i32 {
    if (this_index <= 0) return 0;

    const positive_index = @intCast(usize, this_index);
    if (positive_index < source_vector_len) return @intCast(i32, this_index);
    const b_index = positive_index - source_vector_len;
    return ~@intCast(i32, b_index);
}

test "shuffleVectorIndex" {
    const vector_len: usize = 4;

    testing.expect(shuffleVectorIndex(-1, vector_len) == 0);

    testing.expect(shuffleVectorIndex(0, vector_len) == 0);
    testing.expect(shuffleVectorIndex(1, vector_len) == 1);
    testing.expect(shuffleVectorIndex(2, vector_len) == 2);
    testing.expect(shuffleVectorIndex(3, vector_len) == 3);

    testing.expect(shuffleVectorIndex(4, vector_len) == -1);
    testing.expect(shuffleVectorIndex(5, vector_len) == -2);
    testing.expect(shuffleVectorIndex(6, vector_len) == -3);
    testing.expect(shuffleVectorIndex(7, vector_len) == -4);
}
