const std = @import("std");
const TypeInfo = std.builtin.TypeInfo;
const testing = std.testing;

fn testTypes(comptime types: []const type) !void {
    inline for (types) |testType| {
        try testing.expect(testType == @Type(@typeInfo(testType)));
    }
}

test "Type.MetaType" {
    try testing.expect(type == @Type(TypeInfo{ .Type = undefined }));
    try testTypes(&[_]type{type});
}

test "Type.Void" {
    try testing.expect(void == @Type(TypeInfo{ .Void = undefined }));
    try testTypes(&[_]type{void});
}

test "Type.Bool" {
    try testing.expect(bool == @Type(TypeInfo{ .Bool = undefined }));
    try testTypes(&[_]type{bool});
}

test "Type.NoReturn" {
    try testing.expect(noreturn == @Type(TypeInfo{ .NoReturn = undefined }));
    try testTypes(&[_]type{noreturn});
}

test "Type.Int" {
    try testing.expect(u1 == @Type(TypeInfo{ .Int = TypeInfo.Int{ .signedness = .unsigned, .bits = 1 } }));
    try testing.expect(i1 == @Type(TypeInfo{ .Int = TypeInfo.Int{ .signedness = .signed, .bits = 1 } }));
    try testing.expect(u8 == @Type(TypeInfo{ .Int = TypeInfo.Int{ .signedness = .unsigned, .bits = 8 } }));
    try testing.expect(i8 == @Type(TypeInfo{ .Int = TypeInfo.Int{ .signedness = .signed, .bits = 8 } }));
    try testing.expect(u64 == @Type(TypeInfo{ .Int = TypeInfo.Int{ .signedness = .unsigned, .bits = 64 } }));
    try testing.expect(i64 == @Type(TypeInfo{ .Int = TypeInfo.Int{ .signedness = .signed, .bits = 64 } }));
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
