const std = @import("std");
const builtin = @import("builtin");
const Type = std.builtin.Type;
const testing = std.testing;
const assert = std.debug.assert;

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
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    if (true) {
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
    inline for (.{ error{}, error{A}, error{ A, B, C } }) |T| {
        const info = @typeInfo(T);
        const T2 = @Type(info);
        try testing.expect(T == T2);
    }
}

test "Type.Struct" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const A = @Type(@typeInfo(struct { x: u8, y: u32 }));
    const infoA = @typeInfo(A).Struct;
    try testing.expectEqual(Type.ContainerLayout.auto, infoA.layout);
    try testing.expectEqualSlices(u8, "x", infoA.fields[0].name);
    try testing.expectEqual(u8, infoA.fields[0].type);
    try testing.expectEqual(@as(?*const anyopaque, null), infoA.fields[0].default_value);
    try testing.expectEqualSlices(u8, "y", infoA.fields[1].name);
    try testing.expectEqual(u32, infoA.fields[1].type);
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
    try testing.expectEqual(Type.ContainerLayout.@"extern", infoB.layout);
    try testing.expectEqualSlices(u8, "x", infoB.fields[0].name);
    try testing.expectEqual(u8, infoB.fields[0].type);
    try testing.expectEqual(@as(?*const anyopaque, null), infoB.fields[0].default_value);
    try testing.expectEqualSlices(u8, "y", infoB.fields[1].name);
    try testing.expectEqual(u32, infoB.fields[1].type);
    try testing.expectEqual(@as(u32, 5), @as(*align(1) const u32, @ptrCast(infoB.fields[1].default_value.?)).*);
    try testing.expectEqual(@as(usize, 0), infoB.decls.len);
    try testing.expectEqual(@as(bool, false), infoB.is_tuple);

    const C = @Type(@typeInfo(packed struct { x: u8 = 3, y: u32 = 5 }));
    const infoC = @typeInfo(C).Struct;
    try testing.expectEqual(Type.ContainerLayout.@"packed", infoC.layout);
    try testing.expectEqualSlices(u8, "x", infoC.fields[0].name);
    try testing.expectEqual(u8, infoC.fields[0].type);
    try testing.expectEqual(@as(u8, 3), @as(*const u8, @ptrCast(infoC.fields[0].default_value.?)).*);
    try testing.expectEqualSlices(u8, "y", infoC.fields[1].name);
    try testing.expectEqual(u32, infoC.fields[1].type);
    try testing.expectEqual(@as(u32, 5), @as(*align(1) const u32, @ptrCast(infoC.fields[1].default_value.?)).*);
    try testing.expectEqual(@as(usize, 0), infoC.decls.len);
    try testing.expectEqual(@as(bool, false), infoC.is_tuple);

    // anon structs
    const D = @Type(@typeInfo(@TypeOf(.{ .x = 3, .y = 5 })));
    const infoD = @typeInfo(D).Struct;
    try testing.expectEqual(Type.ContainerLayout.auto, infoD.layout);
    try testing.expectEqualSlices(u8, "x", infoD.fields[0].name);
    try testing.expectEqual(comptime_int, infoD.fields[0].type);
    try testing.expectEqual(@as(comptime_int, 3), @as(*const comptime_int, @ptrCast(infoD.fields[0].default_value.?)).*);
    try testing.expectEqualSlices(u8, "y", infoD.fields[1].name);
    try testing.expectEqual(comptime_int, infoD.fields[1].type);
    try testing.expectEqual(@as(comptime_int, 5), @as(*const comptime_int, @ptrCast(infoD.fields[1].default_value.?)).*);
    try testing.expectEqual(@as(usize, 0), infoD.decls.len);
    try testing.expectEqual(@as(bool, false), infoD.is_tuple);

    // tuples
    const E = @Type(@typeInfo(@TypeOf(.{ 1, 2 })));
    const infoE = @typeInfo(E).Struct;
    try testing.expectEqual(Type.ContainerLayout.auto, infoE.layout);
    try testing.expectEqualSlices(u8, "0", infoE.fields[0].name);
    try testing.expectEqual(comptime_int, infoE.fields[0].type);
    try testing.expectEqual(@as(comptime_int, 1), @as(*const comptime_int, @ptrCast(infoE.fields[0].default_value.?)).*);
    try testing.expectEqualSlices(u8, "1", infoE.fields[1].name);
    try testing.expectEqual(comptime_int, infoE.fields[1].type);
    try testing.expectEqual(@as(comptime_int, 2), @as(*const comptime_int, @ptrCast(infoE.fields[1].default_value.?)).*);
    try testing.expectEqual(@as(usize, 0), infoE.decls.len);
    try testing.expectEqual(@as(bool, true), infoE.is_tuple);

    // empty struct
    const F = @Type(@typeInfo(struct {}));
    const infoF = @typeInfo(F).Struct;
    try testing.expectEqual(Type.ContainerLayout.auto, infoF.layout);
    try testing.expect(infoF.fields.len == 0);
    try testing.expectEqual(@as(bool, false), infoF.is_tuple);

    // empty tuple
    const G = @Type(@typeInfo(@TypeOf(.{})));
    const infoG = @typeInfo(G).Struct;
    try testing.expectEqual(Type.ContainerLayout.auto, infoG.layout);
    try testing.expect(infoG.fields.len == 0);
    try testing.expectEqual(@as(bool, true), infoG.is_tuple);
}

