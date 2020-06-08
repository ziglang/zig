const builtin = @import("builtin");
const TypeInfo = builtin.TypeInfo;

const std = @import("std");
const testing = std.testing;

fn testTypes(comptime types: []const type) void {
    inline for (types) |testType| {
        testing.expect(testType == @Type(@typeInfo(testType)));
    }
}

test "Type.MetaType" {
    testing.expect(type == @Type(TypeInfo{ .Type = undefined }));
    testTypes(&[_]type{type});
}

test "Type.Void" {
    testing.expect(void == @Type(TypeInfo{ .Void = undefined }));
    testTypes(&[_]type{void});
}

test "Type.Bool" {
    testing.expect(bool == @Type(TypeInfo{ .Bool = undefined }));
    testTypes(&[_]type{bool});
}

test "Type.NoReturn" {
    testing.expect(noreturn == @Type(TypeInfo{ .NoReturn = undefined }));
    testTypes(&[_]type{noreturn});
}

test "Type.Int" {
    testing.expect(u1 == @Type(TypeInfo{ .Int = TypeInfo.Int{ .is_signed = false, .bits = 1 } }));
    testing.expect(i1 == @Type(TypeInfo{ .Int = TypeInfo.Int{ .is_signed = true, .bits = 1 } }));
    testing.expect(u8 == @Type(TypeInfo{ .Int = TypeInfo.Int{ .is_signed = false, .bits = 8 } }));
    testing.expect(i8 == @Type(TypeInfo{ .Int = TypeInfo.Int{ .is_signed = true, .bits = 8 } }));
    testing.expect(u64 == @Type(TypeInfo{ .Int = TypeInfo.Int{ .is_signed = false, .bits = 64 } }));
    testing.expect(i64 == @Type(TypeInfo{ .Int = TypeInfo.Int{ .is_signed = true, .bits = 64 } }));
    testTypes(&[_]type{ u8, u32, i64 });
}

test "Type.Float" {
    testing.expect(f16 == @Type(TypeInfo{ .Float = TypeInfo.Float{ .bits = 16 } }));
    testing.expect(f32 == @Type(TypeInfo{ .Float = TypeInfo.Float{ .bits = 32 } }));
    testing.expect(f64 == @Type(TypeInfo{ .Float = TypeInfo.Float{ .bits = 64 } }));
    testing.expect(f128 == @Type(TypeInfo{ .Float = TypeInfo.Float{ .bits = 128 } }));
    testTypes(&[_]type{ f16, f32, f64, f128 });
}

test "Type.Pointer" {
    testTypes(&[_]type{
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

test "Type.Array" {
    testing.expect([123]u8 == @Type(TypeInfo{
        .Array = TypeInfo.Array{
            .len = 123,
            .child = u8,
            .sentinel = null,
        },
    }));
    testing.expect([2]u32 == @Type(TypeInfo{
        .Array = TypeInfo.Array{
            .len = 2,
            .child = u32,
            .sentinel = null,
        },
    }));
    testing.expect([2:0]u32 == @Type(TypeInfo{
        .Array = TypeInfo.Array{
            .len = 2,
            .child = u32,
            .sentinel = 0,
        },
    }));
    testTypes(&[_]type{ [1]u8, [30]usize, [7]bool });
}

test "Type.ComptimeFloat" {
    testTypes(&[_]type{comptime_float});
}
test "Type.ComptimeInt" {
    testTypes(&[_]type{comptime_int});
}
test "Type.Undefined" {
    testTypes(&[_]type{@TypeOf(undefined)});
}
test "Type.Null" {
    testTypes(&[_]type{@TypeOf(null)});
}
test "@Type create slice with null sentinel" {
    const Slice = @Type(builtin.TypeInfo{
        .Pointer = .{
            .size = .Slice,
            .is_const = true,
            .is_volatile = false,
            .is_allowzero = false,
            .alignment = 8,
            .child = *i32,
            .sentinel = null,
        },
    });
    testing.expect(Slice == []align(8) const *i32);
}
test "@Type picks up the sentinel value from TypeInfo" {
    testTypes(&[_]type{
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
    testTypes(&[_]type{
        ?u8,
        ?*u8,
        ?[]u8,
        ?[*]u8,
        ?[*c]u8,
    });
}

test "Type.ErrorUnion" {
    testTypes(&[_]type{
        error{}!void,
        error{Error}!void,
    });
}

test "Type.Opaque" {
    testing.expect(@OpaqueType() != @Type(.Opaque));
    testing.expect(@Type(.Opaque) != @Type(.Opaque));
    testing.expect(@typeInfo(@Type(.Opaque)) == .Opaque);
}

test "Type.Vector" {
    testTypes(&[_]type{
        @Vector(0, u8),
        @Vector(4, u8),
        @Vector(8, *u8),
        std.meta.Vector(0, u8),
        std.meta.Vector(4, u8),
        std.meta.Vector(8, *u8),
    });
}

test "Type.AnyFrame" {
    testTypes(&[_]type{
        anyframe,
        anyframe->u8,
        anyframe->anyframe->u8,
    });
}
