const std = @import("std");
const builtin = @import("builtin");
const Type = std.builtin.Type;
const testing = std.testing;

fn testTypes(comptime types: []const type) !void {
    inline for (types) |testType| {
        try testing.expect(testType == @Type(@typeInfo(testType)));
    }
}

test "Type.MetaType" {
    try testing.expect(type == @Type(.{ .Type = {} }));
    try testTypes(&[_]type{type});
}

test "Type.Void" {
    try testing.expect(void == @Type(.{ .Void = {} }));
    try testTypes(&[_]type{void});
}

test "Type.Bool" {
    try testing.expect(bool == @Type(.{ .Bool = {} }));
    try testTypes(&[_]type{bool});
}

test "Type.NoReturn" {
    try testing.expect(noreturn == @Type(.{ .NoReturn = {} }));
    try testTypes(&[_]type{noreturn});
}

test "Type.Int" {
    try testing.expect(u1 == @Type(.{ .Int = .{ .signedness = .unsigned, .bits = 1 } }));
    try testing.expect(i1 == @Type(.{ .Int = .{ .signedness = .signed, .bits = 1 } }));
    try testing.expect(u8 == @Type(.{ .Int = .{ .signedness = .unsigned, .bits = 8 } }));
    try testing.expect(i8 == @Type(.{ .Int = .{ .signedness = .signed, .bits = 8 } }));
    try testing.expect(u64 == @Type(.{ .Int = .{ .signedness = .unsigned, .bits = 64 } }));
    try testing.expect(i64 == @Type(.{ .Int = .{ .signedness = .signed, .bits = 64 } }));
    try testTypes(&[_]type{ u8, u32, i64 });
}

test "Type.ComptimeFloat" {
    try testTypes(&[_]type{comptime_float});
}
test "Type.ComptimeInt" {
    try testTypes(&[_]type{comptime_int});
}
test "Type.Undefined" {
    try testTypes(&[_]type{@TypeOf(undefined)});
}
test "Type.Null" {
    try testTypes(&[_]type{@TypeOf(null)});
}

test "Type.EnumLiteral" {
    try testTypes(&[_]type{
        @TypeOf(.Dummy),
    });
}

test "Type.Pointer" {
    try testTypes(&[_]type{
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
    });
}

test "Type.Float" {
    try testing.expect(f16 == @Type(.{ .Float = .{ .bits = 16 } }));
    try testing.expect(f32 == @Type(.{ .Float = .{ .bits = 32 } }));
    try testing.expect(f64 == @Type(.{ .Float = .{ .bits = 64 } }));
    try testing.expect(f80 == @Type(.{ .Float = .{ .bits = 80 } }));
    try testing.expect(f128 == @Type(.{ .Float = .{ .bits = 128 } }));
    try testTypes(&[_]type{ f16, f32, f64, f80, f128 });
}

test "Type.Array" {
    try testing.expect([123]u8 == @Type(.{
        .Array = .{
            .len = 123,
            .child = u8,
            .sentinel = null,
        },
    }));
    try testing.expect([2]u32 == @Type(.{
        .Array = .{
            .len = 2,
            .child = u32,
            .sentinel = null,
        },
    }));
    try testing.expect([2:0]u32 == @Type(.{
        .Array = .{
            .len = 2,
            .child = u32,
            .sentinel = &@as(u32, 0),
        },
    }));
    try testTypes(&[_]type{ [1]u8, [30]usize, [7]bool });
}

test "@Type create slice with null sentinel" {
    const Slice = @Type(.{
        .Pointer = .{
            .size = .Slice,
            .is_const = true,
            .is_volatile = false,
            .is_allowzero = false,
            .alignment = 8,
            .address_space = .generic,
            .child = *i32,
            .sentinel = null,
        },
    });
    try testing.expect(Slice == []align(8) const *i32);
}

test "@Type picks up the sentinel value from Type" {
    try testTypes(&[_]type{
        [11:0]u8,                            [4:10]u8,
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
    });
}

