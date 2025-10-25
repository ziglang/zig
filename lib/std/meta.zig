const builtin = @import("builtin");
const std = @import("std.zig");
const debug = std.debug;
const mem = std.mem;
const math = std.math;
const testing = std.testing;
const root = @import("root");

pub const TrailerFlags = @import("meta/trailer_flags.zig").TrailerFlags;

const Type = std.builtin.Type;

test {
    _ = TrailerFlags;
}

/// Returns the variant of an enum type, `T`, which is named `str`, or `null` if no such variant exists.
pub fn stringToEnum(comptime T: type, str: []const u8) ?T {
    // Using StaticStringMap here is more performant, but it will start to take too
    // long to compile if the enum is large enough, due to the current limits of comptime
    // performance when doing things like constructing lookup maps at comptime.
    // TODO The '100' here is arbitrary and should be increased when possible:
    // - https://github.com/ziglang/zig/issues/4055
    // - https://github.com/ziglang/zig/issues/3863
    if (@typeInfo(T).@"enum".fields.len <= 100) {
        const kvs = comptime build_kvs: {
            const EnumKV = struct { []const u8, T };
            var kvs_array: [@typeInfo(T).@"enum".fields.len]EnumKV = undefined;
            for (@typeInfo(T).@"enum".fields, 0..) |enumField, i| {
                kvs_array[i] = .{ enumField.name, @field(T, enumField.name) };
            }
            break :build_kvs kvs_array[0..];
        };
        const map = std.StaticStringMap(T).initComptime(kvs);
        return map.get(str);
    } else {
        inline for (@typeInfo(T).@"enum".fields) |enumField| {
            if (mem.eql(u8, str, enumField.name)) {
                return @field(T, enumField.name);
            }
        }
        return null;
    }
}

test stringToEnum {
    const E1 = enum {
        A,
        B,
    };
    try testing.expect(E1.A == stringToEnum(E1, "A").?);
    try testing.expect(E1.B == stringToEnum(E1, "B").?);
    try testing.expect(null == stringToEnum(E1, "C"));
}

/// Returns the alignment of type T.
/// Note that if T is a pointer type the result is different than the one
/// returned by @alignOf(T).
/// If T is a pointer type the alignment of the type it points to is returned.
pub fn alignment(comptime T: type) comptime_int {
    return switch (@typeInfo(T)) {
        .optional => |info| switch (@typeInfo(info.child)) {
            .pointer, .@"fn" => alignment(info.child),
            else => @alignOf(T),
        },
        .pointer => |info| info.alignment,
        else => @alignOf(T),
    };
}

test alignment {
    try testing.expect(alignment(u8) == 1);
    try testing.expect(alignment(*align(1) u8) == 1);
    try testing.expect(alignment(*align(2) u8) == 2);
    try testing.expect(alignment([]align(1) u8) == 1);
    try testing.expect(alignment([]align(2) u8) == 2);
    try testing.expect(alignment(fn () void) > 0);
    try testing.expect(alignment(*const fn () void) > 0);
    try testing.expect(alignment(*align(128) const fn () void) == 128);
}

/// Given a parameterized type (array, vector, pointer, optional), returns the "child type".
pub fn Child(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .array => |info| info.child,
        .vector => |info| info.child,
        .pointer => |info| info.child,
        .optional => |info| info.child,
        else => @compileError("Expected pointer, optional, array or vector type, found '" ++ @typeName(T) ++ "'"),
    };
}

test Child {
    try testing.expect(Child([1]u8) == u8);
    try testing.expect(Child(*u8) == u8);
    try testing.expect(Child([]u8) == u8);
    try testing.expect(Child(?u8) == u8);
    try testing.expect(Child(@Vector(2, u8)) == u8);
}

/// Given a "memory span" type (array, slice, vector, or pointer to such), returns the "element type".
pub fn Elem(comptime T: type) type {
    switch (@typeInfo(T)) {
        .array => |info| return info.child,
        .vector => |info| return info.child,
        .pointer => |info| switch (info.size) {
            .one => switch (@typeInfo(info.child)) {
                .array => |array_info| return array_info.child,
                .vector => |vector_info| return vector_info.child,
                else => {},
            },
            .many, .c, .slice => return info.child,
        },
        .optional => |info| return Elem(info.child),
        else => {},
    }
    @compileError("Expected pointer, slice, array or vector type, found '" ++ @typeName(T) ++ "'");
}

test Elem {
    try testing.expect(Elem([1]u8) == u8);
    try testing.expect(Elem([*]u8) == u8);
    try testing.expect(Elem([]u8) == u8);
    try testing.expect(Elem(*[10]u8) == u8);
    try testing.expect(Elem(@Vector(2, u8)) == u8);
    try testing.expect(Elem(*@Vector(2, u8)) == u8);
    try testing.expect(Elem(?[*]u8) == u8);
}

/// Given a type which can have a sentinel e.g. `[:0]u8`, returns the sentinel value,
/// or `null` if there is not one.
/// Types which cannot possibly have a sentinel will be a compile error.
/// Result is always comptime-known.
pub inline fn sentinel(comptime T: type) ?Elem(T) {
    switch (@typeInfo(T)) {
        .array => |info| return info.sentinel(),
        .pointer => |info| {
            switch (info.size) {
                .many, .slice => return info.sentinel(),
                .one => switch (@typeInfo(info.child)) {
                    .array => |array_info| return array_info.sentinel(),
                    else => {},
                },
                else => {},
            }
        },
        else => {},
    }
    @compileError("type '" ++ @typeName(T) ++ "' cannot possibly have a sentinel");
}

test sentinel {
    try testSentinel();
    try comptime testSentinel();
}

