const std = @import("std");

const expectEqual = std.testing.expectEqual;

fn testAlignment(comptime namespace_ty: type, comptime decl_name: []const u8, comptime alignment: comptime_int) !void {
    const decl = @reflectDecl(namespace_ty, decl_name);
    try expectEqual(decl.alignment, alignment);
}

fn testType(comptime namespace_ty: type, comptime decl_name: []const u8, comptime func_ty: type) !void {
    const decl = @reflectDecl(namespace_ty, decl_name);
    try expectEqual(decl.ty, func_ty);
}

fn testFunction() align(4) void {}

const TestStruct = struct {
    fn testFunction() align(4) void {}
};

const TestUnion = union {
    foo: void,

    usingnamespace TestStruct;
};

const TestEnum = enum {
    foo,

    usingnamespace TestStruct;
};

const TestOpaque = opaque {
    usingnamespace TestStruct;
};

test "@reflectFunc: correct alignment" {
    try testAlignment(@This(), "testFunction", 4);
    try testAlignment(TestStruct, "testFunction", 4);
    try testAlignment(TestUnion, "testFunction", 4);
    try testAlignment(TestEnum, "testFunction", 4);
    try testAlignment(TestOpaque, "testFunction", 4);
}

test "@reflectFunc: correct type" {
    try testType(@This(), "testFunction", @TypeOf(testFunction));
    try testType(TestStruct, "testFunction", @TypeOf(TestStruct.testFunction));
    try testType(TestUnion, "testFunction", @TypeOf(TestUnion.testFunction));
    try testType(TestEnum, "testFunction", @TypeOf(TestEnum.testFunction));
    try testType(TestOpaque, "testFunction", @TypeOf(TestOpaque.testFunction));
}
