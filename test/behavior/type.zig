const std = @import("std");
const builtin = @import("builtin");
const Type = std.builtin.Type;
const testing = std.testing;
const assert = std.debug.assert;

test "Type.Int" {
    try testing.expect(u1 == @Int(.unsigned, 1));
    try testing.expect(i1 == @Int(.signed, 1));
    try testing.expect(u8 == @Int(.unsigned, 8));
    try testing.expect(i8 == @Int(.signed, 8));
    try testing.expect(u64 == @Int(.unsigned, 64));
    try testing.expect(i64 == @Int(.signed, 64));
}

test "Type.Pointer" {
    inline for (&[_]type{
        // One Value Pointer Types
        *u8,                               *const u8,
        *volatile u8,                      *const volatile u8,
        *align(4) u8,                      *align(4) const u8,
        *align(4) volatile u8,             *align(4) const volatile u8,
        *align(8) u8,                      *align(8) const u8,
        *align(8) volatile u8,             *align(8) const volatile u8,
        *allowzero u8,                     *allowzero const u8,
        *allowzero volatile u8,            *allowzero const volatile u8,
        *allowzero align(4) u8,            *allowzero align(4) const u8,
        *allowzero align(4) volatile u8,   *allowzero align(4) const volatile u8,
        // Many Values Pointer Types
        [*]u8,                             [*]const u8,
        [*]volatile u8,                    [*]const volatile u8,
        [*]align(4) u8,                    [*]align(4) const u8,
        [*]align(4) volatile u8,           [*]align(4) const volatile u8,
        [*]align(8) u8,                    [*]align(8) const u8,
        [*]align(8) volatile u8,           [*]align(8) const volatile u8,
        [*]allowzero u8,                   [*]allowzero const u8,
        [*]allowzero volatile u8,          [*]allowzero const volatile u8,
        [*]allowzero align(4) u8,          [*]allowzero align(4) const u8,
        [*]allowzero align(4) volatile u8, [*]allowzero align(4) const volatile u8,
        // Slice Types
        []u8,                              []const u8,
        []volatile u8,                     []const volatile u8,
        []align(4) u8,                     []align(4) const u8,
        []align(4) volatile u8,            []align(4) const volatile u8,
        []align(8) u8,                     []align(8) const u8,
        []align(8) volatile u8,            []align(8) const volatile u8,
        []allowzero u8,                    []allowzero const u8,
        []allowzero volatile u8,           []allowzero const volatile u8,
        []allowzero align(4) u8,           []allowzero align(4) const u8,
        []allowzero align(4) volatile u8,  []allowzero align(4) const volatile u8,
        // C Pointer Types
        [*c]u8,                            [*c]const u8,
        [*c]volatile u8,                   [*c]const volatile u8,
        [*c]align(4) u8,                   [*c]align(4) const u8,
        [*c]align(4) volatile u8,          [*c]align(4) const volatile u8,
        [*c]align(8) u8,                   [*c]align(8) const u8,
        [*c]align(8) volatile u8,          [*c]align(8) const volatile u8,
    }) |testType| {
        try testing.expect(testType == @Pointer(@typeInfo(testType).pointer));
    }
}

test "@Pointer create slice with null sentinel" {
    const Slice = @Pointer(.{
        .size = .slice,
        .is_const = true,
        .is_volatile = false,
        .is_allowzero = false,
        .alignment = 8,
        .address_space = .generic,
        .child = *i32,
        .sentinel_ptr = null,
    });
    try testing.expect(Slice == []align(8) const *i32);
}

