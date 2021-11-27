const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "void parameters" {
    try voidFun(1, void{}, 2, {});
}
fn voidFun(a: i32, b: void, c: i32, d: void) !void {
    _ = d;
    const v = b;
    const vv: void = if (a == 1) v else {};
    try expect(a + c == 3);
    return vv;
}

test "call function with empty string" {
    acceptsString("");
}

fn acceptsString(foo: []u8) void {
    _ = foo;
}

test "function pointers" {
    const fns = [_]@TypeOf(fn1){
        fn1,
        fn2,
        fn3,
        fn4,
    };
    for (fns) |f, i| {
        try expect(f() == @intCast(u32, i) + 5);
    }
}
fn fn1() u32 {
    return 5;
}
fn fn2() u32 {
    return 6;
}
fn fn3() u32 {
    return 7;
}
fn fn4() u32 {
    return 8;
}

test "number literal as an argument" {
    try numberLiteralArg(3);
    comptime try numberLiteralArg(3);
}

fn numberLiteralArg(a: anytype) !void {
    try expect(a == 3);
}

test "function call with anon list literal" {
    const S = struct {
        fn doTheTest() !void {
            try consumeVec(.{ 9, 8, 7 });
        }

        fn consumeVec(vec: [3]f32) !void {
            try expect(vec[0] == 9);
            try expect(vec[1] == 8);
            try expect(vec[2] == 7);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "ability to give comptime types and non comptime types to same parameter" {
    const S = struct {
        fn doTheTest() !void {
            var x: i32 = 1;
            try expect(foo(x) == 10);
            try expect(foo(i32) == 20);
        }

        fn foo(arg: anytype) i32 {
            if (@typeInfo(@TypeOf(arg)) == .Type and arg == i32) return 20;
            return 9 + arg;
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "function with inferred error set but returning no error" {
    const S = struct {
        fn foo() !void {}
    };

    const return_ty = @typeInfo(@TypeOf(S.foo)).Fn.return_type.?;
    try expectEqual(0, @typeInfo(@typeInfo(return_ty).ErrorUnion.error_set).ErrorSet.?.len);
}
