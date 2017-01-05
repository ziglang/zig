const assert = @import("std").debug.assert;

fn params() {
    @setFnTest(this);

    assert(testParamsAdd(22, 11) == 33);
}
fn testParamsAdd(a: i32, b: i32) -> i32 {
    a + b
}


fn localVariables() {
    @setFnTest(this);

    testLocVars(2);
}
fn testLocVars(b: i32) {
    const a: i32 = 1;
    if (a + b != 3) @unreachable();
}


fn voidParameters() {
    @setFnTest(this);

    voidFun(1, void{}, 2, {});
}
fn voidFun(a: i32, b: void, c: i32, d: void) {
    const v = b;
    const vv: void = if (a == 1) {v} else {};
    assert(a + c == 3);
    return vv;
}


fn mutableLocalVariables() {
    @setFnTest(this);

    var zero : i32 = 0;
    assert(zero == 0);

    var i = i32(0);
    while (i != 3) {
        i += 1;
    }
    assert(i == 3);
}

fn separateBlockScopes() {
    @setFnTest(this);

    {
        const no_conflict : i32 = 5;
        assert(no_conflict == 5);
    }

    const c = {
        const no_conflict = i32(10);
        no_conflict
    };
    assert(c == 10);
}

fn callFnWithEmptyString() {
    @setFnTest(this);

    acceptsString("");
}

fn acceptsString(foo: []u8) { }


fn @"weird function name"() {
    @setFnTest(this);
}

fn implicitCastFnUnreachableReturn() {
    @setFnTest(this);

    wantsFnWithVoid(fnWithUnreachable);
}

fn wantsFnWithVoid(f: fn()) { }

fn fnWithUnreachable() -> unreachable {
    @unreachable()
}


fn functionPointers() {
    @setFnTest(this);

    const fns = []@typeOf(fn1) { fn1, fn2, fn3, fn4, };
    for (fns) |f, i| {
        assert(f() == u32(i) + 5);
    }
}
fn fn1() -> u32 {5}
fn fn2() -> u32 {6}
fn fn3() -> u32 {7}
fn fn4() -> u32 {8}