test "Type.Enum" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const Foo = @Type(.{
        .Enum = .{
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
    try testing.expectEqual(@as(u8, 1), @intFromEnum(Foo.a));
    try testing.expectEqual(@as(u8, 5), @intFromEnum(Foo.b));
    const Bar = @Type(.{
        .Enum = .{
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
    try testing.expectEqual(@as(u32, 1), @intFromEnum(Bar.a));
    try testing.expectEqual(@as(u32, 5), @intFromEnum(Bar.b));
    try testing.expectEqual(@as(u32, 6), @intFromEnum(@as(Bar, @enumFromInt(6))));
}

test "Type.Union" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const Untagged = @Type(.{
        .Union = .{
            .layout = .@"extern",
            .tag_type = null,
            .fields = &.{
                .{ .name = "int", .type = i32, .alignment = @alignOf(f32) },
                .{ .name = "float", .type = f32, .alignment = @alignOf(f32) },
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
            .layout = .@"packed",
            .tag_type = null,
            .fields = &.{
                .{ .name = "signed", .type = i32, .alignment = @alignOf(i32) },
                .{ .name = "unsigned", .type = u32, .alignment = @alignOf(u32) },
            },
            .decls = &.{},
        },
    });
    var packed_untagged: PackedUntagged = .{ .signed = -1 };
    _ = &packed_untagged;
    try testing.expectEqual(@as(i32, -1), packed_untagged.signed);
    try testing.expectEqual(~@as(u32, 0), packed_untagged.unsigned);

    const Tag = @Type(.{
        .Enum = .{
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
            .layout = .auto,
            .tag_type = Tag,
            .fields = &.{
                .{ .name = "signed", .type = i32, .alignment = @alignOf(i32) },
                .{ .name = "unsigned", .type = u32, .alignment = @alignOf(u32) },
            },
            .decls = &.{},
        },
    });
    var tagged = Tagged{ .signed = -1 };
    try testing.expectEqual(Tag.signed, @as(Tag, tagged));
    tagged = .{ .unsigned = 1 };
    try testing.expectEqual(Tag.unsigned, @as(Tag, tagged));
}

test "Type.Union from Type.Enum" {
    const Tag = @Type(.{
        .Enum = .{
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
            .layout = .auto,
            .tag_type = Tag,
            .fields = &.{
                .{ .name = "working_as_expected", .type = u32, .alignment = @alignOf(u32) },
            },
            .decls = &.{},
        },
    });
    _ = @typeInfo(T).Union;
}

test "Type.Union from regular enum" {
    const E = enum { working_as_expected };
    const T = @Type(.{
        .Union = .{
            .layout = .auto,
            .tag_type = E,
            .fields = &.{
                .{ .name = "working_as_expected", .type = u32, .alignment = @alignOf(u32) },
            },
            .decls = &.{},
        },
    });
    _ = @typeInfo(T).Union;
}

test "Type.Union from empty regular enum" {
    const E = enum {};
    const U = @Type(.{
        .Union = .{
            .layout = .auto,
            .tag_type = E,
            .fields = &.{},
            .decls = &.{},
        },
    });
    try testing.expectEqual(@sizeOf(U), 0);
}

test "Type.Union from empty Type.Enum" {
    const E = @Type(.{
        .Enum = .{
            .tag_type = u0,
            .fields = &.{},
            .decls = &.{},
            .is_exhaustive = true,
        },
    });
    const U = @Type(.{
        .Union = .{
            .layout = .auto,
            .tag_type = E,
            .fields = &.{},
            .decls = &.{},
        },
    });
    try testing.expectEqual(@sizeOf(U), 0);
}

test "Type.Fn" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const some_opaque = opaque {};
    const some_ptr = *some_opaque;
    const T = fn (c_int, some_ptr) callconv(.C) void;

    {
        const fn_info = std.builtin.Type{ .Fn = .{
            .calling_convention = .C,
            .is_generic = false,
            .is_var_args = false,
            .return_type = void,
            .params = &.{
                .{ .is_generic = false, .is_noalias = false, .type = c_int },
                .{ .is_generic = false, .is_noalias = false, .type = some_ptr },
            },
        } };

        const fn_type = @Type(fn_info);
        try std.testing.expectEqual(T, fn_type);
    }

    {
        const fn_info = @typeInfo(T);
        const fn_type = @Type(fn_info);
        try std.testing.expectEqual(T, fn_type);
    }
}

test "reified struct field name from optional payload" {
    comptime {
        const m_name: ?[1:0]u8 = "a".*;
        if (m_name) |*name| {
            const T = @Type(.{ .Struct = .{
                .layout = .auto,
                .fields = &.{.{
                    .name = name,
                    .type = u8,
                    .default_value = null,
                    .is_comptime = false,
                    .alignment = 1,
                }},
                .decls = &.{},
                .is_tuple = false,
            } });
            const t: T = .{ .a = 123 };
            try std.testing.expect(t.a == 123);
        }
    }
}

test "reified union uses @alignOf" {
    const S = struct {
        fn CreateUnion(comptime T: type) type {
            return @Type(.{
                .Union = .{
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
                },
            });
        }
    };
    _ = S.CreateUnion(struct {});
}

test "reified struct uses @alignOf" {
    const S = struct {
        fn NamespacedGlobals(comptime modules: anytype) type {
            return @Type(.{
                .Struct = .{
                    .layout = .auto,
                    .is_tuple = false,
                    .fields = &.{
                        .{
                            .name = "globals",
                            .type = modules.mach.globals,
                            .default_value = null,
                            .is_comptime = false,
                            .alignment = @alignOf(modules.mach.globals),
                        },
                    },
                    .decls = &.{},
                },
            });
        }
    };
    _ = S.NamespacedGlobals(.{
        .mach = .{
            .globals = struct {},
        },
    });
}

test "reified error set initialized with field pointer" {
    const S = struct {
        const info = .{
            .args = [_]Type.Error{
                .{ .name = "bar" },
            },
        };
        const Foo = @Type(.{
            .ErrorSet = &info.args,
        });
    };
    try testing.expect(S.Foo == error{bar});
}
test "reified function type params initialized with field pointer" {
    const S = struct {
        const fn_info = .{
            .params = [_]Type.Fn.Param{
                .{ .is_generic = false, .is_noalias = false, .type = u8 },
            },
        };
        const Bar = @Type(.{
            .Fn = .{
                .calling_convention = .Unspecified,
                .is_generic = false,
                .is_var_args = false,
                .return_type = void,
                .params = &fn_info.params,
            },
        });
    };
    try testing.expect(@typeInfo(S.Bar) == .Fn);
}

test "empty struct assigned to reified struct field" {
    const S = struct {
        fn NamespacedComponents(comptime modules: anytype) type {
            return @Type(.{
                .Struct = .{
                    .layout = .auto,
                    .is_tuple = false,
                    .fields = &.{.{
                        .name = "components",
                        .type = @TypeOf(modules.components),
                        .default_value = null,
                        .is_comptime = false,
                        .alignment = @alignOf(@TypeOf(modules.components)),
                    }},
                    .decls = &.{},
                },
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

test "@Type should resolve its children types" {
    const sparse = enum(u2) { a, b, c };
    const dense = enum(u2) { a, b, c, d };

    comptime var sparse_info = @typeInfo(anyerror!sparse);
    sparse_info.ErrorUnion.payload = dense;
    const B = @Type(sparse_info);
    try testing.expectEqual(anyerror!dense, B);
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
                .default_value = null,
                .is_comptime = false,
            }};
        }

        const T = @Type(.{
            .Struct = .{
                .layout = .auto,
                .is_tuple = false,
                .fields = fields,
                .decls = &.{},
            },
        });

        const gen_fields = @typeInfo(T).Struct.fields;
        try testing.expectEqual(3, gen_fields.len);
        try testing.expectEqualStrings("f1", gen_fields[0].name);
        try testing.expectEqualStrings("f2", gen_fields[1].name);
        try testing.expectEqualStrings("f3", gen_fields[2].name);
    }
}

test "matching captures causes opaque equivalence" {
    const S = struct {
        fn UnsignedId(comptime I: type) type {
            const U = @Type(.{ .Int = .{
                .signedness = .unsigned,
                .bits = @typeInfo(I).Int.bits,
            } });
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
    const E = @Type(.{ .Enum = .{
        .tag_type = u8,
        .fields = fields[0..2],
        .decls = &.{},
        .is_exhaustive = true,
    } });
    var a: E = undefined;
    var b: E = undefined;
    a = .foo;
    b = .bar;
    try testing.expect(a == .foo);
    try testing.expect(b == .bar);
    try testing.expect(a != b);
}
