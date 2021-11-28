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
            \\pub fn main() u8 {
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
            \\pub fn main() u8 {
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
            \\pub fn main() void {
            \\    bar();
            \\    foo();
            \\    return;
            \\}
            \\fn foo() void {
            \\    bar();
            \\    bar();
            \\    bar();
            \\}
            \\fn bar() void {}
        ,
            "0\n",
        );

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    foo(10, 20);
            \\    return 5;
            \\}
            \\fn foo(x: u8, y: u8) void { _ = x; _ = y; }
        , "5\n");
    }

    {
        var case = ctx.exe("wasm locals", wasi);

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var i: u8 = 5;
            \\    var y: f32 = 42.0;
            \\    var x: u8 = 10;
            \\    if (false) {
            \\      y;
            \\      x;
            \\    }
            \\    return i;
            \\}
        , "5\n");

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var i: u8 = 5;
            \\    var y: f32 = 42.0;
            \\    _ = y;
            \\    var x: u8 = 10;
            \\    foo(i, x);
            \\    i = x;
            \\    return i;
            \\}
            \\fn foo(x: u8, y: u8) void {
            \\    _  = y;
            \\    var i: u8 = 10;
            \\    i = x;
            \\}
        , "10\n");
    }

    {
        var case = ctx.exe("wasm binary operands", wasi);

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var i: u8 = 5;
            \\    i += 20;
            \\    return i;
            \\}
        , "25\n");

        case.addCompareOutput(
            \\pub fn main() void {
            \\    var i: i32 = 2147483647;
            \\    if (i +% 1 != -2147483648) unreachable;
            \\    return;
            \\}
        , "0\n");

        case.addCompareOutput(
            \\pub fn main() void {
            \\    var i: i4 = 7;
            \\    if (i +% 1 != 0) unreachable;
            \\    return;
            \\}
        , "0\n");

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var i: u8 = 255;
            \\    return i +% 1;
            \\}
        , "0\n");

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var i: u8 = 5;
            \\    i += 20;
            \\    var result: u8 = foo(i, 10);
            \\    return result;
            \\}
            \\fn foo(x: u8, y: u8) u8 {
            \\    return x + y;
            \\}
        , "35\n");

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var i: u8 = 20;
            \\    i -= 5;
            \\    return i;
            \\}
        , "15\n");

        case.addCompareOutput(
            \\pub fn main() void {
            \\    var i: i32 = -2147483648;
            \\    if (i -% 1 != 2147483647) unreachable;
            \\    return;
            \\}
        , "0\n");

        case.addCompareOutput(
            \\pub fn main() void {
            \\    var i: i7 = -64;
            \\    if (i -% 1 != 63) unreachable;
            \\    return;
            \\}
        , "0\n");

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var i: u4 = 0;
            \\    return i -% 1;
            \\}
        , "15\n");

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var i: u8 = 5;
            \\    i -= 3;
            \\    var result: u8 = foo(i, 10);
            \\    return result;
            \\}
            \\fn foo(x: u8, y: u8) u8 {
            \\    return y - x;
            \\}
        , "8\n");

        case.addCompareOutput(
            \\pub fn main() void {
            \\    var i: u32 = 5;
            \\    i *= 7;
            \\    var result: u32 = foo(i, 10);
            \\    if (result != 350) unreachable;
            \\    return;
            \\}
            \\fn foo(x: u32, y: u32) u32 {
            \\    return x * y;
            \\}
        , "0\n");

        case.addCompareOutput(
            \\pub fn main() void {
            \\    var i: i32 = 2147483647;
            \\    const result = i *% 2;
            \\    if (result != -2) unreachable;
            \\    return;
            \\}
        , "0\n");

        case.addCompareOutput(
            \\pub fn main() void {
            \\    var i: u3 = 3;
            \\    if (i *% 3 != 1) unreachable;
            \\    return;
            \\}
        , "0\n");

        case.addCompareOutput(
            \\pub fn main() void {
            \\    var i: i4 = 3;
            \\    if (i *% 3 != 1) unreachable;
            \\    return;
            \\}
        , "0\n");

        case.addCompareOutput(
            \\pub fn main() void {
            \\    var i: u32 = 352;
            \\    i /= 7; // i = 50
            \\    var result: u32 = foo(i, 7);
            \\    if (result != 7) unreachable;
            \\    return;
            \\}
            \\fn foo(x: u32, y: u32) u32 {
            \\    return x / y;
            \\}
        , "0\n");

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var i: u8 = 5;
            \\    i &= 6;
            \\    return i;
            \\}
        , "4\n");

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var i: u8 = 5;
            \\    i |= 6;
            \\    return i;
            \\}
        , "7\n");

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var i: u8 = 5;
            \\    i ^= 6;
            \\    return i;
            \\}
        , "3\n");

        case.addCompareOutput(
            \\pub fn main() void {
            \\    var b: bool = false;
            \\    b = b or false;
            \\    if (b) unreachable;
            \\    return;
            \\}
        , "0\n");

        case.addCompareOutput(
            \\pub fn main() void {
            \\    var b: bool = true;
            \\    b = b or false;
            \\    if (!b) unreachable;
            \\    return;
            \\}
        , "0\n");

        case.addCompareOutput(
            \\pub fn main() void {
            \\    var b: bool = false;
            \\    b = b or true;
            \\    if (!b) unreachable;
            \\    return;
            \\}
        , "0\n");

        case.addCompareOutput(
            \\pub fn main() void {
            \\    var b: bool = true;
            \\    b = b or true;
            \\    if (!b) unreachable;
            \\    return;
            \\}
        , "0\n");

        case.addCompareOutput(
            \\pub fn main() void {
            \\    var b: bool = false;
            \\    b = b and false;
            \\    if (b) unreachable;
            \\    return;
            \\}
        , "0\n");

        case.addCompareOutput(
            \\pub fn main() void {
            \\    var b: bool = true;
            \\    b = b and false;
            \\    if (b) unreachable;
            \\    return;
            \\}
        , "0\n");

        case.addCompareOutput(
            \\pub fn main() void {
            \\    var b: bool = false;
            \\    b = b and true;
            \\    if (b) unreachable;
            \\    return;
            \\}
        , "0\n");

        case.addCompareOutput(
            \\pub fn main() void {
            \\    var b: bool = true;
            \\    b = b and true;
            \\    if (!b) unreachable;
            \\    return;
            \\}
        , "0\n");
    }

    {
        var case = ctx.exe("wasm conditions", wasi);

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var i: u8 = 5;
            \\    if (i > @as(u8, 4)) {
            \\        i += 10;
            \\    }
            \\    return i;
            \\}
        , "15\n");

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var i: u8 = 5;
            \\    if (i < @as(u8, 4)) {
            \\        i += 10;
            \\    } else {
            \\        i = 2;
            \\    }
            \\    return i;
            \\}
        , "2\n");

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var i: u8 = 5;
            \\    if (i < @as(u8, 4)) {
            \\        i += 10;
            \\    } else if(i == @as(u8, 5)) {
            \\        i = 20;
            \\    }
            \\    return i;
            \\}
        , "20\n");

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var i: u8 = 11;
            \\    if (i < @as(u8, 4)) {
            \\        i += 10;
            \\    } else {
            \\        if (i > @as(u8, 10)) {
            \\            i += 20;
            \\        } else {
            \\            i = 20;
            \\        }
            \\    }
            \\    return i;
            \\}
        , "31\n");

        case.addCompareOutput(
            \\pub fn main() void {
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
        , "0\n");

        case.addCompareOutput(
            \\pub fn main() void {
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
        , "0\n");
    }

    {
        var case = ctx.exe("wasm while loops", wasi);

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var i: u8 = 0;
            \\    while(i < @as(u8, 5)){
            \\        i += 1;
            \\    }
            \\
            \\    return i;
            \\}
        , "5\n");

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var i: u8 = 0;
            \\    while(i < @as(u8, 10)){
            \\        var x: u8 = 1;
            \\        i += x;
            \\    }
            \\    return i;
            \\}
        , "10\n");

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var i: u8 = 0;
            \\    while(i < @as(u8, 10)){
            \\        var x: u8 = 1;
            \\        i += x;
            \\        if (i == @as(u8, 5)) break;
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
            \\pub fn main() void {
            \\    var number1 = Number.One;
            \\    var number2: Number = .Two;
            \\    if (false) {
            \\        number1;
            \\        number2;
            \\    }
            \\    const number3 = @intToEnum(Number, 2);
            \\    if (@enumToInt(number3) != 2) {
            \\        unreachable;
            \\    }
            \\    return;
            \\}
        , "0\n");

        case.addCompareOutput(
            \\const Number = enum { One, Two, Three };
            \\
            \\pub fn main() void {
            \\    var number1 = Number.One;
            \\    var number2: Number = .Two;
            \\    const number3 = @intToEnum(Number, 2);
            \\    assert(number1 != number2);
            \\    assert(number2 != number3);
            \\    assert(@enumToInt(number1) == 0);
            \\    assert(@enumToInt(number2) == 1);
            \\    assert(@enumToInt(number3) == 2);
            \\    var x: Number = .Two;
            \\    assert(number2 == x);
            \\
            \\    return;
            \\}
            \\fn assert(val: bool) void {
            \\    if(!val) unreachable;
            \\}
        , "0\n");
    }

    {
        var case = ctx.exe("wasm structs", wasi);

        case.addCompareOutput(
            \\const Example = struct { x: u8 };
            \\
            \\pub fn main() u8 {
            \\    var example: Example = .{ .x = 5 };
            \\    return example.x;
            \\}
        , "5\n");

        case.addCompareOutput(
            \\const Example = struct { x: u8 };
            \\
            \\pub fn main() u8 {
            \\    var example: Example = .{ .x = 5 };
            \\    example.x = 10;
            \\    return example.x;
            \\}
        , "10\n");

        case.addCompareOutput(
            \\const Example = struct { x: u8, y: u8 };
            \\
            \\pub fn main() u8 {
            \\    var example: Example = .{ .x = 5, .y = 10 };
            \\    return example.y + example.x;
            \\}
        , "15\n");

        case.addCompareOutput(
            \\const Example = struct { x: u8, y: u8 };
            \\
            \\pub fn main() u8 {
            \\    var example: Example = .{ .x = 5, .y = 10 };
            \\    var example2: Example = .{ .x = 10, .y = 20 };
            \\
            \\    example = example2;
            \\    return example.y + example.x;
            \\}
        , "30\n");

        case.addCompareOutput(
            \\const Example = struct { x: u8, y: u8 };
            \\
            \\pub fn main() u8 {
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
            \\pub fn main() u8 {
            \\    var val: u8 = 1;
            \\    var a: u8 = switch (val) {
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
            \\pub fn main() u8 {
            \\    var val: u8 = 2;
            \\    var a: u8 = switch (val) {
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
            \\pub fn main() u8 {
            \\    var val: u8 = 10;
            \\    var a: u8 = switch (val) {
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
            \\pub fn main() u8 {
            \\    var val: MyEnum = .Two;
            \\    var a: u8 = switch (val) {
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
            \\pub fn main() void {
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
        , "0\n");

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var e: anyerror!u8 = 5;
            \\    const i = e catch 10;
            \\    return i;
            \\}
        , "5\n");

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var e: anyerror!u8 = error.Foo;
            \\    const i = e catch 10;
            \\    return i;
            \\}
        , "10\n");

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var e = foo();
            \\    const i = e catch 69;
            \\    return i;
            \\}
            \\
            \\fn foo() anyerror!u8 {
            \\    return 5;
            \\}
        , "5\n");
    }

    {
        var case = ctx.exe("wasm error union part 2", wasi);

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var e = foo();
            \\    const i = e catch 69;
            \\    return i;
            \\}
            \\
            \\fn foo() anyerror!u8 {
            \\    return error.Bruh;
            \\}
        , "69\n");
        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var e = foo();
            \\    const i = e catch 42;
            \\    return i;
            \\}
            \\
            \\fn foo() anyerror!u8 {
            \\    return error.Dab;
            \\}
        , "42\n");
    }

    {
        var case = ctx.exe("wasm integer widening", wasi);

        case.addCompareOutput(
            \\pub fn main() void{
            \\    var x: u8 = 5;
            \\    var y: u64 = x;
            \\    _ = y;
            \\    return;
            \\}
        , "0\n");
    }

    {
        var case = ctx.exe("wasm optionals", wasi);

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var x: ?u8 = 5;
            \\    var y: u8 = 0;
            \\    if (x) |val| {
            \\        y = val;
            \\    }
            \\    return y;
            \\}
        , "5\n");

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var x: ?u8 = null;
            \\    var y: u8 = 0;
            \\    if (x) |val| {
            \\        y = val;
            \\    }
            \\    return y;
            \\}
        , "0\n");

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var x: ?u8 = 5;
            \\    return x.?;
            \\}
        , "5\n");

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var x: u8 = 5;
            \\    var y: ?u8 = x;
            \\    return y.?;
            \\}
        , "5\n");

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var val: ?u8 = 5;
            \\    while (val) |*v| {
            \\        v.* -= 1;
            \\        if (v.* == 2) {
            \\            val = null;
            \\        }
            \\    }
            \\    return 0;
            \\}
        , "0\n");
    }

    {
        var case = ctx.exe("wasm pointers", wasi);

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var x: u8 = 0;
            \\
            \\    foo(&x);
            \\    return x;
            \\}
            \\
            \\fn foo(x: *u8)void {
            \\    x.* = 2;
            \\}
        , "2\n");

        case.addCompareOutput(
            \\pub fn main() u8 {
            \\    var x: u8 = 0;
            \\
            \\    foo(&x);
            \\    bar(&x);
            \\    return x;
            \\}
            \\
            \\fn foo(x: *u8)void {
            \\    x.* = 2;
            \\}
            \\
            \\fn bar(x: *u8) void {
            \\    x.* += 2;
            \\}
        , "4\n");
    }
}