test "@Pointer picks up the sentinel value from Type" {
    inline for (&[_]type{
        [*:0]u8,                             [*:0]const u8,
        [*:0]volatile u8,                    [*:0]const volatile u8,
        [*:0]align(4) u8,                    [*:0]align(4) const u8,
        [*:0]align(4) volatile u8,           [*:0]align(4) const volatile u8,
        [*:0]align(8) u8,                    [*:0]align(8) const u8,
        [*:0]align(8) volatile u8,           [*:0]align(8) const volatile u8,
        [*:0]allowzero u8,                   [*:0]allowzero const u8,
        [*:0]allowzero volatile u8,          [*:0]allowzero const volatile u8,
        [*:0]allowzero align(4) u8,          [*:0]allowzero align(4) const u8,
        [*:0]allowzero align(4) volatile u8, [*:0]allowzero align(4) const volatile u8,
        [*:5]allowzero align(4) volatile u8, [*:5]allowzero align(4) const volatile u8,
        [:0]u8,                              [:0]const u8,
        [:0]volatile u8,                     [:0]const volatile u8,
        [:0]align(4) u8,                     [:0]align(4) const u8,
        [:0]align(4) volatile u8,            [:0]align(4) const volatile u8,
        [:0]align(8) u8,                     [:0]align(8) const u8,
        [:0]align(8) volatile u8,            [:0]align(8) const volatile u8,
        [:0]allowzero u8,                    [:0]allowzero const u8,
        [:0]allowzero volatile u8,           [:0]allowzero const volatile u8,
        [:0]allowzero align(4) u8,           [:0]allowzero align(4) const u8,
        [:0]allowzero align(4) volatile u8,  [:0]allowzero align(4) const volatile u8,
        [:4]allowzero align(4) volatile u8,  [:4]allowzero align(4) const volatile u8,
    }) |TestType| {
        try testing.expect(TestType == @Pointer(@typeInfo(TestType).pointer));
    }
}

fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "Type.Struct" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const A = @Struct(@typeInfo(struct { x: u8, y: u32 }).@"struct");
    const infoA = @typeInfo(A).@"struct";
    try testing.expectEqual(Type.ContainerLayout.auto, infoA.layout);
    try testing.expectEqualSlices(u8, "x", infoA.fields[0].name);
    try testing.expectEqual(u8, infoA.fields[0].type);
    try testing.expectEqual(@as(?*const anyopaque, null), infoA.fields[0].default_value_ptr);
    try testing.expectEqualSlices(u8, "y", infoA.fields[1].name);
    try testing.expectEqual(u32, infoA.fields[1].type);
    try testing.expectEqual(@as(?*const anyopaque, null), infoA.fields[1].default_value_ptr);
    try testing.expectEqualSlices(Type.Declaration, &.{}, infoA.decls);
    try testing.expectEqual(@as(bool, false), infoA.is_tuple);

    var a = A{ .x = 0, .y = 1 };
    try testing.expectEqual(@as(u8, 0), a.x);
    try testing.expectEqual(@as(u32, 1), a.y);
    a.y += 1;
    try testing.expectEqual(@as(u32, 2), a.y);

    const B = @Struct(@typeInfo(extern struct { x: u8, y: u32 = 5 }).@"struct");
    const infoB = @typeInfo(B).@"struct";
    try testing.expectEqual(Type.ContainerLayout.@"extern", infoB.layout);
    try testing.expectEqualSlices(u8, "x", infoB.fields[0].name);
    try testing.expectEqual(u8, infoB.fields[0].type);
    try testing.expectEqual(@as(?*const anyopaque, null), infoB.fields[0].default_value_ptr);
    try testing.expectEqualSlices(u8, "y", infoB.fields[1].name);
    try testing.expectEqual(u32, infoB.fields[1].type);
    try testing.expectEqual(@as(u32, 5), infoB.fields[1].defaultValue().?);
    try testing.expectEqual(@as(usize, 0), infoB.decls.len);
    try testing.expectEqual(@as(bool, false), infoB.is_tuple);

    const C = @Struct(@typeInfo(packed struct { x: u8 = 3, y: u32 = 5 }).@"struct");
    const infoC = @typeInfo(C).@"struct";
    try testing.expectEqual(Type.ContainerLayout.@"packed", infoC.layout);
    try testing.expectEqualSlices(u8, "x", infoC.fields[0].name);
    try testing.expectEqual(u8, infoC.fields[0].type);
    try testing.expectEqual(@as(u8, 3), infoC.fields[0].defaultValue().?);
    try testing.expectEqualSlices(u8, "y", infoC.fields[1].name);
    try testing.expectEqual(u32, infoC.fields[1].type);
    try testing.expectEqual(@as(u32, 5), infoC.fields[1].defaultValue().?);
    try testing.expectEqual(@as(usize, 0), infoC.decls.len);
    try testing.expectEqual(@as(bool, false), infoC.is_tuple);

    // anon structs
    const D = @Struct(@typeInfo(@TypeOf(.{ .x = 3, .y = 5 })).@"struct");
    const infoD = @typeInfo(D).@"struct";
    try testing.expectEqual(Type.ContainerLayout.auto, infoD.layout);
    try testing.expectEqualSlices(u8, "x", infoD.fields[0].name);
    try testing.expectEqual(comptime_int, infoD.fields[0].type);
    try testing.expectEqual(@as(comptime_int, 3), infoD.fields[0].defaultValue().?);
    try testing.expectEqualSlices(u8, "y", infoD.fields[1].name);
    try testing.expectEqual(comptime_int, infoD.fields[1].type);
    try testing.expectEqual(@as(comptime_int, 5), infoD.fields[1].defaultValue().?);
    try testing.expectEqual(@as(usize, 0), infoD.decls.len);
    try testing.expectEqual(@as(bool, false), infoD.is_tuple);

    // tuples
    const E = @Struct(@typeInfo(@TypeOf(.{ 1, 2 })).@"struct");
    const infoE = @typeInfo(E).@"struct";
    try testing.expectEqual(Type.ContainerLayout.auto, infoE.layout);
    try testing.expectEqualSlices(u8, "0", infoE.fields[0].name);
    try testing.expectEqual(comptime_int, infoE.fields[0].type);
    try testing.expectEqual(@as(comptime_int, 1), infoE.fields[0].defaultValue().?);
    try testing.expectEqualSlices(u8, "1", infoE.fields[1].name);
    try testing.expectEqual(comptime_int, infoE.fields[1].type);
    try testing.expectEqual(@as(comptime_int, 2), infoE.fields[1].defaultValue().?);
    try testing.expectEqual(@as(usize, 0), infoE.decls.len);
    try testing.expectEqual(@as(bool, true), infoE.is_tuple);

    // empty struct
    const F = @Struct(@typeInfo(struct {}).@"struct");
    const infoF = @typeInfo(F).@"struct";
    try testing.expectEqual(Type.ContainerLayout.auto, infoF.layout);
    try testing.expect(infoF.fields.len == 0);
    try testing.expectEqual(@as(bool, false), infoF.is_tuple);

    // empty tuple
    const G = @Struct(@typeInfo(@TypeOf(.{})).@"struct");
    const infoG = @typeInfo(G).@"struct";
    try testing.expectEqual(Type.ContainerLayout.auto, infoG.layout);
    try testing.expect(infoG.fields.len == 0);
    try testing.expectEqual(@as(bool, true), infoG.is_tuple);
}

