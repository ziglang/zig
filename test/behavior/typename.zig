//
const std = @import("std");
const expectEqualStrings = std.testing.expectEqualStrings;

// Most tests here can be comptime but use runtime so that a stacktrace
// can show failure location.
//
// Note certain results of `@typeName()` expect `behavior.zig` to be the
// root file. Running a test against this file as root will result in
// failures.

// CAUTION: this test is source-location sensitive.
test "anon fn param - source-location sensitive" {
    // https://github.com/ziglang/zig/issues/9339
    try expectEqualStrings(@typeName(TypeFromFn(struct {})), "behavior.typename.TypeFromFn(behavior.typename.struct:15:49)");
    try expectEqualStrings(@typeName(TypeFromFn(union { unused: u8 })), "behavior.typename.TypeFromFn(behavior.typename.union:16:49)");
    try expectEqualStrings(@typeName(TypeFromFn(enum { unused })), "behavior.typename.TypeFromFn(behavior.typename.enum:17:49)");

    try expectEqualStrings(
        @typeName(TypeFromFn3(struct {}, union { unused: u8 }, enum { unused })),
        "behavior.typename.TypeFromFn3(behavior.typename.struct:20:31,behavior.typename.union:20:42,behavior.typename.enum:20:64)",
    );
}

// CAUTION: this test is source-location sensitive.
test "anon field init" {
    const Foo = .{
        .T1 = struct {},
        .T2 = union { unused: u8 },
        .T3 = enum { unused },
    };

    try expectEqualStrings(@typeName(Foo.T1), "behavior.typename.struct:28:15");
    try expectEqualStrings(@typeName(Foo.T2), "behavior.typename.union:29:15");
    try expectEqualStrings(@typeName(Foo.T3), "behavior.typename.enum:30:15");
}

test "basic" {
    try expectEqualStrings(@typeName(i64), "i64");
    try expectEqualStrings(@typeName(*usize), "*usize");
    try expectEqualStrings(@typeName([]u8), "[]u8");
}

test "top level decl" {
    try expectEqualStrings(@typeName(A_Struct), "A_Struct");
    try expectEqualStrings(@typeName(A_Union), "A_Union");
    try expectEqualStrings(@typeName(A_Enum), "A_Enum");

    // regular fn, without error
    try expectEqualStrings(@typeName(@TypeOf(regular)), "fn() void");
    // regular fn inside struct, with error
    try expectEqualStrings(@typeName(@TypeOf(B.doTest)), "fn() @typeInfo(@typeInfo(@TypeOf(behavior.typename.B.doTest)).Fn.return_type.?).ErrorUnion.error_set!void");
    // generic fn
    try expectEqualStrings(@typeName(@TypeOf(TypeFromFn)), "fn(type) anytype");
}

const A_Struct = struct {};
const A_Union = union {
    unused: u8,
};
const A_Enum = enum {
    unused,
};

fn regular() void {}

test "fn body decl" {
    try B.doTest();
}

const B = struct {
    fn doTest() !void {
        const B_Struct = struct {};
        const B_Union = union {
            unused: u8,
        };
        const B_Enum = enum {
            unused,
        };

        try expectEqualStrings(@typeName(B_Struct), "B_Struct");
        try expectEqualStrings(@typeName(B_Union), "B_Union");
        try expectEqualStrings(@typeName(B_Enum), "B_Enum");
    }
};

test "fn param" {
    // https://github.com/ziglang/zig/issues/675
    try expectEqualStrings(@typeName(TypeFromFn(u8)), "behavior.typename.TypeFromFn(u8)");
    try expectEqualStrings(@typeName(TypeFromFn(A_Struct)), "behavior.typename.TypeFromFn(behavior.typename.A_Struct)");
    try expectEqualStrings(@typeName(TypeFromFn(A_Union)), "behavior.typename.TypeFromFn(behavior.typename.A_Union)");
    try expectEqualStrings(@typeName(TypeFromFn(A_Enum)), "behavior.typename.TypeFromFn(behavior.typename.A_Enum)");

    try expectEqualStrings(@typeName(TypeFromFn2(u8, bool)), "behavior.typename.TypeFromFn2(u8,bool)");
}

fn TypeFromFn(comptime T: type) type {
    _ = T;
    return struct {};
}

fn TypeFromFn2(comptime T1: type, comptime T2: type) type {
    _ = T1;
    _ = T2;
    return struct {};
}

fn TypeFromFn3(comptime T1: type, comptime T2: type, comptime T3: type) type {
    _ = T1;
    _ = T2;
    _ = T3;
    return struct {};
}
