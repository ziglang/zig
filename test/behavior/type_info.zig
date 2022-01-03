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

test "type info: C pointer type info" {
    try testCPtr();
    comptime try testCPtr();
}

fn testCPtr() !void {
    const ptr_info = @typeInfo([*c]align(4) const i8);
    try expect(ptr_info == .Pointer);
    try expect(ptr_info.Pointer.size == .C);
    try expect(ptr_info.Pointer.is_const);
    try expect(!ptr_info.Pointer.is_volatile);
    try expect(ptr_info.Pointer.alignment == 4);
    try expect(ptr_info.Pointer.child == i8);
}

test "type info: value is correctly copied" {
    comptime {
        var ptrInfo = @typeInfo([]u32);
        ptrInfo.Pointer.size = .One;
        try expect(@typeInfo([]u32).Pointer.size == .Slice);
    }
}