test "Type.Enum" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const Foo = @Enum(.{
        .tag_type = u8,
        .fields = &.{
            .{ .name = "a", .value = 1 },
            .{ .name = "b", .value = 5 },
        },
        .decls = &.{},
        .is_exhaustive = true,
    });
    try testing.expectEqual(true, @typeInfo(Foo).@"enum".is_exhaustive);
    try testing.expectEqual(@as(u8, 1), @intFromEnum(Foo.a));
    try testing.expectEqual(@as(u8, 5), @intFromEnum(Foo.b));
    const Bar = @Enum(.{
        .tag_type = u32,
        .fields = &.{
            .{ .name = "a", .value = 1 },
            .{ .name = "b", .value = 5 },
        },
        .decls = &.{},
        .is_exhaustive = false,
    });
    try testing.expectEqual(false, @typeInfo(Bar).@"enum".is_exhaustive);
    try testing.expectEqual(@as(u32, 1), @intFromEnum(Bar.a));
    try testing.expectEqual(@as(u32, 5), @intFromEnum(Bar.b));
    try testing.expectEqual(@as(u32, 6), @intFromEnum(@as(Bar, @enumFromInt(6))));

    { // from https://github.com/ziglang/zig/issues/19985
        { // enum with single field can be initialized.
            const E = @Enum(.{
                .tag_type = u0,
                .is_exhaustive = true,
                .fields = &.{.{ .name = "foo", .value = 0 }},
                .decls = &.{},
            });
            const s: struct { E } = .{.foo};
            try testing.expectEqual(.foo, s[0]);
        }

        { // meta.FieldEnum() with single field
            const S = struct { foo: u8 };
            const Fe = std.meta.FieldEnum(S);
            var s: S = undefined;
            const fe = std.meta.stringToEnum(Fe, "foo") orelse return error.InvalidField;
            switch (fe) {
                inline else => |tag| {
                    @field(s, @tagName(tag)) = 42;
                },
            }
            try testing.expectEqual(42, s.foo);
        }
    }
}

