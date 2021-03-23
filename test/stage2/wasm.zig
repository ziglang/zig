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
            \\export fn _start() u32 {
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
            \\export fn _start() i64 {
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
            \\export fn _start() f32 {
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
        // This is what you get when you take the bits of the IEE-754
        // representation of 42.0 and reinterpret them as an unsigned
        // integer. Guess that's a bug in wasmtime.
            "1109917696\n",
        );

        case.addCompareOutput(
            \\export fn _start() u32 {
            \\    foo(10, 20);
            \\    return 5;
            \\}
            \\fn foo(x: u32, y: u32) void {}
        , "5\n");
    }

    {
        var case = ctx.exe("wasm locals", wasi);

        case.addCompareOutput(
            \\export fn _start() u32 {
            \\    var i: u32 = 5;
            \\    var y: f32 = 42.0;
            \\    var x: u32 = 10;
            \\    return i;
            \\}
        , "5\n");

        case.addCompareOutput(
            \\export fn _start() u32 {
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
            \\export fn _start() u32 {
            \\    var i: u32 = 5;
            \\    i += 20;
            \\    return i;
            \\}
        , "25\n");

        case.addCompareOutput(
            \\export fn _start() u32 {
            \\    var i: u32 = 5;
            \\    i += 20;
            \\    var result: u32 = foo(i, 10);
            \\    return result;
            \\}
            \\fn foo(x: u32, y: u32) u32 {
            \\    return x + y;
            \\}
        , "35\n");
    }

    {
        var case = ctx.exe("wasm conditions", wasi);

        case.addCompareOutput(
            \\export fn _start() u32 {
            \\    var i: u32 = 5;
            \\    if (i > @as(u32, 4)) {
            \\        i += 10;
            \\    }
            \\    return i;
            \\}
        , "15\n");

        case.addCompareOutput(
            \\export fn _start() u32 {
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
            \\export fn _start() u32 {
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
            \\export fn _start() u32 {
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
            \\export fn _start() void {
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
            \\export fn _start() void {
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
            \\export fn _start() u32 {
            \\    var i: u32 = 0;
            \\    while(i < @as(u32, 5)){
            \\        i += 1;
            \\    }
            \\
            \\    return i;
            \\}
        , "5\n");

        case.addCompareOutput(
            \\export fn _start() u32 {
            \\    var i: u32 = 0;
            \\    while(i < @as(u32, 10)){
            \\        var x: u32 = 1;
            \\        i += x;
            \\    }
            \\    return i;
            \\}
        , "10\n");

        case.addCompareOutput(
            \\export fn _start() u32 {
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
}
