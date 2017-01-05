const assert = @import("std").debug.assert;

fn whileLoop() {
    @setFnTest(this);

    var i : i32 = 0;
    while (i < 4) {
        i += 1;
    }
    assert(i == 4);
    assert(whileLoop1() == 1);
}
fn whileLoop1() -> i32 {
    return whileLoop2();
}
fn whileLoop2() -> i32 {
    while (true) {
        return 1;
    }
}
fn staticEvalWhile() {
    @setFnTest(this);

    assert(static_eval_while_number == 1);
}
const static_eval_while_number = staticWhileLoop1();
fn staticWhileLoop1() -> i32 {
    return whileLoop2();
}
fn staticWhileLoop2() -> i32 {
    while (true) {
        return 1;
    }
}

fn continueAndBreak() {
    @setFnTest(this);

    runContinueAndBreakTest();
    assert(continue_and_break_counter == 8);
}
var continue_and_break_counter: i32 = 0;
fn runContinueAndBreakTest() {
    var i : i32 = 0;
    while (true) {
        continue_and_break_counter += 2;
        i += 1;
        if (i < 4) {
            continue;
        }
        break;
    }
    assert(i == 4);
}

fn returnWithImplicitCastFromWhileLoop() {
    @setFnTest(this);

    %%returnWithImplicitCastFromWhileLoopTest();
}
fn returnWithImplicitCastFromWhileLoopTest() -> %void {
    while (true) {
        return;
    }
}

fn whileWithContinueExpr() {
    @setFnTest(this);

    var sum: i32 = 0;
    {var i: i32 = 0; while (i < 10; i += 1) {
        if (i == 5) continue;
        sum += i;
    }}
    assert(sum == 40);
}