test "Type.Union" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const Untagged = @Union(.{
        .layout = .@"extern",
        .tag_type = null,
        .fields = &.{
            .{ .name = "int", .type = i32, .alignment = @alignOf(f32) },
            .{ .name = "float", .type = f32, .alignment = @alignOf(f32) },
        },
        .decls = &.{},
    });
    var untagged = Untagged{ .int = 1 };
    untagged.float = 2.0;
    untagged.int = 3;
    try testing.expectEqual(@as(i32, 3), untagged.int);

    const PackedUntagged = @Union(.{
        .layout = .@"packed",
        .tag_type = null,
        .fields = &.{
            .{ .name = "signed", .type = i32, .alignment = @alignOf(i32) },
            .{ .name = "unsigned", .type = u32, .alignment = @alignOf(u32) },
        },
        .decls = &.{},
    });
    var packed_untagged: PackedUntagged = .{ .signed = -1 };
    _ = &packed_untagged;
    try testing.expectEqual(@as(i32, -1), packed_untagged.signed);
    try testing.expectEqual(~@as(u32, 0), packed_untagged.unsigned);

    const Tag = @Enum(.{
        .tag_type = u1,
        .fields = &.{
            .{ .name = "signed", .value = 0 },
            .{ .name = "unsigned", .value = 1 },
        },
        .decls = &.{},
        .is_exhaustive = true,
    });
    const Tagged = @Union(.{
        .layout = .auto,
        .tag_type = Tag,
        .fields = &.{
            .{ .name = "signed", .type = i32, .alignment = @alignOf(i32) },
            .{ .name = "unsigned", .type = u32, .alignment = @alignOf(u32) },
        },
        .decls = &.{},
    });
    var tagged = Tagged{ .signed = -1 };
    try testing.expectEqual(Tag.signed, @as(Tag, tagged));
    tagged = .{ .unsigned = 1 };
    try testing.expectEqual(Tag.unsigned, @as(Tag, tagged));
}

test "Type.Union from Type.Enum" {
    const Tag = @Enum(.{
        .tag_type = u0,
        .fields = &.{
            .{ .name = "working_as_expected", .value = 0 },
        },
        .decls = &.{},
        .is_exhaustive = true,
    });
    const T = @Union(.{
        .layout = .auto,
        .tag_type = Tag,
        .fields = &.{
            .{ .name = "working_as_expected", .type = u32, .alignment = @alignOf(u32) },
        },
        .decls = &.{},
    });
    _ = @typeInfo(T).@"union";
}

test "Type.Union from regular enum" {
    const E = enum { working_as_expected };
    const T = @Union(.{
        .layout = .auto,
        .tag_type = E,
        .fields = &.{
            .{ .name = "working_as_expected", .type = u32, .alignment = @alignOf(u32) },
        },
        .decls = &.{},
    });
    _ = @typeInfo(T).@"union";
}

test "Type.Union from empty regular enum" {
    const E = enum {};
    const U = @Union(.{
        .layout = .auto,
        .tag_type = E,
        .fields = &.{},
        .decls = &.{},
    });
    try testing.expectEqual(@sizeOf(U), 0);
}

test "Type.Union from empty Type.Enum" {
    const E = @Enum(.{
        .tag_type = u0,
        .fields = &.{},
        .decls = &.{},
        .is_exhaustive = true,
    });
    const U = @Union(.{
        .layout = .auto,
        .tag_type = E,
        .fields = &.{},
        .decls = &.{},
    });
    try testing.expectEqual(@sizeOf(U), 0);
}

test "reified struct field name from optional payload" {
    comptime {
        const m_name: ?[1:0]u8 = "a".*;
        if (m_name) |*name| {
            const T = @Struct(.{
                .layout = .auto,
                .fields = &.{.{
                    .name = name,
                    .type = u8,
                    .default_value_ptr = null,
                    .is_comptime = false,
                    .alignment = 1,
                }},
                .decls = &.{},
                .is_tuple = false,
            });
            const t: T = .{ .a = 123 };
            try std.testing.expect(t.a == 123);
        }
    }
}