test "Type.Optional" {
    try testTypes(&[_]type{
        ?u8,
        ?*u8,
        ?[]u8,
        ?[*]u8,
        ?[*c]u8,
    });
}

test "Type.ErrorUnion" {
    try testTypes(&[_]type{
        error{}!void,
        error{Error}!void,
    });
}

test "Type.Opaque" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const Opaque = @Type(.{
        .Opaque = .{
            .decls = &.{},
        },
    });
    try testing.expect(Opaque != opaque {});
    try testing.expectEqualSlices(
        Type.Declaration,
        &.{},
        @typeInfo(Opaque).Opaque.decls,
    );
}

test "Type.Vector" {
    try testTypes(&[_]type{
        @Vector(0, u8),
        @Vector(4, u8),
        @Vector(8, *u8),
        @Vector(0, u8),
        @Vector(4, u8),
        @Vector(8, *u8),
    });
}

test "Type.AnyFrame" {
    if (builtin.zig_backend != .stage1) {
        // https://github.com/ziglang/zig/issues/6025
        return error.SkipZigTest;
    }

    try testTypes(&[_]type{
        anyframe,
        anyframe->u8,
        anyframe->anyframe->u8,
    });
}

fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "Type.ErrorSet" {
    try testing.expect(@Type(.{ .ErrorSet = null }) == anyerror);

    // error sets don't compare equal so just check if they compile
    _ = @Type(@typeInfo(error{}));
    _ = @Type(@typeInfo(error{A}));
    _ = @Type(@typeInfo(error{ A, B, C }));
    _ = @Type(.{
        .ErrorSet = &[_]Type.Error{
            .{ .name = "A" },
            .{ .name = "B" },
            .{ .name = "C" },
        },
    });
    _ = @Type(.{
        .ErrorSet = &.{
            .{ .name = "C" },
            .{ .name = "B" },
            .{ .name = "A" },
        },
    });
}

