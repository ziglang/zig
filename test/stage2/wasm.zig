const std = @import("std");
const TestContext = @import("../../src/test.zig").TestContext;

const wasi = std.zig.CrossTarget{
    .cpu_arch = .wasm32,
    .os_tag = .wasi,
};

pub fn addCases(ctx: *TestContext) !void {
    {
        var case = ctx.exe("wasm function calls", wasi);

        case.addCompareOutput(
            \\pub export fn _start() u32 {
            \\    foo();
            \\    bar();
            \\    return 42;
            \\}
            \\fn foo() void {
            \\    bar();
            \\    bar();
            \\}
            \\fn bar() void {}
        ,
            "42\n",
        );

        case.addCompareOutput(
            \\pub export fn _start() i64 {
            \\    bar();
            \\    foo();
            \\    foo();
            \\    bar();
            \\    foo();
            \\    bar();
            \\    return 42;
            \\}
            \\fn foo() void {
            \\    bar();
            \\}
            \\fn bar() void {}
        ,
            "42\n",
        );

        case.addCompareOutput(
            \\pub export fn _start() f32 {
            \\    bar();
            \\    foo();
            \\    return 42.0;
            \\}
            \\fn foo() void {
            \\    bar();
            \\    bar();
            \\    bar();
            \\}
            \\fn bar() void {}
        ,
            "42\n",
        );

        case.addCompareOutput(
            \\pub export fn _start() u32 {
            \\    foo(10, 20);
            \\    return 5;
            \\}
            \\fn foo(x: u32, y: u32) void {}
        , "5\n");
    }

    {
        var case = ctx.exe("wasm locals", wasi);

        case.addCompareOutput(
            \\pub export fn _start() u32 {
            \\    var i: u32 = 5;
            \\    var y: f32 = 42.0;
            \\    var x: u32 = 10;
            \\    return i;
            \\}
        , "5\n");

        case.addCompareOutput(
            \\pub export fn _start() u32 {
            \\    var i: u32 = 5;
            \\    var y: f32 = 42.0;
            \\    var x: u32 = 10;
            \\    foo(i, x);
            \\    i = x;
            \\    return i;
            \\}
            \\fn foo(x: u32, y: u32) void {
            \\    var i: u32 = 10;
            \\    i = x;
            \\}
        , "10\n");
    }

    {
        var case = ctx.exe("wasm binary operands", wasi);

        case.addCompareOutput(
            \\pub export fn _start() u32 {
            \\    var i: u32 = 5;
            \\    i += 20;
            \\    return i;
            \\}
        , "25\n");

        case.addCompareOutput(
            \\pub export fn _start() u32 {
            \\    var i: u32 = 5;
            \\    i += 20;
            \\    var result: u32 = foo(i, 10);
            \\    return result;
            \\}
            \\fn foo(x: u32, y: u32) u32 {
            \\    return x + y;
            \\}
        , "35\n");

        case.addCompareOutput(
            \\pub export fn _start() u32 {
            \\    var i: u32 = 20;
            \\    i -= 5;
            \\    return i;
            \\}
        , "15\n");

        case.addCompareOutput(
            \\pub export fn _start() u32 {
            \\    var i: u32 = 5;
            \\    i -= 3;
            \\    var result: u32 = foo(i, 10);
            \\    return result;
            \\}
            \\fn foo(x: u32, y: u32) u32 {
            \\    return y - x;
            \\}
        , "8\n");

        case.addCompareOutput(
            \\pub export fn _start() u32 {
            \\    var i: u32 = 5;
            \\    i *= 7;
            \\    var result: u32 = foo(i, 10);
            \\    return result;
            \\}
            \\fn foo(x: u32, y: u32) u32 {
            \\    return x * y;
            \\}
        , "350\n");

        case.addCompareOutput(
            \\pub export fn _start() u32 {
            \\    var i: u32 = 352;
            \\    i /= 7; // i = 50
            \\    var result: u32 = foo(i, 7);
            \\    return result;
            \\}
            \\fn foo(x: u32, y: u32) u32 {
            \\    return x / y;
            \\}
        , "7\n");

        case.addCompareOutput(
            \\pub export fn _start() u32 {
            \\    var i: u32 = 5;
            \\    i &= 6;
            \\    return i;
            \\}
        , "4\n");

        case.addCompareOutput(
            \\pub export fn _start() u32 {
            \\    var i: u32 = 5;
            \\    i |= 6;
            \\    return i;
            \\}
        , "7\n");

        case.addCompareOutput(
            \\pub export fn _start() u32 {
            \\    var i: u32 = 5;
            \\    i ^= 6;
            \\    return i;
            \\}
        , "3\n");

        case.addCompareOutput(
            \\pub export fn _start() bool {
            \\    var b: bool = false;
            \\    b = b or false;
            \\    return b;
            \\}
        , "0\n");

        case.addCompareOutput(
            \\pub export fn _start() bool {
            \\    var b: bool = true;
            \\    b = b or false;
            \\    return b;
            \\}
        , "1\n");

        case.addCompareOutput(
            \\pub export fn _start() bool {
            \\    var b: bool = false;
            \\    b = b or true;
            \\    return b;
            \\}
        , "1\n");

        case.addCompareOutput(
            \\pub export fn _start() bool {
            \\    var b: bool = true;
            \\    b = b or true;
            \\    return b;
            \\}
        , "1\n");

        case.addCompareOutput(
            \\pub export fn _start() bool {
            \\    var b: bool = false;
            \\    b = b and false;
            \\    return b;
            \\}
        , "0\n");

        case.addCompareOutput(
            \\pub export fn _start() bool {
            \\    var b: bool = true;
            \\    b = b and false;
            \\    return b;
            \\}
        , "0\n");

        case.addCompareOutput(
            \\pub export fn _start() bool {
            \\    var b: bool = false;
            \\    b = b and true;
            \\    return b;
            \\}
        , "0\n");

        case.addCompareOutput(
            \\pub export fn _start() bool {
            \\    var b: bool = true;
            \\    b = b and true;
            \\    return b;
            \\}
        , "1\n");
    }

    {
        var case = ctx.exe("wasm conditions", wasi);

        case.addCompareOutput(
            \\pub export fn _start() u32 {
            \\    var i: u32 = 5;
            \\    if (i > @as(u32, 4)) {
            \\        i += 10;
            \\    }
            \\    return i;
            \\}
        , "15\n");

        case.addCompareOutput(
            \\pub export fn _start() u32 {
            \\    var i: u32 = 5;
            \\    if (i < @as(u32, 4)) {
            \\        i += 10;
            \\    } else {
            \\        i = 2;
            \\    }
            \\    return i;
            \\}
        , "2\n");

        case.addCompareOutput(
            \\pub export fn _start() u32 {
            \\    var i: u32 = 5;
            \\    if (i < @as(u32, 4)) {
            \\        i += 10;
            \\    } else if(i == @as(u32, 5)) {
            \\        i = 20;
            \\    }
            \\    return i;
            \\}
        , "20\n");

        case.addCompareOutput(
            \\pub export fn _start() u32 {
            \\    var i: u32 = 11;
            \\    if (i < @as(u32, 4)) {
            \\        i += 10;
            \\    } else {
            \\        if (i > @as(u32, 10)) {
            \\            i += 20;
            \\        } else {
            \\            i = 20;
            \\        }
            \\    }
            \\    return i;
            \\}
        , "31\n");

        case.addCompareOutput(
            \\pub export fn _start() void {
            \\    assert(foo(true) != @as(i32, 30));
            \\}
            \\
            \\fn assert(ok: bool) void {
            \\    if (!ok) unreachable;
            \\}
            \\
            \\fn foo(ok: bool) i32 {
            \\    const x = if(ok) @as(i32, 20) else @as(i32, 10);
            \\    return x;
            \\}
        , "");

        case.addCompareOutput(
            \\pub export fn _start() void {
            \\    assert(foo(false) == @as(i32, 20));
            \\    assert(foo(true) == @as(i32, 30));
            \\}
            \\
            \\fn assert(ok: bool) void {
            \\    if (!ok) unreachable;
            \\}
            \\
            \\fn foo(ok: bool) i32 {
            \\    const val: i32 = blk: {
            \\        var x: i32 = 1;
            \\        if (!ok) break :blk x + @as(i32, 9);
            \\        break :blk x + @as(i32, 19);
            \\    };
            \\    return val + 10;
            \\}
        , "");
    }

    {
        var case = ctx.exe("wasm while loops", wasi);

        case.addCompareOutput(
            \\pub export fn _start() u32 {
            \\    var i: u32 = 0;
            \\    while(i < @as(u32, 5)){
            \\        i += 1;
            \\    }
            \\
            \\    return i;
            \\}
        , "5\n");

        case.addCompareOutput(
            \\pub export fn _start() u32 {
            \\    var i: u32 = 0;
            \\    while(i < @as(u32, 10)){
            \\        var x: u32 = 1;
            \\        i += x;
            \\    }
            \\    return i;
            \\}
        , "10\n");

        case.addCompareOutput(
            \\pub export fn _start() u32 {
            \\    var i: u32 = 0;
            \\    while(i < @as(u32, 10)){
            \\        var x: u32 = 1;
            \\        i += x;
            \\        if (i == @as(u32, 5)) break;
            \\    }
            \\    return i;
            \\}
        , "5\n");
    }

    {
        var case = ctx.exe("wasm enum values", wasi);

        case.addCompareOutput(
            \\const Number = enum { One, Two, Three };
            \\
            \\pub export fn _start() i32 {
            \\    var number1 = Number.One;
            \\    var number2: Number = .Two;
            \\    const number3 = @intToEnum(Number, 2);
            \\
            \\    return @enumToInt(number3);
            \\}
        , "2\n");

        case.addCompareOutput(
            \\const Number = enum { One, Two, Three };
            \\
            \\pub export fn _start() i32 {
            \\    var number1 = Number.One;
            \\    var number2: Number = .Two;
            \\    const number3 = @intToEnum(Number, 2);
            \\    if (number1 == number2) return 1;
            \\    if (number2 == number3) return 1;
            \\    if (@enumToInt(number1) != 0) return 1;
            \\    if (@enumToInt(number2) != 1) return 1;
            \\    if (@enumToInt(number3) != 2) return 1;
            \\    var x: Number = .Two;
            \\    if (number2 != x) return 1;
            \\
            \\    return @enumToInt(number3);
            \\}
        , "2\n");
    }

    {
        var case = ctx.exe("wasm structs", wasi);

        case.addCompareOutput(
            \\const Example = struct { x: u32 };
            \\
            \\pub export fn _start() u32 {
            \\    var example: Example = .{ .x = 5 };
            \\    return example.x;
            \\}
        , "5\n");

        case.addCompareOutput(
            \\const Example = struct { x: u32 };
            \\
            \\pub export fn _start() u32 {
            \\    var example: Example = .{ .x = 5 };
            \\    example.x = 10;
            \\    return example.x;
            \\}
        , "10\n");

        case.addCompareOutput(
            \\const Example = struct { x: u32, y: u32 };
            \\
            \\pub export fn _start() u32 {
            \\    var example: Example = .{ .x = 5, .y = 10 };
            \\    return example.y + example.x;
            \\}
        , "15\n");

        case.addCompareOutput(
            \\const Example = struct { x: u32, y: u32 };
            \\
            \\pub export fn _start() u32 {
            \\    var example: Example = .{ .x = 5, .y = 10 };
            \\    var example2: Example = .{ .x = 10, .y = 20 };
            \\
            \\    example = example2;
            \\    return example.y + example.x;
            \\}
        , "30\n");

        case.addCompareOutput(
            \\const Example = struct { x: u32, y: u32 };
            \\
            \\pub export fn _start() u32 {
            \\    var example: Example = .{ .x = 5, .y = 10 };
            \\
            \\    example = .{ .x = 10, .y = 20 };
            \\    return example.y + example.x;
            \\}
        , "30\n");
    }

    {
        var case = ctx.exe("wasm switch", wasi);

        case.addCompareOutput(
            \\pub export fn _start() u32 {
            \\    var val: u32 = 1;
            \\    var a: u32 = switch (val) {
            \\        0, 1 => 2,
            \\        2 => 3,
            \\        3 => 4,
            \\        else => 5,
            \\    };
            \\
            \\    return a;
            \\}
        , "2\n");

        case.addCompareOutput(
            \\pub export fn _start() u32 {
            \\    var val: u32 = 2;
            \\    var a: u32 = switch (val) {
            \\        0, 1 => 2,
            \\        2 => 3,
            \\        3 => 4,
            \\        else => 5,
            \\    };
            \\
            \\    return a;
            \\}
        , "3\n");

        case.addCompareOutput(
            \\pub export fn _start() u32 {
            \\    var val: u32 = 10;
            \\    var a: u32 = switch (val) {
            \\        0, 1 => 2,
            \\        2 => 3,
            \\        3 => 4,
            \\        else => 5,
            \\    };
            \\
            \\    return a;
            \\}
        , "5\n");

        case.addCompareOutput(
            \\const MyEnum = enum { One, Two, Three };
            \\
            \\pub export fn _start() u32 {
            \\    var val: MyEnum = .Two;
            \\    var a: u32 = switch (val) {
            \\        .One => 1,
            \\        .Two => 2,
            \\        .Three => 3,
            \\    };
            \\
            \\    return a;
            \\}
        , "2\n");
    }

    {
        var case = ctx.exe("wasm error unions", wasi);

        case.addCompareOutput(
            \\pub export fn _start() void {
            \\    var e1 = error.Foo;
            \\    var e2 = error.Bar;
            \\    assert(e1 != e2);
            \\    assert(e1 == error.Foo);
            \\    assert(e2 == error.Bar);
            \\}
            \\
            \\fn assert(b: bool) void {
            \\    if (!b) unreachable;
            \\}
        , "");

        case.addCompareOutput(
            \\pub export fn _start() u32 {
            \\    var e: anyerror!u32 = 5;
            \\    const i = e catch 10;
            \\    return i;
            \\}
        , "5\n");

        case.addCompareOutput(
            \\pub export fn _start() u32 {
            \\    var e: anyerror!u32 = error.Foo;
            \\    const i = e catch 10;
            \\    return i;
            \\}
        , "10\n");

        case.addCompareOutput(
            \\pub export fn _start() u32 {
            \\    var e = foo();
            \\    const i = e catch 69;
            \\    return i;
            \\}
            \\
            \\fn foo() anyerror!u32 {
            \\    return 5;
            \\}
        , "5\n");
    }

    {
        // TODO implement Type equality comparison of error unions in SEMA
        // before we can incrementally compile functions with an error union as return type
        var case = ctx.exe("wasm error union part 2", wasi);

        case.addCompareOutput(
            \\pub export fn _start() u32 {
            \\    var e = foo();
            \\    const i = e catch 69;
            \\    return i;
            \\}
            \\
            \\fn foo() anyerror!u32 {
            \\    return error.Bruh;
            \\}
        , "69\n");
    }
}
