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
        const ptr = @typeInfo(testType).pointer;
        try testing.expect(testType == @Pointer(ptr.size, .{
            .@"const" = ptr.is_const,
            .@"volatile" = ptr.is_volatile,
            .@"allowzero" = ptr.is_allowzero,
            .@"align" = ptr.alignment,
            .@"addrspace" = ptr.address_space,
        }, ptr.child, ptr.sentinel()));
    }
}

test "@Pointer create slice without sentinel" {
    const Slice = @Pointer(.slice, .{ .@"const" = true, .@"align" = 8 }, ?*i32, null);
    try testing.expect(Slice == []align(8) const ?*i32);
}

test "@Pointer create slice with null sentinel" {
    const Slice = @Pointer(.slice, .{ .@"const" = true, .@"align" = 8 }, ?*i32, @as(?*i32, null));
    try testing.expect(Slice == [:null]align(8) const ?*i32);
}

test "@Pointer on @typeInfo round-trips sentinels" {
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
        const ptr = @typeInfo(TestType).pointer;
        try testing.expect(TestType == @Pointer(ptr.size, .{
            .@"const" = ptr.is_const,
            .@"volatile" = ptr.is_volatile,
            .@"allowzero" = ptr.is_allowzero,
            .@"align" = ptr.alignment,
            .@"addrspace" = ptr.address_space,
        }, ptr.child, ptr.sentinel()));
    }
}

test "Type.Opaque" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv) return error.SkipZigTest;

    const Opaque = opaque {};
    try testing.expect(Opaque != opaque {});
    try testing.expectEqualSlices(
        Type.Declaration,
        &.{},
        @typeInfo(Opaque).@"opaque".decls,
    );
}

fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "Type.Struct" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv) return error.SkipZigTest;

    const A = @Struct(.auto, null, &.{ "x", "y" }, &.{ u8, u32 }, &@splat(.{}));
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

    const B = @Struct(
        .@"extern",
        null,
        &.{ "x", "y" },
        &.{ u8, u32 },
        &.{ .{}, .{ .default_value_ptr = &@as(u32, 5) } },
    );
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

    const C = @Struct(
        .@"packed",
        null,
        &.{ "x", "y" },
        &.{ u8, u32 },
        &.{
            .{ .default_value_ptr = &@as(u8, 3) },
            .{ .default_value_ptr = &@as(u32, 5) },
        },
    );
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

    // empty struct
    const F = @Struct(.auto, null, &.{}, &.{}, &.{});
    const infoF = @typeInfo(F).@"struct";
    try testing.expectEqual(Type.ContainerLayout.auto, infoF.layout);
    try testing.expect(infoF.fields.len == 0);
    try testing.expectEqual(@as(bool, false), infoF.is_tuple);
}