test "Type.Struct" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const A = @Type(@typeInfo(struct { x: u8, y: u32 }));
    const infoA = @typeInfo(A).Struct;
    try testing.expectEqual(Type.ContainerLayout.Auto, infoA.layout);
    try testing.expectEqualSlices(u8, "x", infoA.fields[0].name);
    try testing.expectEqual(u8, infoA.fields[0].field_type);
    try testing.expectEqual(@as(?*const anyopaque, null), infoA.fields[0].default_value);
    try testing.expectEqualSlices(u8, "y", infoA.fields[1].name);
    try testing.expectEqual(u32, infoA.fields[1].field_type);
    try testing.expectEqual(@as(?*const anyopaque, null), infoA.fields[1].default_value);
    try testing.expectEqualSlices(Type.Declaration, &.{}, infoA.decls);
    try testing.expectEqual(@as(bool, false), infoA.is_tuple);

    var a = A{ .x = 0, .y = 1 };
    try testing.expectEqual(@as(u8, 0), a.x);
    try testing.expectEqual(@as(u32, 1), a.y);
    a.y += 1;
    try testing.expectEqual(@as(u32, 2), a.y);

    const B = @Type(@typeInfo(extern struct { x: u8, y: u32 = 5 }));
    const infoB = @typeInfo(B).Struct;
    try testing.expectEqual(Type.ContainerLayout.Extern, infoB.layout);
    try testing.expectEqualSlices(u8, "x", infoB.fields[0].name);
    try testing.expectEqual(u8, infoB.fields[0].field_type);
    try testing.expectEqual(@as(?*const anyopaque, null), infoB.fields[0].default_value);
    try testing.expectEqualSlices(u8, "y", infoB.fields[1].name);
    try testing.expectEqual(u32, infoB.fields[1].field_type);
    try testing.expectEqual(@as(u32, 5), @ptrCast(*const u32, infoB.fields[1].default_value.?).*);
    try testing.expectEqual(@as(usize, 0), infoB.decls.len);
    try testing.expectEqual(@as(bool, false), infoB.is_tuple);

    const C = @Type(@typeInfo(packed struct { x: u8 = 3, y: u32 = 5 }));
    const infoC = @typeInfo(C).Struct;
    try testing.expectEqual(Type.ContainerLayout.Packed, infoC.layout);
    try testing.expectEqualSlices(u8, "x", infoC.fields[0].name);
    try testing.expectEqual(u8, infoC.fields[0].field_type);
    try testing.expectEqual(@as(u8, 3), @ptrCast(*const u8, infoC.fields[0].default_value.?).*);
    try testing.expectEqualSlices(u8, "y", infoC.fields[1].name);
    try testing.expectEqual(u32, infoC.fields[1].field_type);
    try testing.expectEqual(@as(u32, 5), @ptrCast(*const u32, infoC.fields[1].default_value.?).*);
    try testing.expectEqual(@as(usize, 0), infoC.decls.len);
    try testing.expectEqual(@as(bool, false), infoC.is_tuple);

    // anon structs
    const D = @Type(@typeInfo(@TypeOf(.{ .x = 3, .y = 5 })));
    const infoD = @typeInfo(D).Struct;
    try testing.expectEqual(Type.ContainerLayout.Auto, infoD.layout);
    try testing.expectEqualSlices(u8, "x", infoD.fields[0].name);
    try testing.expectEqual(comptime_int, infoD.fields[0].field_type);
    try testing.expectEqual(@as(comptime_int, 3), @ptrCast(*const comptime_int, infoD.fields[0].default_value.?).*);
    try testing.expectEqualSlices(u8, "y", infoD.fields[1].name);
    try testing.expectEqual(comptime_int, infoD.fields[1].field_type);
    try testing.expectEqual(@as(comptime_int, 5), @ptrCast(*const comptime_int, infoD.fields[1].default_value.?).*);
    try testing.expectEqual(@as(usize, 0), infoD.decls.len);
    try testing.expectEqual(@as(bool, false), infoD.is_tuple);

    // tuples
    const E = @Type(@typeInfo(@TypeOf(.{ 1, 2 })));
    const infoE = @typeInfo(E).Struct;
    try testing.expectEqual(Type.ContainerLayout.Auto, infoE.layout);
    try testing.expectEqualSlices(u8, "0", infoE.fields[0].name);
    try testing.expectEqual(comptime_int, infoE.fields[0].field_type);
    try testing.expectEqual(@as(comptime_int, 1), @ptrCast(*const comptime_int, infoE.fields[0].default_value.?).*);
    try testing.expectEqualSlices(u8, "1", infoE.fields[1].name);
    try testing.expectEqual(comptime_int, infoE.fields[1].field_type);
    try testing.expectEqual(@as(comptime_int, 2), @ptrCast(*const comptime_int, infoE.fields[1].default_value.?).*);
    try testing.expectEqual(@as(usize, 0), infoE.decls.len);
    try testing.expectEqual(@as(bool, true), infoE.is_tuple);

    // empty struct
    const F = @Type(@typeInfo(struct {}));
    const infoF = @typeInfo(F).Struct;
    try testing.expectEqual(Type.ContainerLayout.Auto, infoF.layout);
    try testing.expect(infoF.fields.len == 0);
    try testing.expectEqual(@as(bool, false), infoF.is_tuple);

    // empty tuple
    const G = @Type(@typeInfo(@TypeOf(.{})));
    const infoG = @typeInfo(G).Struct;
    try testing.expectEqual(Type.ContainerLayout.Auto, infoG.layout);
    try testing.expect(infoG.fields.len == 0);
    try testing.expectEqual(@as(bool, true), infoG.is_tuple);
}

