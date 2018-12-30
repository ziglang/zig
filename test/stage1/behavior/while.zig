const assertOrPanic = @import("std").debug.assertOrPanic;

test "while loop" {
    var i: i32 = 0;
    while (i < 4) {
        i += 1;
    }
    assertOrPanic(i == 4);
    assertOrPanic(whileLoop1() == 1);
}
fn whileLoop1() i32 {
    return whileLoop2();
}
fn whileLoop2() i32 {
    while (true) {
        return 1;
    }
}

test "static eval while" {
    assertOrPanic(static_eval_while_number == 1);
}
const static_eval_while_number = staticWhileLoop1();
fn staticWhileLoop1() i32 {
    return whileLoop2();
}
fn staticWhileLoop2() i32 {
    while (true) {
        return 1;
    }
}

test "continue and break" {
    runContinueAndBreakTest();
    assertOrPanic(continue_and_break_counter == 8);
}
var continue_and_break_counter: i32 = 0;
fn runContinueAndBreakTest() void {
    var i: i32 = 0;
    while (true) {
        continue_and_break_counter += 2;
        i += 1;
        if (i < 4) {
            continue;
        }
        break;
    }
    assertOrPanic(i == 4);
}

test "return with implicit cast from while loop" {
    returnWithImplicitCastFromWhileLoopTest() catch unreachable;
}
fn returnWithImplicitCastFromWhileLoopTest() anyerror!void {
    while (true) {
        return;
    }
}

test "while with continue expression" {
    var sum: i32 = 0;
    {
        var i: i32 = 0;
        while (i < 10) : (i += 1) {
            if (i == 5) continue;
            sum += i;
        }
    }
    assertOrPanic(sum == 40);
}

test "while with else" {
    var sum: i32 = 0;
    var i: i32 = 0;
    var got_else: i32 = 0;
    while (i < 10) : (i += 1) {
        sum += 1;
    } else {
        got_else += 1;
    }
    assertOrPanic(sum == 10);
    assertOrPanic(got_else == 1);
}

