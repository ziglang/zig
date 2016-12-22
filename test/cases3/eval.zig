fn fib(x: i32) -> i32 {
    if (x < 2) x else fib(x - 1) + fib(x - 2)
}
const fib_7 = fib(7);
fn compileTimeFib() {
    @setFnTest(this);
    assert(fib_7 == 13);
}


fn unwrapAndAddOne(blah: ?i32) -> i32 {
    return ??blah + 1;
}
const should_be_1235 = unwrapAndAddOne(1234);
fn testStaticAddOne() {
    @setFnTest(this);
    assert(should_be_1235 == 1235);
}

fn inlinedLoop() {
    @setFnTest(this);

    inline var i = 0;
    inline var sum = 0;
    inline while (i <= 5; i += 1)
        sum += i;
    assert(sum == 15);
}

fn gimme1or2(inline a: bool) -> i32 {
    const x: i32 = 1;
    const y: i32 = 2;
    inline var z: i32 = if (a) x else y;
    return z;
}
fn inlineVariableGetsResultOfConstIf() {
    @setFnTest(this);
    assert(gimme1or2(true) == 1);
    assert(gimme1or2(false) == 2);
}



// TODO const assert = @import("std").debug.assert;
fn assert(ok: bool) {
    if (!ok)
        @unreachable();
}

