const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const expect = testing.expect;
const expectEqualStrings = testing.expectEqualStrings;

test "tuple declaration type info" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    {
        const T = struct { comptime u32 align(2) = 1, []const u8 };
        const info = @typeInfo(T).Struct;

        try expect(info.layout == .auto);
        try expect(info.backing_integer == null);
        try expect(info.fields.len == 2);
        try expect(info.decls.len == 0);
        try expect(info.is_tuple);

        try expectEqualStrings(info.fields[0].name, "0");
        try expect(info.fields[0].type == u32);
        try expect(@as(*const u32, @ptrCast(@alignCast(info.fields[0].default_value))).* == 1);
        try expect(info.fields[0].is_comptime);
        try expect(info.fields[0].alignment == 2);

        try expectEqualStrings(info.fields[1].name, "1");
        try expect(info.fields[1].type == []const u8);
        try expect(info.fields[1].default_value == null);
        try expect(!info.fields[1].is_comptime);
        try expect(info.fields[1].alignment == @alignOf([]const u8));
    }
}

test "Tuple declaration usage" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const T = struct { u32, []const u8 };
    var t: T = .{ 1, "foo" };
    _ = &t;
    try expect(t[0] == 1);
    try expectEqualStrings(t[1], "foo");

    const mul = t ** 3;
    try expect(@TypeOf(mul) != T);
    try expect(mul.len == 6);
    try expect(mul[2] == 1);
    try expectEqualStrings(mul[3], "foo");

    var t2: T = .{ 2, "bar" };
    _ = &t2;
    const cat = t ++ t2;
    try expect(@TypeOf(cat) != T);
    try expect(cat.len == 4);
    try expect(cat[2] == 2);
    try expectEqualStrings(cat[3], "bar");
}