fn testSentinel() !void {
    try testing.expectEqual(@as(u8, 0), sentinel([:0]u8).?);
    try testing.expectEqual(@as(u8, 0), sentinel([*:0]u8).?);
    try testing.expectEqual(@as(u8, 0), sentinel([5:0]u8).?);
    try testing.expectEqual(@as(u8, 0), sentinel(*const [5:0]u8).?);

    try testing.expect(sentinel([]u8) == null);
    try testing.expect(sentinel([*]u8) == null);
    try testing.expect(sentinel([5]u8) == null);
    try testing.expect(sentinel(*const [5]u8) == null);
}

/// Given a "memory span" type, returns the same type except with the given sentinel value.
pub fn Sentinel(comptime T: type, comptime sentinel_val: Elem(T)) type {
    switch (@typeInfo(T)) {
        .pointer => |info| switch (info.size) {
            .one => switch (@typeInfo(info.child)) {
                .array => |array_info| return @Type(.{
                    .pointer = .{
                        .size = info.size,
                        .is_const = info.is_const,
                        .is_volatile = info.is_volatile,
                        .alignment = info.alignment,
                        .address_space = info.address_space,
                        .child = @Type(.{
                            .array = .{
                                .len = array_info.len,
                                .child = array_info.child,
                                .sentinel_ptr = @as(?*const anyopaque, @ptrCast(&sentinel_val)),
                            },
                        }),
                        .is_allowzero = info.is_allowzero,
                        .sentinel_ptr = info.sentinel_ptr,
                    },
                }),
                else => {},
            },
            .many, .slice => return @Type(.{
                .pointer = .{
                    .size = info.size,
                    .is_const = info.is_const,
                    .is_volatile = info.is_volatile,
                    .alignment = info.alignment,
                    .address_space = info.address_space,
                    .child = info.child,
                    .is_allowzero = info.is_allowzero,
                    .sentinel_ptr = @as(?*const anyopaque, @ptrCast(&sentinel_val)),
                },
            }),
            else => {},
        },
        .optional => |info| switch (@typeInfo(info.child)) {
            .pointer => |ptr_info| switch (ptr_info.size) {
                .many => return @Type(.{
                    .optional = .{
                        .child = @Type(.{
                            .pointer = .{
                                .size = ptr_info.size,
                                .is_const = ptr_info.is_const,
                                .is_volatile = ptr_info.is_volatile,
                                .alignment = ptr_info.alignment,
                                .address_space = ptr_info.address_space,
                                .child = ptr_info.child,
                                .is_allowzero = ptr_info.is_allowzero,
                                .sentinel_ptr = @as(?*const anyopaque, @ptrCast(&sentinel_val)),
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

pub fn containerLayout(comptime T: type) Type.ContainerLayout {
    return switch (@typeInfo(T)) {
        .@"struct" => |info| info.layout,
        .@"union" => |info| info.layout,
        else => @compileError("expected struct or union type, found '" ++ @typeName(T) ++ "'"),
    };
}

test containerLayout {
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

    try testing.expect(containerLayout(S1) == .auto);
    try testing.expect(containerLayout(S2) == .@"packed");
    try testing.expect(containerLayout(S3) == .@"extern");
    try testing.expect(containerLayout(U1) == .auto);
    try testing.expect(containerLayout(U2) == .@"packed");
    try testing.expect(containerLayout(U3) == .@"extern");
}

/// Instead of this function, prefer to use e.g. `@typeInfo(foo).@"struct".decls`
/// directly when you know what kind of type it is.
pub fn declarations(comptime T: type) []const Type.Declaration {
    return switch (@typeInfo(T)) {
        .@"struct" => |info| info.decls,
        .@"enum" => |info| info.decls,
        .@"union" => |info| info.decls,
        .@"opaque" => |info| info.decls,
        else => @compileError("Expected struct, enum, union, or opaque type, found '" ++ @typeName(T) ++ "'"),
    };
}

test declarations {
    const E1 = enum {
        A,

        pub fn a() void {}
    };
    const S1 = struct {
        pub fn a() void {}
    };
    const U1 = union {
        b: u8,

        pub fn a() void {}
    };
    const O1 = opaque {
        pub fn a() void {}
    };

    const decls = comptime [_][]const Type.Declaration{
        declarations(E1),
        declarations(S1),
        declarations(U1),
        declarations(O1),
    };

    inline for (decls) |decl| {
        try testing.expect(decl.len == 1);
        try testing.expect(comptime mem.eql(u8, decl[0].name, "a"));
    }
}

pub fn declarationInfo(comptime T: type, comptime decl_name: []const u8) Type.Declaration {
    inline for (comptime declarations(T)) |decl| {
        if (comptime mem.eql(u8, decl.name, decl_name))
            return decl;
    }

    @compileError("'" ++ @typeName(T) ++ "' has no declaration '" ++ decl_name ++ "'");
}

test declarationInfo {
    const E1 = enum {
        A,

        pub fn a() void {}
    };
    const S1 = struct {
        pub fn a() void {}
    };
    const U1 = union {
        b: u8,

        pub fn a() void {}
    };

    const infos = comptime [_]Type.Declaration{
        declarationInfo(E1, "a"),
        declarationInfo(S1, "a"),
        declarationInfo(U1, "a"),
    };

    inline for (infos) |info| {
        try testing.expect(comptime mem.eql(u8, info.name, "a"));
    }
}
pub fn fields(comptime T: type) switch (@typeInfo(T)) {
    .@"struct" => []const Type.StructField,
    .@"union" => []const Type.UnionField,
    .@"enum" => []const Type.EnumField,
    .error_set => []const Type.Error,
    else => @compileError("Expected struct, union, error set or enum type, found '" ++ @typeName(T) ++ "'"),
} {
    return switch (@typeInfo(T)) {
        .@"struct" => |info| info.fields,
        .@"union" => |info| info.fields,
        .@"enum" => |info| info.fields,
        .error_set => |errors| errors.?, // must be non global error set
        else => @compileError("Expected struct, union, error set or enum type, found '" ++ @typeName(T) ++ "'"),
    };
}

test fields {
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

    try testing.expect(e1f.len == 1);
    try testing.expect(e2f.len == 1);
    try testing.expect(sf.len == 1);
    try testing.expect(uf.len == 1);
    try testing.expect(mem.eql(u8, e1f[0].name, "A"));
    try testing.expect(mem.eql(u8, e2f[0].name, "A"));
    try testing.expect(mem.eql(u8, sf[0].name, "a"));
    try testing.expect(mem.eql(u8, uf[0].name, "a"));
    try testing.expect(comptime sf[0].type == u8);
    try testing.expect(comptime uf[0].type == u8);
}

pub fn fieldInfo(comptime T: type, comptime field: FieldEnum(T)) switch (@typeInfo(T)) {
    .@"struct" => Type.StructField,
    .@"union" => Type.UnionField,
    .@"enum" => Type.EnumField,
    .error_set => Type.Error,
    else => @compileError("Expected struct, union, error set or enum type, found '" ++ @typeName(T) ++ "'"),
} {
    return fields(T)[@intFromEnum(field)];
}

test fieldInfo {
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

    try testing.expect(mem.eql(u8, e1f.name, "A"));
    try testing.expect(mem.eql(u8, e2f.name, "A"));
    try testing.expect(mem.eql(u8, sf.name, "a"));
    try testing.expect(mem.eql(u8, uf.name, "a"));
    try testing.expect(comptime sf.type == u8);
    try testing.expect(comptime uf.type == u8);
}

pub fn fieldNames(comptime T: type) *const [fields(T).len][:0]const u8 {
    return comptime blk: {
        const fieldInfos = fields(T);
        var names: [fieldInfos.len][:0]const u8 = undefined;
        for (&names, fieldInfos) |*name, field| name.* = field.name;
        const final = names;
        break :blk &final;
    };
}

test fieldNames {
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

    try testing.expect(e1names.len == 2);
    try testing.expectEqualSlices(u8, e1names[0], "A");
    try testing.expectEqualSlices(u8, e1names[1], "B");
    try testing.expect(e2names.len == 1);
    try testing.expectEqualSlices(u8, e2names[0], "A");
    try testing.expect(s1names.len == 1);
    try testing.expectEqualSlices(u8, s1names[0], "a");
    try testing.expect(u1names.len == 2);
    try testing.expectEqualSlices(u8, u1names[0], "a");
    try testing.expectEqualSlices(u8, u1names[1], "b");
}

/// Given an enum or error set type, returns a pointer to an array containing all tags for that
/// enum or error set.
pub fn tags(comptime T: type) *const [fields(T).len]T {
    return comptime blk: {
        const fieldInfos = fields(T);
        var res: [fieldInfos.len]T = undefined;
        for (fieldInfos, 0..) |field, i| {
            res[i] = @field(T, field.name);
        }
        const final = res;
        break :blk &final;
    };
}

test tags {
    const E1 = enum { A, B };
    const E2 = error{A};

    const e1_tags = tags(E1);
    const e2_tags = tags(E2);

    try testing.expect(e1_tags.len == 2);
    try testing.expectEqual(E1.A, e1_tags[0]);
    try testing.expectEqual(E1.B, e1_tags[1]);
    try testing.expect(e2_tags.len == 1);
    try testing.expectEqual(E2.A, e2_tags[0]);
}

/// Returns an enum with a variant named after each field of `T`.
pub fn FieldEnum(comptime T: type) type {
    const field_infos = fields(T);

    if (field_infos.len == 0) {
        return @Type(.{
            .@"enum" = .{
                .tag_type = u0,
                .fields = &.{},
                .decls = &.{},
                .is_exhaustive = true,
            },
        });
    }

    if (@typeInfo(T) == .@"union") {
        if (@typeInfo(T).@"union".tag_type) |tag_type| {
            for (std.enums.values(tag_type), 0..) |v, i| {
                if (@intFromEnum(v) != i) break; // enum values not consecutive
                if (!std.mem.eql(u8, @tagName(v), field_infos[i].name)) break; // fields out of order
            } else {
                return tag_type;
            }
        }
    }

    var enumFields: [field_infos.len]std.builtin.Type.EnumField = undefined;
    var decls = [_]std.builtin.Type.Declaration{};
    inline for (field_infos, 0..) |field, i| {
        enumFields[i] = .{
            .name = field.name,
            .value = i,
        };
    }
    return @Type(.{
        .@"enum" = .{
            .tag_type = std.math.IntFittingRange(0, field_infos.len - 1),
            .fields = &enumFields,
            .decls = &decls,
            .is_exhaustive = true,
        },
    });
}

fn expectEqualEnum(expected: anytype, actual: @TypeOf(expected)) !void {
    // TODO: https://github.com/ziglang/zig/issues/7419
    // testing.expectEqual(@typeInfo(expected).@"enum", @typeInfo(actual).@"enum");
    try testing.expectEqual(
        @typeInfo(expected).@"enum".tag_type,
        @typeInfo(actual).@"enum".tag_type,
    );
    // For comparing decls and fields, we cannot use the meta eql function here
    // because the language does not guarantee that the slice pointers for field names
    // and decl names will be the same.
    comptime {
        const expected_fields = @typeInfo(expected).@"enum".fields;
        const actual_fields = @typeInfo(actual).@"enum".fields;
        if (expected_fields.len != actual_fields.len) return error.FailedTest;
        for (expected_fields, 0..) |expected_field, i| {
            const actual_field = actual_fields[i];
            try testing.expectEqual(expected_field.value, actual_field.value);
            try testing.expectEqualStrings(expected_field.name, actual_field.name);
        }
    }
    comptime {
        const expected_decls = @typeInfo(expected).@"enum".decls;
        const actual_decls = @typeInfo(actual).@"enum".decls;
        if (expected_decls.len != actual_decls.len) return error.FailedTest;
        for (expected_decls, 0..) |expected_decl, i| {
            const actual_decl = actual_decls[i];
            try testing.expectEqualStrings(expected_decl.name, actual_decl.name);
        }
    }
    try testing.expectEqual(
        @typeInfo(expected).@"enum".is_exhaustive,
        @typeInfo(actual).@"enum".is_exhaustive,
    );
}

test FieldEnum {
    try expectEqualEnum(enum {}, FieldEnum(struct {}));
    try expectEqualEnum(enum { a }, FieldEnum(struct { a: u8 }));
    try expectEqualEnum(enum { a, b, c }, FieldEnum(struct { a: u8, b: void, c: f32 }));
    try expectEqualEnum(enum { a, b, c }, FieldEnum(union { a: u8, b: void, c: f32 }));

    const Tagged = union(enum) { a: u8, b: void, c: f32 };
    try testing.expectEqual(Tag(Tagged), FieldEnum(Tagged));

    const Tag2 = enum { a, b, c };
    const Tagged2 = union(Tag2) { a: u8, b: void, c: f32 };
    try testing.expect(Tag(Tagged2) == FieldEnum(Tagged2));

    const Tag3 = enum(u8) { a, b, c = 7 };
    const Tagged3 = union(Tag3) { a: u8, b: void, c: f32 };
    try testing.expect(Tag(Tagged3) != FieldEnum(Tagged3));
}

pub fn DeclEnum(comptime T: type) type {
    const fieldInfos = std.meta.declarations(T);
    var enumDecls: [fieldInfos.len]std.builtin.Type.EnumField = undefined;
    var decls = [_]std.builtin.Type.Declaration{};
    inline for (fieldInfos, 0..) |field, i| {
        enumDecls[i] = .{ .name = field.name, .value = i };
    }
    return @Type(.{
        .@"enum" = .{
            .tag_type = std.math.IntFittingRange(0, if (fieldInfos.len == 0) 0 else fieldInfos.len - 1),
            .fields = &enumDecls,
            .decls = &decls,
            .is_exhaustive = true,
        },
    });
}

test DeclEnum {
    const A = struct {
        pub const a: u8 = 0;
    };
    const B = union {
        foo: void,

        pub const a: u8 = 0;
        pub const b: void = {};
        pub const c: f32 = 0;
    };
    const C = enum {
        bar,

        pub const a: u8 = 0;
        pub const b: void = {};
        pub const c: f32 = 0;
    };
    const D = struct {};

    try expectEqualEnum(enum { a }, DeclEnum(A));
    try expectEqualEnum(enum { a, b, c }, DeclEnum(B));
    try expectEqualEnum(enum { a, b, c }, DeclEnum(C));
    try expectEqualEnum(enum {}, DeclEnum(D));
}

pub fn Tag(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .@"enum" => |info| info.tag_type,
        .@"union" => |info| info.tag_type orelse @compileError(@typeName(T) ++ " has no tag type"),
        else => @compileError("expected enum or union type, found '" ++ @typeName(T) ++ "'"),
    };
}

test Tag {
    const E = enum(u8) {
        C = 33,
        D,
    };
    const U = union(E) {
        C: u8,
        D: u16,
    };

    try testing.expect(Tag(E) == u8);
    try testing.expect(Tag(U) == E);
}

/// Returns the active tag of a tagged union
pub fn activeTag(u: anytype) Tag(@TypeOf(u)) {
    const T = @TypeOf(u);
    return @as(Tag(T), u);
}

test activeTag {
    const UE = enum {
        Int,
        Float,
    };

    const U = union(UE) {
        Int: u32,
        Float: f32,
    };

    var u = U{ .Int = 32 };
    try testing.expect(activeTag(u) == UE.Int);

    u = U{ .Float = 112.9876 };
    try testing.expect(activeTag(u) == UE.Float);
}

/// Deprecated: Use @FieldType(U, tag_name)
const TagPayloadType = TagPayload;

/// Deprecated: Use @FieldType(U, tag_name)
pub fn TagPayloadByName(comptime U: type, comptime tag_name: []const u8) type {
    const info = @typeInfo(U).@"union";

    inline for (info.fields) |field_info| {
        if (comptime mem.eql(u8, field_info.name, tag_name))
            return field_info.type;
    }

    @compileError("no field '" ++ tag_name ++ "' in union '" ++ @typeName(U) ++ "'");
}

/// Deprecated: Use @FieldType(U, @tagName(tag))
pub fn TagPayload(comptime U: type, comptime tag: Tag(U)) type {
    return TagPayloadByName(U, @tagName(tag));
}

test TagPayload {
    const Event = union(enum) {
        Moved: struct {
            from: i32,
            to: i32,
        },
    };
    const MovedEvent = TagPayload(Event, Event.Moved);
    const e: Event = .{ .Moved = undefined };
    try testing.expect(MovedEvent == @TypeOf(e.Moved));
}

/// Compares two of any type for equality. Containers that do not support comparison
/// on their own are compared on a field-by-field basis. Pointers are not followed.
pub fn eql(a: anytype, b: @TypeOf(a)) bool {
    const T = @TypeOf(a);

    switch (@typeInfo(T)) {
        .@"struct" => |info| {
            if (info.layout == .@"packed") return a == b;

            inline for (info.fields) |field_info| {
                if (!eql(@field(a, field_info.name), @field(b, field_info.name))) return false;
            }
            return true;
        },
        .error_union => {
            if (a) |a_p| {
                if (b) |b_p| return eql(a_p, b_p) else |_| return false;
            } else |a_e| {
                if (b) |_| return false else |b_e| return a_e == b_e;
            }
        },
        .@"union" => |info| {
            if (info.tag_type) |UnionTag| {
                const tag_a: UnionTag = a;
                const tag_b: UnionTag = b;
                if (tag_a != tag_b) return false;

                return switch (a) {
                    inline else => |val, tag| return eql(val, @field(b, @tagName(tag))),
                };
            }

            @compileError("cannot compare untagged union type " ++ @typeName(T));
        },
        .array => {
            if (a.len != b.len) return false;
            for (a, 0..) |e, i|
                if (!eql(e, b[i])) return false;
            return true;
        },
        .vector => return @reduce(.And, a == b),
        .pointer => |info| {
            return switch (info.size) {
                .one, .many, .c => a == b,
                .slice => a.ptr == b.ptr and a.len == b.len,
            };
        },
        .optional => {
            if (a == null and b == null) return true;
            if (a == null or b == null) return false;
            return eql(a.?, b.?);
        },
        else => return a == b,
    }
}

test eql {
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

    var s_3 = S{
        .a = 134,
        .b = 123.3,
        .c = "12345".*,
    };

    const u_1 = U{ .f = 24 };
    const u_2 = U{ .s = s_1 };
    const u_3 = U{ .f = 24 };

    try testing.expect(eql(s_1, s_3));
    try testing.expect(eql(&s_1, &s_1));
    try testing.expect(!eql(&s_1, &s_3));
    try testing.expect(eql(u_1, u_3));
    try testing.expect(!eql(u_1, u_2));

    const a1 = "abcdef".*;
    const a2 = "abcdef".*;
    const a3 = "ghijkl".*;

    try testing.expect(eql(a1, a2));
    try testing.expect(!eql(a1, a3));

    const EU = struct {
        fn tst(err: bool) !u8 {
            if (err) return error.Error;
            return @as(u8, 5);
        }
    };

    try testing.expect(eql(EU.tst(true), EU.tst(true)));
    try testing.expect(eql(EU.tst(false), EU.tst(false)));
    try testing.expect(!eql(EU.tst(false), EU.tst(true)));

    const CU = union(enum) {
        a: void,
        b: void,
        c: comptime_int,
    };

    try testing.expect(eql(CU{ .a = {} }, .a));
    try testing.expect(!eql(CU{ .a = {} }, .b));

    if (builtin.cpu.arch == .hexagon) return error.SkipZigTest;

    const V = @Vector(4, u32);
    const v1: V = @splat(1);
    const v2: V = @splat(1);
    const v3: V = @splat(2);

    try testing.expect(eql(v1, v2));
    try testing.expect(!eql(v1, v3));
}

/// Deprecated: use `std.enums.fromInt` instead and handle null.
pub const IntToEnumError = error{InvalidEnumTag};

/// Deprecated: use `std.enums.fromInt` instead and handle null instead of an error.
pub fn intToEnum(comptime EnumTag: type, tag_int: anytype) IntToEnumError!EnumTag {
    return std.enums.fromInt(EnumTag, tag_int) orelse return error.InvalidEnumTag;
}

/// Given a type and a name, return the field index according to source order.
/// Returns `null` if the field is not found.
pub fn fieldIndex(comptime T: type, comptime name: []const u8) ?comptime_int {
    inline for (fields(T), 0..) |field, i| {
        if (mem.eql(u8, field.name, name))
            return i;
    }
    return null;
}

/// Returns a slice of pointers to public declarations of a namespace.
pub fn declList(comptime Namespace: type, comptime Decl: type) []const *const Decl {
    const S = struct {
        fn declNameLessThan(context: void, lhs: *const Decl, rhs: *const Decl) bool {
            _ = context;
            return mem.lessThan(u8, lhs.name, rhs.name);
        }
    };
    comptime {
        const decls = declarations(Namespace);
        var array: [decls.len]*const Decl = undefined;
        for (decls, 0..) |decl, i| {
            array[i] = &@field(Namespace, decl.name);
        }
        mem.sort(*const Decl, &array, {}, S.declNameLessThan);
        return &array;
    }
}

pub fn Int(comptime signedness: std.builtin.Signedness, comptime bit_count: u16) type {
    return @Type(.{
        .int = .{
            .signedness = signedness,
            .bits = bit_count,
        },
    });
}

pub fn Float(comptime bit_count: u8) type {
    return @Type(.{
        .float = .{ .bits = bit_count },
    });
}

test Float {
    try testing.expectEqual(f16, Float(16));
    try testing.expectEqual(f32, Float(32));
    try testing.expectEqual(f64, Float(64));
    try testing.expectEqual(f128, Float(128));
}

/// For a given function type, returns a tuple type which fields will
/// correspond to the argument types.
///
/// Examples:
/// - `ArgsTuple(fn () void)` ⇒ `tuple { }`
/// - `ArgsTuple(fn (a: u32) u32)` ⇒ `tuple { u32 }`
/// - `ArgsTuple(fn (a: u32, b: f16) noreturn)` ⇒ `tuple { u32, f16 }`
pub fn ArgsTuple(comptime Function: type) type {
    const info = @typeInfo(Function);
    if (info != .@"fn")
        @compileError("ArgsTuple expects a function type");

    const function_info = info.@"fn";
    if (function_info.is_var_args)
        @compileError("Cannot create ArgsTuple for variadic function");

    var argument_field_list: [function_info.params.len]type = undefined;
    inline for (function_info.params, 0..) |arg, i| {
        const T = arg.type orelse @compileError("cannot create ArgsTuple for function with an 'anytype' parameter");
        argument_field_list[i] = T;
    }

    return CreateUniqueTuple(argument_field_list.len, argument_field_list);
}

/// For a given anonymous list of types, returns a new tuple type
/// with those types as fields.
///
/// Examples:
/// - `Tuple(&[_]type {})` ⇒ `tuple { }`
/// - `Tuple(&[_]type {f32})` ⇒ `tuple { f32 }`
/// - `Tuple(&[_]type {f32,u32})` ⇒ `tuple { f32, u32 }`
pub fn Tuple(comptime types: []const type) type {
    return CreateUniqueTuple(types.len, types[0..types.len].*);
}

fn CreateUniqueTuple(comptime N: comptime_int, comptime types: [N]type) type {
    var tuple_fields: [types.len]std.builtin.Type.StructField = undefined;
    inline for (types, 0..) |T, i| {
        @setEvalBranchQuota(10_000);
        var num_buf: [128]u8 = undefined;
        tuple_fields[i] = .{
            .name = std.fmt.bufPrintSentinel(&num_buf, "{d}", .{i}, 0) catch unreachable,
            .type = T,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(T),
        };
    }

    return @Type(.{
        .@"struct" = .{
            .is_tuple = true,
            .layout = .auto,
            .decls = &.{},
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
        if (info != .@"struct")
            @compileError("Expected struct type");
        if (!info.@"struct".is_tuple)
            @compileError("Struct type must be a tuple type");

        const fields_list = std.meta.fields(Actual);
        if (expected.len != fields_list.len)
            @compileError("Argument count mismatch");

        inline for (fields_list, 0..) |fld, i| {
            if (expected[i] != fld.type) {
                @compileError("Field " ++ fld.name ++ " expected to be type " ++ @typeName(expected[i]) ++ ", but was type " ++ @typeName(fld.type));
            }
        }
    }
};

test ArgsTuple {
    TupleTester.assertTuple(.{}, ArgsTuple(fn () void));
    TupleTester.assertTuple(.{u32}, ArgsTuple(fn (a: u32) []const u8));
    TupleTester.assertTuple(.{ u32, f16 }, ArgsTuple(fn (a: u32, b: f16) noreturn));
    TupleTester.assertTuple(.{ u32, f16, []const u8, void }, ArgsTuple(fn (a: u32, b: f16, c: []const u8, void) noreturn));
    TupleTester.assertTuple(.{u32}, ArgsTuple(fn (comptime a: u32) []const u8));
}

test Tuple {
    TupleTester.assertTuple(.{}, Tuple(&[_]type{}));
    TupleTester.assertTuple(.{u32}, Tuple(&[_]type{u32}));
    TupleTester.assertTuple(.{ u32, f16 }, Tuple(&[_]type{ u32, f16 }));
    TupleTester.assertTuple(.{ u32, f16, []const u8, void }, Tuple(&[_]type{ u32, f16, []const u8, void }));
}

test "Tuple deduplication" {
    const T1 = std.meta.Tuple(&.{ u32, f32, i8 });
    const T2 = std.meta.Tuple(&.{ u32, f32, i8 });
    const T3 = std.meta.Tuple(&.{ u32, f32, i7 });

    if (T1 != T2) {
        @compileError("std.meta.Tuple doesn't deduplicate tuple types.");
    }
    if (T1 == T3) {
        @compileError("std.meta.Tuple fails to generate different types.");
    }
}

test "ArgsTuple forwarding" {
    const T1 = std.meta.Tuple(&.{ u32, f32, i8 });
    const T2 = std.meta.ArgsTuple(fn (u32, f32, i8) void);
    const T3 = std.meta.ArgsTuple(fn (u32, f32, i8) callconv(.c) noreturn);

    if (T1 != T2) {
        @compileError("std.meta.ArgsTuple produces different types than std.meta.Tuple");
    }
    if (T1 != T3) {
        @compileError("std.meta.ArgsTuple produces different types for the same argument lists.");
    }
}

/// Returns whether `error_union` contains an error.
pub fn isError(error_union: anytype) bool {
    return if (error_union) |_| false else |_| true;
}

test isError {
    try std.testing.expect(isError(math.divTrunc(u8, 5, 0)));
    try std.testing.expect(!isError(math.divTrunc(u8, 5, 5)));
}

/// Returns true if a type has a namespace and the namespace contains `name`;
/// `false` otherwise. Result is always comptime-known.
pub inline fn hasFn(comptime T: type, comptime name: []const u8) bool {
    switch (@typeInfo(T)) {
        .@"struct", .@"union", .@"enum", .@"opaque" => {},
        else => return false,
    }
    if (!@hasDecl(T, name))
        return false;

    return @typeInfo(@TypeOf(@field(T, name))) == .@"fn";
}

test hasFn {
    const S1 = struct {
        pub fn foo() void {}
    };

    try std.testing.expect(hasFn(S1, "foo"));
    try std.testing.expect(!hasFn(S1, "bar"));
    try std.testing.expect(!hasFn(*S1, "foo"));

    const S2 = struct {
        foo: fn () void,
    };

    try std.testing.expect(!hasFn(S2, "foo"));
}

/// Returns true if a type has a `name` method; `false` otherwise.
/// Result is always comptime-known.
pub inline fn hasMethod(comptime T: type, comptime name: []const u8) bool {
    return switch (@typeInfo(T)) {
        .pointer => |P| switch (P.size) {
            .one => hasFn(P.child, name),
            .many, .slice, .c => false,
        },
        else => hasFn(T, name),
    };
}

test hasMethod {
    try std.testing.expect(!hasMethod(u32, "foo"));
    try std.testing.expect(!hasMethod([]u32, "len"));
    try std.testing.expect(!hasMethod(struct { u32, u64 }, "len"));

    const S1 = struct {
        pub fn foo() void {}
    };

    try std.testing.expect(hasMethod(S1, "foo"));
    try std.testing.expect(hasMethod(*S1, "foo"));

    try std.testing.expect(!hasMethod(S1, "bar"));
    try std.testing.expect(!hasMethod(*[1]S1, "foo"));
    try std.testing.expect(!hasMethod(*[10]S1, "foo"));
    try std.testing.expect(!hasMethod([]S1, "foo"));

    const S2 = struct {
        foo: fn () void,
    };

    try std.testing.expect(!hasMethod(S2, "foo"));

    const U = union {
        pub fn foo() void {}
    };

    try std.testing.expect(hasMethod(U, "foo"));
    try std.testing.expect(hasMethod(*U, "foo"));
    try std.testing.expect(!hasMethod(U, "bar"));
}

/// True if every value of the type `T` has a single unique byte pattern representing it.
/// In other words, `T` has no padding and no insignificant bits.
/// Result is always comptime-known.
pub fn hasUniqueRepresentation(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        // If the runtime size of an integer is exactly
        // equal to its logical bits divided by 8,
        // then there cannot be any padding bytes.
        .int,
        // Error sets are represented by an integer
        // with a width determined by the error limit.
        .error_set,
        // For this case, we are considering
        // NaN values to be distinct, as the
        // payload and signal bit are significant.
        // With this in mind, every logical bit in
        // a float is significant, and thus they
        // may be treated as integers.
        .float,
        => @sizeOf(T) * 8 == @bitSizeOf(T),

        // An enum is just a wrapper over its integer tag type
        .@"enum" => |info| hasUniqueRepresentation(info.tag_type),

        // Void (and void-equivalent types)
        // only have one value, and they don't
        // have padding bytes because they don't
        // have bytes at all.
        .void => true,

        // Known issue: pointers to comptime-only types
        // should not return true, but detecting whether
        // a type is comptime-onlt takes up an impractical
        // amount of eval branch quota.
        .pointer => |info| switch (info.size) {
            // Raw pointers are always unique.
            // TODO: detect comptime-only types while
            // being reasonable with eval branch quota
            .one, .many, .c => true,
            // While there is no guarantee on the layout of
            // a slice type, we can still do something here.
            // Informationally, slices are equivalent to o
            // raw pointers, one representing the ptr field
            // and one representing the len field. This makes it
            // theoretically impossible for a slice to be smaller than
            // the sum of the logical sizes of these pointers.
            // In turn, if the size of the slice is exactly equal to
            // that sum, then we can be sure that there is
            // no padding unless whoever implemented the compiler
            // is a powerful wizard capable of defying the rules
            // of mathematics, in which case we are obliged
            // to sabotage their conquests by intentionally
            // writing them a faulty standard library.
            .slice => slice_check: {
                const ManyPtr = comptime manyptr: {
                    var new_info = info;
                    new_info.size = .many;
                    break :manyptr @Type(.{ .pointer = new_info });
                };
                const expected_size = @bitSizeOf(ManyPtr) + @bitSizeOf(usize);
                break :slice_check @sizeOf(T) * 8 == expected_size;
            },
        },

        .optional => |info| switch (@typeInfo(info.child)) {
            .pointer => |ptr| switch (ptr.size) {
                // An optional nonzero pointer is guaranteed to be
                // represented by an actual pointer. Just make sure
                // it's not a comptime-only pointer!
                .one, .many => !ptr.is_allowzero,
                // C pointers can be null, so the above does not apply
                .c => false,
                // Our trick with slices from earlier does not apply
                // here, as when the pointer is null, the "len" pseudo-field
                // is inaccessible and could be anything.
                .slice => false,
            },

            // ?noreturn is void-equivalent.
            // The size check is just a sanity test.
            .noreturn => @sizeOf(T) == 0,

            // In practice, this is also true for
            // optional error sets, but
            // this is not guaranteed, and there
            // is no practical way to check.
            else => false,
        },

        .@"struct" => |info| switch (info.layout) {
            // For packed structs, we only need to check the backing integer
            .@"packed" => hasUniqueRepresentation(info.backing_integer.?),

            // For regular struct types, we need to check that
            // every field has a unique representation,
            // and that the size of the struct is
            // equal to the sum of the sizes of the fields
            .auto, .@"extern" => {
                comptime var sum_size: usize = 0;
                inline for (info.fields) |field| {
                    if (field.is_comptime) continue;
                    if (!hasUniqueRepresentation(field.type)) return false;
                    sum_size += @sizeOf(field.type);
                }
                return @sizeOf(T) == sum_size;
            },
        },

        .@"union" => |info| {
            const payload_size: usize = payload_size: {
                if (info.tag_type) |UTag| {
                    // For tagged unions, check that
                    // that tag has a unique representation,
                    // the fields all have unique
                    // representations and the same size,
                    // and that the union's size is the size
                    // of the tag plus the size of the payload.
                    if (hasUniqueRepresentation(UTag)) {
                        break :payload_size @sizeOf(T) - @sizeOf(UTag);
                    } else {
                        return false;
                    }
                }

                break :payload_size switch (info.fields.len) {
                    // For empty unions, this should never be checked.
                    0 => undefined,

                    // For single-field untagged unions, check that
                    // the union's size is equal to its payload.
                    1 => @sizeOf(T),

                    // For multi-field packed and extern unions,
                    // it is ambiguous whether the unions's "value"
                    // refers to its bit pattern or the field
                    // it was initialized with.
                    // For multi-field untagged auto unions,
                    // since the active field isn't distinguishable
                    // from the byte pattern, multiple values
                    // are capable of having the same byte
                    // representation, so we always return false.
                    else => return false,
                };
            };

            inline for (info.fields) |field| {
                if (field.type == noreturn) {
                    // "noreturn" fields occupy 0 bytes,
                    // so they are acceptable as long as
                    // the payload is expected to be 0 bytes.
                    if (payload_size > 0) {
                        return false;
                    }
                } else {
                    if (@sizeOf(field.type) != payload_size) {
                        return false;
                    } else if (!hasUniqueRepresentation(field.type)) {
                        return false;
                    }
                }
            }

            return true;
        },

        // If an array has a sentinel, then it is ambiguous whether
        // the sentinel is included in the "value."
        .array => |info| info.len == 0 or hasUniqueRepresentation(info.child),

        .vector => |info| info.len == 0 or switch (@typeInfo(info.child)) {
            // For vectors of trivially packable types, iff the ABI bit size
            // of T is equal to the logical bit size of all of the elements,
            // then the elements must be packed together with no padding.
            .int, .float, .bool => @sizeOf(T) * 8 == @bitSizeOf(info.child) * info.len,

            // For vectors of types with a unique representation,
            // we can apply the same logic but with byte sizes.
            else => hasUniqueRepresentation(info.child) and
                @sizeOf(T) == @sizeOf(info.child) * info.len,
        },

        // "true" may be represented by multiple different byte patterns.
        // TODO: In some ABIs, a bool is always either 0 or 1,
        // and other values are not allowed. If it is possible to check this,
        // then this could enable some optimization.
        .bool => false,

        // Noreturn cannot have a unique representation
        // because it cannot be represented in the first place.
        .noreturn => false,

        // In practice, this is often true,
        // but there is no practical way to
        // guarantee this.
        .error_union => false,

        // By definition of an opaque type, this is impossible to know
        .@"opaque" => false,

        // These types are comptime-only
        .type,
        .@"fn",
        .comptime_int,
        .comptime_float,
        .enum_literal,
        .null,
        .undefined,
        => false,

        // Async types are not currently supported,
        .frame, .@"anyframe" => unreachable,
    };
}

test "hasUniqueRepresentation unions" {
    const TestUnion2 = extern union {
        a: u32,
        b: u16,
    };

    try testing.expect(!hasUniqueRepresentation(TestUnion2));

    const TestUnion3 = union {
        a: u32,
        b: u16,
    };

    try testing.expect(!hasUniqueRepresentation(TestUnion3));

    const TestUnion4 = union(enum) {
        a: u32,
        b: u16,
    };

    try testing.expect(!hasUniqueRepresentation(TestUnion4));

    const TestUnion5 = union(enum) {
        a: u32,
    };

    try testing.expect(hasUniqueRepresentation(TestUnion5));
}

test "hasUniqueRepresentation ints" {
    inline for ([_]type{ i0, u8, i16, u32, i64, i128 }) |T| {
        try testing.expect(hasUniqueRepresentation(T));
    }

    inline for ([_]type{ i1, u9, i17, u33 }) |T| {
        try testing.expect(!hasUniqueRepresentation(T));
    }
}

test "hasUniqueRepresentation structs" {
    const TestStruct1 = struct {
        a: u32,
        b: u32,
    };

    try testing.expect(hasUniqueRepresentation(TestStruct1));

    const TestStruct2 = struct {
        a: u32,
        b: u16,
    };

    try testing.expect(!hasUniqueRepresentation(TestStruct2));

    const TestStruct3 = struct {
        a: u32,
        b: u32,
    };

    try testing.expect(hasUniqueRepresentation(TestStruct3));

    const TestStruct4 = packed struct(u8) {
        @"0": bool,
        @"1": bool,
        @"2": bool,
        @"3": bool,
        @"4": bool,
        @"5": bool,
        @"6": bool,
        @"7": bool,
    };

    try testing.expect(hasUniqueRepresentation(TestStruct4));
}

test "hasUniqueRepresentation comptime fields" {
    const StructWithComptimeFields = struct {
        comptime should_be_ignored: u27 = 42,
        comptime should_also_be_ignored: [*:0]const u8 = "hope you're having a good day :)",
        field: u32,
    };
    try testing.expect(hasUniqueRepresentation(StructWithComptimeFields));
}

test "hasUniqueRepresentation pointers" {
    try testing.expect(hasUniqueRepresentation(*u8));

    try testing.expect(hasUniqueRepresentation(?*u8));
    try testing.expect(hasUniqueRepresentation(*allowzero u8));
    try testing.expect(hasUniqueRepresentation([*c]u8));

    try testing.expect(!hasUniqueRepresentation(?*allowzero u8));
    try testing.expect(!hasUniqueRepresentation(?[*c]u8));

    try testing.expect(!hasUniqueRepresentation(*const type));
    try testing.expect(hasUniqueRepresentation(*const fn () void));
}

test "hasUniqueRepresentation vectors" {
    try testing.expect(hasUniqueRepresentation(@Vector(std.simd.suggestVectorLength(u8) orelse 1, u8)));

    if (@sizeOf(@Vector(3, u8)) == 3) {
        try testing.expect(hasUniqueRepresentation(@Vector(3, u8)));
    } else {
        try testing.expect(!hasUniqueRepresentation(@Vector(3, u8)));
    }

    if (@sizeOf(@Vector(8, bool)) == 1) {
        try testing.expect(hasUniqueRepresentation(@Vector(8, bool)));
    } else {
        try testing.expect(!hasUniqueRepresentation(@Vector(8, bool)));
    }
    try testing.expect(!hasUniqueRepresentation(@Vector(9, bool)));
}

test hasUniqueRepresentation {
    try testing.expect(hasUniqueRepresentation(u32));
    try testing.expect(!hasUniqueRepresentation(u18));

    const StructWithNoPadding = extern struct {
        a: u32,
        b: u32,
    };

    try testing.expect(hasUniqueRepresentation(StructWithNoPadding));

    const StructWithPadding = extern struct {
        a: u8 align(4),
        b: u32,
    };

    try testing.expect(!hasUniqueRepresentation(StructWithPadding));
}
