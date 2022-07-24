const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;
const expectEqualStrings = std.testing.expectEqualStrings;
const expectStringStartsWith = std.testing.expectStringStartsWith;

// Most tests here can be comptime but use runtime so that a stacktrace
// can show failure location.
//
// Note certain results of `@typeName()` expect `behavior.zig` to be the
// root file. Running a test against this file as root will result in
// failures.

test "anon fn param" {
    if (builtin.zig_backend == .stage1) {
        // stage1 uses line/column for the names but we're moving away from that for
        // incremental compilation purposes.
        return error.SkipZigTest;
    }

    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    // https://github.com/ziglang/zig/issues/9339
    try expectEqualStringsIgnoreDigits(
        "behavior.typename.TypeFromFn(behavior.typename.test.anon fn param__struct_0)",
        @typeName(TypeFromFn(struct {})),
    );
    try expectEqualStringsIgnoreDigits(
        "behavior.typename.TypeFromFn(behavior.typename.test.anon fn param__union_0)",
        @typeName(TypeFromFn(union { unused: u8 })),
    );
    try expectEqualStringsIgnoreDigits(
        "behavior.typename.TypeFromFn(behavior.typename.test.anon fn param__enum_0)",
        @typeName(TypeFromFn(enum { unused })),
    );

    try expectEqualStringsIgnoreDigits(
        "behavior.typename.TypeFromFnB(behavior.typename.test.anon fn param__struct_0,behavior.typename.test.anon fn param__union_0,behavior.typename.test.anon fn param__enum_0)",
        @typeName(TypeFromFnB(struct {}, union { unused: u8 }, enum { unused })),
    );
}

test "anon field init" {
    if (builtin.zig_backend == .stage1) {
        // stage1 uses line/column for the names but we're moving away from that for
        // incremental compilation purposes.
        return error.SkipZigTest;
    }

    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const Foo = .{
        .T1 = struct {},
        .T2 = union { unused: u8 },
        .T3 = enum { unused },
    };

    try expectEqualStringsIgnoreDigits(
        "behavior.typename.test.anon field init__struct_0",
        @typeName(Foo.T1),
    );
    try expectEqualStringsIgnoreDigits(
        "behavior.typename.test.anon field init__union_0",
        @typeName(Foo.T2),
    );
    try expectEqualStringsIgnoreDigits(
        "behavior.typename.test.anon field init__enum_0",
        @typeName(Foo.T3),
    );
}

test "basic" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    try expectEqualStrings(@typeName(i64), "i64");
    try expectEqualStrings(@typeName(*usize), "*usize");
    try expectEqualStrings(@typeName([]u8), "[]u8");
}

test "top level decl" {
    if (builtin.zig_backend == .stage1) {
        // stage1 fails to return fully qualified namespaces.
        return error.SkipZigTest;
    }

    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    try expectEqualStrings(
        "behavior.typename.A_Struct",
        @typeName(A_Struct),
    );
    try expectEqualStrings(
        "behavior.typename.A_Union",
        @typeName(A_Union),
    );
    try expectEqualStrings(
        "behavior.typename.A_Enum",
        @typeName(A_Enum),
    );

    // regular fn, without error
    try expectEqualStrings(
        "fn() void",
        @typeName(@TypeOf(regular)),
    );
    // regular fn inside struct, with error
    try expectEqualStrings(
        "fn() @typeInfo(@typeInfo(@TypeOf(behavior.typename.B.doTest)).Fn.return_type.?).ErrorUnion.error_set!void",
        @typeName(@TypeOf(B.doTest)),
    );
    // generic fn
    try expectEqualStrings(
        "fn(type) type",
        @typeName(@TypeOf(TypeFromFn)),
    );
}

const A_Struct = struct {};
const A_Union = union {
    unused: u8,
};
const A_Enum = enum {
    unused,
};

fn regular() void {}

const B = struct {
    fn doTest() !void {}
};

test "fn param" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    // https://github.com/ziglang/zig/issues/675
    try expectEqualStrings(
        "behavior.typename.TypeFromFn(u8)",
        @typeName(TypeFromFn(u8)),
    );
    try expectEqualStrings(
        "behavior.typename.TypeFromFn(behavior.typename.A_Struct)",
        @typeName(TypeFromFn(A_Struct)),
    );
    try expectEqualStrings(
        "behavior.typename.TypeFromFn(behavior.typename.A_Union)",
        @typeName(TypeFromFn(A_Union)),
    );
    try expectEqualStrings(
        "behavior.typename.TypeFromFn(behavior.typename.A_Enum)",
        @typeName(TypeFromFn(A_Enum)),
    );

    try expectEqualStrings(
        "behavior.typename.TypeFromFn2(u8,bool)",
        @typeName(TypeFromFn2(u8, bool)),
    );
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

fn TypeFromFnB(comptime T1: type, comptime T2: type, comptime T3: type) type {
    _ = T1;
    _ = T2;
    _ = T3;
    return struct {};
}

/// Replaces integers in `actual` with '0' before doing the test.
pub fn expectEqualStringsIgnoreDigits(expected: []const u8, actual: []const u8) !void {
    var actual_buf: [1024]u8 = undefined;
    var actual_i: usize = 0;
    var last_digit = false;
    for (actual) |byte| {
        switch (byte) {
            '0'...'9' => {
                if (last_digit) continue;
                last_digit = true;
                actual_buf[actual_i] = '0';
                actual_i += 1;
            },
            else => {
                last_digit = false;
                actual_buf[actual_i] = byte;
                actual_i += 1;
            },
        }
    }
    return expectEqualStrings(expected, actual_buf[0..actual_i]);
}

test "local variable" {
    if (builtin.zig_backend == .stage1) {
        // stage1 fails to return fully qualified namespaces.
        return error.SkipZigTest;
    }

    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const Foo = struct { a: u32 };
    const Bar = union { a: u32 };
    const Baz = enum { a, b };
    const Qux = enum { a, b };
    const Quux = enum { a, b };

    try expectEqualStrings("behavior.typename.test.local variable.Foo", @typeName(Foo));
    try expectEqualStrings("behavior.typename.test.local variable.Bar", @typeName(Bar));
    try expectEqualStrings("behavior.typename.test.local variable.Baz", @typeName(Baz));
    try expectEqualStrings("behavior.typename.test.local variable.Qux", @typeName(Qux));
    try expectEqualStrings("behavior.typename.test.local variable.Quux", @typeName(Quux));
}
