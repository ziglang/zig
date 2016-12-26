fn compileTimeRecursion() {
    @setFnTest(this);

    assert(some_data.len == 21);
}
var some_data: [usize(fibbonaci(7))]u8 = undefined;
fn fibbonaci(x: i32) -> i32 {
    if (x <= 1) return 1;
    return fibbonaci(x - 1) + fibbonaci(x - 2);
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


fn staticFunctionEvaluation() {
    @setFnTest(this);

    assert(statically_added_number == 3);
}
const statically_added_number = staticAdd(1, 2);
fn staticAdd(a: i32, b: i32) -> i32 { a + b }


fn constExprEvalOnSingleExprBlocks() {
    @setFnTest(this);

    assert(constExprEvalOnSingleExprBlocksFn(1, true) == 3);
}

fn constExprEvalOnSingleExprBlocksFn(x: i32, b: bool) -> i32 {
    const literal = 3;

    const result = if (b) {
        literal
    } else {
        x
    };

    return result;
}





// TODO const assert = @import("std").debug.assert;
fn assert(ok: bool) {
    if (!ok)
        @unreachable();
}