test "Type.Enum" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv) return error.SkipZigTest;

    const Foo = @Enum(u8, .exhaustive, &.{ "a", "b" }, &.{ 1, 5 });
    try testing.expectEqual(true, @typeInfo(Foo).@"enum".is_exhaustive);
    try testing.expectEqual(@as(u8, 1), @intFromEnum(Foo.a));
    try testing.expectEqual(@as(u8, 5), @intFromEnum(Foo.b));
    const Bar = @Enum(u32, .nonexhaustive, &.{ "a", "b" }, &.{ 1, 5 });
    try testing.expectEqual(false, @typeInfo(Bar).@"enum".is_exhaustive);
    try testing.expectEqual(@as(u32, 1), @intFromEnum(Bar.a));
    try testing.expectEqual(@as(u32, 5), @intFromEnum(Bar.b));
    try testing.expectEqual(@as(u32, 6), @intFromEnum(@as(Bar, @enumFromInt(6))));

    { // from https://github.com/ziglang/zig/issues/19985
        { // enum with single field can be initialized.
            const E = @Enum(u0, .exhaustive, &.{"foo"}, &.{0});
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
    if (builtin.zig_backend == .stage2_spirv) return error.SkipZigTest;

    const Untagged = @Union(.@"extern", null, &.{ "int", "float" }, &.{ i32, f32 }, &.{ .{}, .{} });
    var untagged = Untagged{ .int = 1 };
    untagged.float = 2.0;
    untagged.int = 3;
    try testing.expectEqual(@as(i32, 3), untagged.int);

    const PackedUntagged = @Union(.@"packed", null, &.{ "signed", "unsigned" }, &.{ i32, u32 }, &.{ .{}, .{} });
    var packed_untagged: PackedUntagged = .{ .signed = -1 };
    _ = &packed_untagged;
    try testing.expectEqual(@as(i32, -1), packed_untagged.signed);
    try testing.expectEqual(~@as(u32, 0), packed_untagged.unsigned);

    const Tag = @Enum(u1, .exhaustive, &.{ "signed", "unsigned" }, &.{ 0, 1 });
    const Tagged = @Union(.auto, Tag, &.{ "signed", "unsigned" }, &.{ i32, u32 }, &.{ .{}, .{} });
    var tagged = Tagged{ .signed = -1 };
    try testing.expectEqual(Tag.signed, @as(Tag, tagged));
    tagged = .{ .unsigned = 1 };
    try testing.expectEqual(Tag.unsigned, @as(Tag, tagged));
}

test "Type.Union from Type.Enum" {
    const Tag = @Enum(u0, .exhaustive, &.{"working_as_expected"}, &.{0});
    const T = @Union(.auto, Tag, &.{"working_as_expected"}, &.{u32}, &.{.{}});
    _ = @typeInfo(T).@"union";
}

test "Type.Union from regular enum" {
    const E = enum { working_as_expected };
    const T = @Union(.auto, E, &.{"working_as_expected"}, &.{u32}, &.{.{}});
    _ = @typeInfo(T).@"union";
}

test "Type.Union from empty regular enum" {
    const E = enum {};
    const U = @Union(.auto, E, &.{}, &.{}, &.{});
    try testing.expectEqual(@sizeOf(U), 0);
}

test "Type.Union from empty Type.Enum" {
    const E = @Enum(u0, .exhaustive, &.{}, &.{});
    const U = @Union(.auto, E, &.{}, &.{}, &.{});
    try testing.expectEqual(@sizeOf(U), 0);
}

test "Type.Fn" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const some_opaque = opaque {};
    const some_ptr = *some_opaque;

    const A = @Fn(&.{ c_int, some_ptr }, &@splat(.{}), void, .{ .@"callconv" = .c });
    comptime assert(A == fn (c_int, some_ptr) callconv(.c) void);

    const B = @Fn(&.{ c_int, some_ptr, u32 }, &.{ .{}, .{ .@"noalias" = true }, .{} }, u64, .{});
    comptime assert(B == fn (c_int, noalias some_ptr, u32) u64);

    const C = @Fn(&.{?[*]u8}, &.{.{}}, *const anyopaque, .{ .@"callconv" = .c, .varargs = true });
    comptime assert(C == fn (?[*]u8, ...) callconv(.c) *const anyopaque);
}

test "reified struct field name from optional payload" {
    comptime {
        const m_name: ?[1:0]u8 = "a".*;
        if (m_name) |*name| {
            const T = @Struct(.auto, null, &.{name}, &.{u8}, &.{.{}});
            const t: T = .{ .a = 123 };
            try std.testing.expect(t.a == 123);
        }
    }
}

test "reified union uses @alignOf" {
    const S = struct {
        fn CreateUnion(comptime T: type) type {
            return @Union(.auto, null, &.{"field"}, &.{T}, &.{.{}});
        }
    };
    _ = S.CreateUnion(struct {});
}

test "reified struct uses @alignOf" {
    const S = struct {
        fn NamespacedGlobals(comptime modules: anytype) type {
            return @Struct(
                .auto,
                null,
                &.{"globals"},
                &.{modules.mach.globals},
                &.{.{ .@"align" = @alignOf(modules.mach.globals) }},
            );
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
            return @Struct(.auto, null, &.{"components"}, &.{@TypeOf(modules.components)}, &.{.{}});
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
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const text =
        \\f1
        \\f2
        \\f3
    ;
    comptime {
        var field_names: []const []const u8 = &.{};

        var it = std.mem.tokenizeScalar(u8, text, '\n');
        while (it.next()) |name| {
            field_names = field_names ++ @as([]const []const u8, &.{name});
        }

        const T = @Struct(.auto, null, field_names, &@splat(usize), &@splat(.{}));
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
    const field_names: [3][]const u8 = .{ "foo", "bar", undefined };
    const field_values: [3]u8 = .{ undefined, 0, 1 };
    const E = @Enum(u8, .exhaustive, field_names[0..2], field_values[1..3]);
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
