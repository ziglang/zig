const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;

const TypeInfo = std.builtin.TypeInfo;
const TypeId = std.builtin.TypeId;

const expect = std.testing.expect;
const expectEqualStrings = std.testing.expectEqualStrings;

test "type info: integer, floating point type info" {
    try testIntFloat();
    comptime try testIntFloat();
}

fn testIntFloat() !void {
    const u8_info = @typeInfo(u8);
    try expect(u8_info == .Int);
    try expect(u8_info.Int.signedness == .unsigned);
    try expect(u8_info.Int.bits == 8);

    const f64_info = @typeInfo(f64);
    try expect(f64_info == .Float);
    try expect(f64_info.Float.bits == 64);
}

test "type info: optional type info" {
    try testOptional();
    comptime try testOptional();
}

fn testOptional() !void {
    const null_info = @typeInfo(?void);
    try expect(null_info == .Optional);
    try expect(null_info.Optional.child == void);
}
