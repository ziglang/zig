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
    testing.expect(type == @Type(TypeInfo { .Type = undefined }));
    testTypes([_]type {type});
}

test "Type.Void" {
    testing.expect(void == @Type(TypeInfo { .Void = undefined }));
    testTypes([_]type {void});
}

test "Type.Bool" {
    testing.expect(bool == @Type(TypeInfo { .Bool = undefined }));
    testTypes([_]type {bool});
}

test "Type.NoReturn" {
    testing.expect(noreturn == @Type(TypeInfo { .NoReturn = undefined }));
    testTypes([_]type {noreturn});
}

test "Type.Int" {
    testing.expect(u1 == @Type(TypeInfo { .Int = TypeInfo.Int { .is_signed = false, .bits = 1 } }));
    testing.expect(i1 == @Type(TypeInfo { .Int = TypeInfo.Int { .is_signed = true, .bits = 1 } }));
    testing.expect(u8 == @Type(TypeInfo { .Int = TypeInfo.Int { .is_signed = false, .bits = 8 } }));
    testing.expect(i8 == @Type(TypeInfo { .Int = TypeInfo.Int { .is_signed = true, .bits = 8 } }));
    testing.expect(u64 == @Type(TypeInfo { .Int = TypeInfo.Int { .is_signed = false, .bits = 64 } }));
    testing.expect(i64 == @Type(TypeInfo { .Int = TypeInfo.Int { .is_signed = true, .bits = 64 } }));
    testTypes([_]type {u8,u32,i64});
}

test "Type.Float" {
    testing.expect(f16  == @Type(TypeInfo { .Float = TypeInfo.Float { .bits = 16 } }));
    testing.expect(f32  == @Type(TypeInfo { .Float = TypeInfo.Float { .bits = 32 } }));
    testing.expect(f64  == @Type(TypeInfo { .Float = TypeInfo.Float { .bits = 64 } }));
    testing.expect(f128 == @Type(TypeInfo { .Float = TypeInfo.Float { .bits = 128 } }));
    testTypes([_]type {f16, f32, f64, f128});
}

test "Type.Pointer" {
    testTypes([_]type {
        // One Value Pointer Types
        *u8, *const u8,
        *volatile u8, *const volatile u8,
        *align(4) u8, *const align(4) u8,
        *volatile align(4) u8, *const volatile align(4) u8,
        *align(8) u8, *const align(8) u8,
        *volatile align(8) u8, *const volatile align(8) u8,
        *allowzero u8, *const allowzero u8,
        *volatile allowzero u8, *const volatile allowzero u8,
        *align(4) allowzero u8, *const align(4) allowzero u8,
        *volatile align(4) allowzero u8, *const volatile align(4) allowzero u8,
        // Many Values Pointer Types
        [*]u8, [*]const u8,
        [*]volatile u8, [*]const volatile u8,
        [*]align(4) u8, [*]const align(4) u8,
        [*]volatile align(4) u8, [*]const volatile align(4) u8,
        [*]align(8) u8, [*]const align(8) u8,
        [*]volatile align(8) u8, [*]const volatile align(8) u8,
        [*]allowzero u8, [*]const allowzero u8,
        [*]volatile allowzero u8, [*]const volatile allowzero u8,
        [*]align(4) allowzero u8, [*]const align(4) allowzero u8,
        [*]volatile align(4) allowzero u8, [*]const volatile align(4) allowzero u8,
        // Slice Types
        []u8, []const u8,
        []volatile u8, []const volatile u8,
        []align(4) u8, []const align(4) u8,
        []volatile align(4) u8, []const volatile align(4) u8,
        []align(8) u8, []const align(8) u8,
        []volatile align(8) u8, []const volatile align(8) u8,
        []allowzero u8, []const allowzero u8,
        []volatile allowzero u8, []const volatile allowzero u8,
        []align(4) allowzero u8, []const align(4) allowzero u8,
        []volatile align(4) allowzero u8, []const volatile align(4) allowzero u8,
        // C Pointer Types
        [*c]u8, [*c]const u8,
        [*c]volatile u8, [*c]const volatile u8,
        [*c]align(4) u8, [*c]const align(4) u8,
        [*c]volatile align(4) u8, [*c]const volatile align(4) u8,
        [*c]align(8) u8, [*c]const align(8) u8,
        [*c]volatile align(8) u8, [*c]const volatile align(8) u8,
    });
}

test "Type.Array" {
    testing.expect([123]u8 == @Type(TypeInfo { .Array = TypeInfo.Array { .len = 123, .child = u8 } }));
    testing.expect([2]u32 == @Type(TypeInfo { .Array = TypeInfo.Array { .len = 2, .child = u32 } }));
    testTypes([_]type {[1]u8, [30]usize, [7]bool});
}

test "Type.ComptimeFloat" {
    testTypes([_]type {comptime_float});
}
test "Type.ComptimeInt" {
    testTypes([_]type {comptime_int});
}
test "Type.Undefined" {
    testTypes([_]type {@typeOf(undefined)});
}
test "Type.Null" {
    testTypes([_]type {@typeOf(null)});
}
