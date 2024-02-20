const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

const h = @cImport(@cInclude("macros.h"));
const latin1 = @cImport(@cInclude("macros_not_utf8.h"));

test "casting to void with a macro" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    h.IGNORE_ME_1(42);
    h.IGNORE_ME_2(42);
    h.IGNORE_ME_3(42);
    h.IGNORE_ME_4(42);
    h.IGNORE_ME_5(42);
    h.IGNORE_ME_6(42);
    h.IGNORE_ME_7(42);
    h.IGNORE_ME_8(42);
    h.IGNORE_ME_9(42);
    h.IGNORE_ME_10(42);
}

test "initializer list expression" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try expectEqual(h.Color{
        .r = 200,
        .g = 200,
        .b = 200,
        .a = 255,
    }, h.LIGHTGRAY);
}

test "sizeof in macros" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try expect(@as(c_int, @sizeOf(u32)) == h.MY_SIZEOF(u32));
    try expect(@as(c_int, @sizeOf(u32)) == h.MY_SIZEOF2(u32));
}

test "reference to a struct type" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try expect(@sizeOf(h.struct_Foo) == h.SIZE_OF_FOO);
}

test "cast negative integer to pointer" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try expectEqual(@as(?*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, -1))))), h.MAP_FAILED);
}

test "casting to union with a macro" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const l: c_long = 42;
    const d: f64 = 2.0;

    var casted = h.UNION_CAST(l);
    try expect(l == casted.l);

    casted = h.UNION_CAST(d);
    try expect(d == casted.d);
}

test "casting or calling a value with a paren-surrounded macro" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const l: c_long = 42;
    const casted = h.CAST_OR_CALL_WITH_PARENS(c_int, l);
    try expect(casted == @as(c_int, @intCast(l)));

    const Helper = struct {
        fn foo(n: c_int) !void {
            try expect(n == 42);
        }
    };

    try h.CAST_OR_CALL_WITH_PARENS(Helper.foo, 42);
}

test "nested comma operator" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try expectEqual(@as(c_int, 3), h.NESTED_COMMA_OPERATOR);
    try expectEqual(@as(c_int, 3), h.NESTED_COMMA_OPERATOR_LHS);
}

test "cast functions" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        fn foo() void {}
    };
    try expectEqual(true, h.CAST_TO_BOOL(S.foo));
    try expect(h.CAST_TO_UINTPTR(S.foo) != 0);
}

test "large integer macro" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try expectEqual(@as(c_ulonglong, 18446744073709550592), h.LARGE_INT);
}

test "string literal macro with embedded tab character" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try expectEqualStrings("hello\t", h.EMBEDDED_TAB);
}

test "string and char literals that are not UTF-8 encoded. Issue #12784" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try expectEqual(@as(u8, '\xA9'), latin1.UNPRINTABLE_CHAR);
    try expectEqualStrings("\xA9\xA9\xA9", latin1.UNPRINTABLE_STRING);
}

test "Macro that uses division operator. Issue #13162" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;

    try expectEqual(@as(c_int, 42), h.DIVIDE_CONSTANT(@as(c_int, 42_000)));
    try expectEqual(@as(c_uint, 42), h.DIVIDE_CONSTANT(@as(c_uint, 42_000)));

    try expectEqual(
        @as(f64, 42.0),
        h.DIVIDE_ARGS(
            @as(f64, 42.0),
            true,
        ),
    );
    try expectEqual(
        @as(c_int, 21),
        h.DIVIDE_ARGS(
            @as(i8, 42),
            @as(i8, 2),
        ),
    );

    try expectEqual(
        @as(c_int, 21),
        h.DIVIDE_ARGS(
            @as(c_ushort, 42),
            @as(c_ushort, 2),
        ),
    );
}

test "Macro that uses remainder operator. Issue #13346" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try expectEqual(@as(c_int, 2_010), h.REMAINDER_CONSTANT(@as(c_int, 42_010)));
    try expectEqual(@as(c_uint, 2_030), h.REMAINDER_CONSTANT(@as(c_uint, 42_030)));

    try expectEqual(
        @as(c_int, 7),
        h.REMAINDER_ARGS(
            @as(i8, 17),
            @as(i8, 10),
        ),
    );

    try expectEqual(
        @as(c_int, 5),
        h.REMAINDER_ARGS(
            @as(c_ushort, 25),
            @as(c_ushort, 20),
        ),
    );

    try expectEqual(
        @as(c_int, 1),
        h.REMAINDER_ARGS(
            @as(c_int, 5),
            @as(c_int, -2),
        ),
    );
}

test "@typeInfo on @cImport result" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try expect(@typeInfo(h).Struct.decls.len > 1);
}

test "Macro that uses Long type concatenation casting" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try expect((@TypeOf(h.X)) == c_long);
    try expectEqual(h.X, @as(c_long, 10));
}

test "Blank macros" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try expectEqual(h.BLANK_MACRO, "");
    try expectEqual(h.BLANK_CHILD_MACRO, "");
    try expect(@TypeOf(h.BLANK_MACRO_CAST) == h.def_type);
    try expectEqual(h.BLANK_MACRO_CAST, @as(c_long, 0));
}
