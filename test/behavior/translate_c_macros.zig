const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const h = @cImport(@cInclude("behavior/translate_c_macros.h"));

test "casting to void with a macro" {
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
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    try expectEqual(h.Color{
        .r = 200,
        .g = 200,
        .b = 200,
        .a = 255,
    }, h.LIGHTGRAY);
}

test "sizeof in macros" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    try expect(@as(c_int, @sizeOf(u32)) == h.MY_SIZEOF(u32));
    try expect(@as(c_int, @sizeOf(u32)) == h.MY_SIZEOF2(u32));
}

test "reference to a struct type" {
    try expect(@sizeOf(h.struct_Foo) == h.SIZE_OF_FOO);
}

test "cast negative integer to pointer" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    try expectEqual(@intToPtr(?*anyopaque, @bitCast(usize, @as(isize, -1))), h.MAP_FAILED);
}

test "casting to union with a macro" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const l: c_long = 42;
    const d: f64 = 2.0;

    var casted = h.UNION_CAST(l);
    try expect(l == casted.l);

    casted = h.UNION_CAST(d);
    try expect(d == casted.d);
}

test "casting or calling a value with a paren-surrounded macro" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const l: c_long = 42;
    const casted = h.CAST_OR_CALL_WITH_PARENS(c_int, l);
    try expect(casted == @intCast(c_int, l));

    const Helper = struct {
        fn foo(n: c_int) !void {
            try expect(n == 42);
        }
    };

    try h.CAST_OR_CALL_WITH_PARENS(Helper.foo, 42);
}

test "nested comma operator" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    try expectEqual(@as(c_int, 3), h.NESTED_COMMA_OPERATOR);
}