test "reified union uses @alignOf" {
    const S = struct {
        fn CreateUnion(comptime T: type) type {
            return @Union(.{
                .layout = .auto,
                .tag_type = null,
                .fields = &[_]std.builtin.Type.UnionField{
                    .{
                        .name = "field",
                        .type = T,
                        .alignment = @alignOf(T),
                    },
                },
                .decls = &.{},
            });
        }
    };
    _ = S.CreateUnion(struct {});
}

test "reified struct uses @alignOf" {
    const S = struct {
        fn NamespacedGlobals(comptime modules: anytype) type {
            return @Struct(.{
                .layout = .auto,
                .is_tuple = false,
                .fields = &.{
                    .{
                        .name = "globals",
                        .type = modules.mach.globals,
                        .default_value_ptr = null,
                        .is_comptime = false,
                        .alignment = @alignOf(modules.mach.globals),
                    },
                },
                .decls = &.{},
            });
        }
    };
    _ = S.NamespacedGlobals(.{
        .mach = .{
            .globals = struct {},
        },
    });
}

test "empty struct assigned to reified struct field" {
    const S = struct {
        fn NamespacedComponents(comptime modules: anytype) type {
            return @Struct(.{
                .layout = .auto,
                .is_tuple = false,
                .fields = &.{.{
                    .name = "components",
                    .type = @TypeOf(modules.components),
                    .default_value_ptr = null,
                    .is_comptime = false,
                    .alignment = @alignOf(@TypeOf(modules.components)),
                }},
                .decls = &.{},
            });
        }

        fn namespacedComponents(comptime modules: anytype) NamespacedComponents(modules) {
            var x: NamespacedComponents(modules) = undefined;
            x.components = modules.components;
            return x;
        }
    };
    _ = S.namespacedComponents(.{
        .components = .{
            .location = struct {},
        },
    });
}

test "struct field names sliced at comptime from larger string" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const text =
        \\f1
        \\f2
        \\f3
    ;
    comptime {
        var fields: []const Type.StructField = &[0]Type.StructField{};

        var it = std.mem.tokenizeScalar(u8, text, '\n');
        while (it.next()) |name| {
            fields = fields ++ &[_]Type.StructField{.{
                .alignment = 0,
                .name = name ++ "",
                .type = usize,
                .default_value_ptr = null,
                .is_comptime = false,
            }};
        }

        const T = @Struct(.{
            .layout = .auto,
            .is_tuple = false,
            .fields = fields,
            .decls = &.{},
        });

        const gen_fields = @typeInfo(T).@"struct".fields;
        try testing.expectEqual(3, gen_fields.len);
        try testing.expectEqualStrings("f1", gen_fields[0].name);
        try testing.expectEqualStrings("f2", gen_fields[1].name);
        try testing.expectEqualStrings("f3", gen_fields[2].name);
    }
}

test "matching captures causes opaque equivalence" {
    const S = struct {
        fn UnsignedId(comptime I: type) type {
            const U = @Int(.unsigned, @typeInfo(I).int.bits);
            return opaque {
                fn id(x: U) U {
                    return x;
                }
            };
        }
    };

    comptime assert(S.UnsignedId(u8) == S.UnsignedId(i8));
    comptime assert(S.UnsignedId(u16) == S.UnsignedId(i16));
    comptime assert(S.UnsignedId(u8) != S.UnsignedId(u16));

    const a = S.UnsignedId(u8).id(123);
    const b = S.UnsignedId(i8).id(123);
    comptime assert(@TypeOf(a) == @TypeOf(b));
    try testing.expect(a == b);
}

test "reify enum where fields refers to part of array" {
    const fields: [3]std.builtin.Type.EnumField = .{
        .{ .name = "foo", .value = 0 },
        .{ .name = "bar", .value = 1 },
        undefined,
    };
    const E = @Enum(.{
        .tag_type = u8,
        .fields = fields[0..2],
        .decls = &.{},
        .is_exhaustive = true,
    });
    var a: E = undefined;
    var b: E = undefined;
    a = .foo;
    b = .bar;
    try testing.expect(a == .foo);
    try testing.expect(b == .bar);
    try testing.expect(a != b);
}

test "undefined type value" {
    const S = struct {
        const undef_type: type = undefined;
    };
    comptime assert(@TypeOf(S.undef_type) == type);
}
