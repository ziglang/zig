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


// TODO const assert = @import("std").debug.assert;
fn assert(ok: bool) {
    if (!ok)
        @unreachable();
}