test "Type.Enum" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const Foo = @Type(.{
        .Enum = .{
            .layout = .Auto,
            .tag_type = u8,
            .fields = &.{
                .{ .name = "a", .value = 1 },
                .{ .name = "b", .value = 5 },
            },
            .decls = &.{},
            .is_exhaustive = true,
        },
    });
    try testing.expectEqual(true, @typeInfo(Foo).Enum.is_exhaustive);
    try testing.expectEqual(@as(u8, 1), @enumToInt(Foo.a));
    try testing.expectEqual(@as(u8, 5), @enumToInt(Foo.b));
    const Bar = @Type(.{
        .Enum = .{
            // stage2 only has auto layouts
            .layout = if (builtin.zig_backend == .stage1)
                .Extern
            else
                .Auto,

            .tag_type = u32,
            .fields = &.{
                .{ .name = "a", .value = 1 },
                .{ .name = "b", .value = 5 },
            },
            .decls = &.{},
            .is_exhaustive = false,
        },
    });
    try testing.expectEqual(false, @typeInfo(Bar).Enum.is_exhaustive);
    try testing.expectEqual(@as(u32, 1), @enumToInt(Bar.a));
    try testing.expectEqual(@as(u32, 5), @enumToInt(Bar.b));
    try testing.expectEqual(@as(u32, 6), @enumToInt(@intToEnum(Bar, 6)));
}

test "Type.Union" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const Untagged = @Type(.{
        .Union = .{
            .layout = .Auto,
            .tag_type = null,
            .fields = &.{
                .{ .name = "int", .field_type = i32, .alignment = @alignOf(f32) },
                .{ .name = "float", .field_type = f32, .alignment = @alignOf(f32) },
            },
            .decls = &.{},
        },
    });
    var untagged = Untagged{ .int = 1 };
    untagged.float = 2.0;
    untagged.int = 3;
    try testing.expectEqual(@as(i32, 3), untagged.int);

    const PackedUntagged = @Type(.{
        .Union = .{
            .layout = .Packed,
            .tag_type = null,
            .fields = &.{
                .{ .name = "signed", .field_type = i32, .alignment = @alignOf(i32) },
                .{ .name = "unsigned", .field_type = u32, .alignment = @alignOf(u32) },
            },
            .decls = &.{},
        },
    });
    var packed_untagged = PackedUntagged{ .signed = -1 };
    try testing.expectEqual(@as(i32, -1), packed_untagged.signed);
    try testing.expectEqual(~@as(u32, 0), packed_untagged.unsigned);

    const Tag = @Type(.{
        .Enum = .{
            .layout = .Auto,
            .tag_type = u1,
            .fields = &.{
                .{ .name = "signed", .value = 0 },
                .{ .name = "unsigned", .value = 1 },
            },
            .decls = &.{},
            .is_exhaustive = true,
        },
    });
    const Tagged = @Type(.{
        .Union = .{
            .layout = .Auto,
            .tag_type = Tag,
            .fields = &.{
                .{ .name = "signed", .field_type = i32, .alignment = @alignOf(i32) },
                .{ .name = "unsigned", .field_type = u32, .alignment = @alignOf(u32) },
            },
            .decls = &.{},
        },
    });
    var tagged = Tagged{ .signed = -1 };
    try testing.expectEqual(Tag.signed, tagged);
    tagged = .{ .unsigned = 1 };
    try testing.expectEqual(Tag.unsigned, tagged);
}

test "Type.Union from Type.Enum" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    const Tag = @Type(.{
        .Enum = .{
            .layout = .Auto,
            .tag_type = u0,
            .fields = &.{
                .{ .name = "working_as_expected", .value = 0 },
            },
            .decls = &.{},
            .is_exhaustive = true,
        },
    });
    const T = @Type(.{
        .Union = .{
            .layout = .Auto,
            .tag_type = Tag,
            .fields = &.{
                .{ .name = "working_as_expected", .field_type = u32, .alignment = @alignOf(u32) },
            },
            .decls = &.{},
        },
    });
    _ = T;
    _ = @typeInfo(T).Union;
}

test "Type.Union from regular enum" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    const E = enum { working_as_expected };
    const T = @Type(.{
        .Union = .{
            .layout = .Auto,
            .tag_type = E,
            .fields = &.{
                .{ .name = "working_as_expected", .field_type = u32, .alignment = @alignOf(u32) },
            },
            .decls = &.{},
        },
    });
    _ = T;
    _ = @typeInfo(T).Union;
}
