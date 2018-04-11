const assert = @import("std").debug.assert;

test "params" {
    assert(testParamsAdd(22, 11) == 33);
}
fn testParamsAdd(a: i32, b: i32) i32 {
    return a + b;
}


test "local variables" {
    testLocVars(2);
}
fn testLocVars(b: i32) void {
    const a: i32 = 1;
    if (a + b != 3) unreachable;
}


test "void parameters" {
    voidFun(1, void{}, 2, {});
}
fn voidFun(a: i32, b: void, c: i32, d: void) void {
    const v = b;
    const vv: void = if (a == 1) v else {};
    assert(a + c == 3);
    return vv;
}


test "mutable local variables" {
    var zero : i32 = 0;
    assert(zero == 0);

    var i = i32(0);
    while (i != 3) {
        i += 1;
    }
    assert(i == 3);
}

test "separate block scopes" {
    {
        const no_conflict : i32 = 5;
        assert(no_conflict == 5);
    }

    const c = x: {
        const no_conflict = i32(10);
        break :x no_conflict;
    };
    assert(c == 10);
}

test "call function with empty string" {
    acceptsString("");
}

fn acceptsString(foo: []u8) void { }


fn @"weird function name"() i32 {
    return 1234;
}
test "weird function name" {
    assert(@"weird function name"() == 1234);
}

test "implicit cast function unreachable return" {
    wantsFnWithVoid(fnWithUnreachable);
}

fn wantsFnWithVoid(f: fn() void) void { }

fn fnWithUnreachable() noreturn {
    unreachable;
}


test "function pointers" {
    const fns = []@typeOf(fn1) { fn1, fn2, fn3, fn4, };
    for (fns) |f, i| {
        assert(f() == u32(i) + 5);
    }
}
fn fn1() u32 {return 5;}
fn fn2() u32 {return 6;}
fn fn3() u32 {return 7;}
fn fn4() u32 {return 8;}


test "inline function call" {
    assert(@inlineCall(add, 3, 9) == 12);
}

fn add(a: i32, b: i32) i32 { return a + b; }


test "number literal as an argument" {
    numberLiteralArg(3);
    comptime numberLiteralArg(3);
}

fn numberLiteralArg(a: var) void {
    assert(a == 3);
}
