const assertOrPanic = @import("std").debug.assertOrPanic;

test "while with error union condition" {
    numbers_left = 10;
    var sum: i32 = 0;
    var got_else: i32 = 0;
    while (getNumberOrErr()) |value| {
        sum += value;
    } else |err| {
        assertOrPanic(err == error.OutOfNumbers);
        got_else += 1;
    }
    assertOrPanic(sum == 45);
    assertOrPanic(got_else == 1);
}

var numbers_left: i32 = undefined;
fn getNumberOrErr() anyerror!i32 {
    return if (numbers_left == 0) error.OutOfNumbers else x: {
        numbers_left -= 1;
        break :x numbers_left;
    };
}
fn getNumberOrNull() ?i32 {
    return if (numbers_left == 0) null else x: {
        numbers_left -= 1;
        break :x numbers_left;
    };
}

test "while on optional with else result follow else prong" {
    const result = while (returnNull()) |value| {
        break value;
    } else
        i32(2);
    assertOrPanic(result == 2);
}

test "while on optional with else result follow break prong" {
    const result = while (returnOptional(10)) |value| {
        break value;
    } else
        i32(2);
    assertOrPanic(result == 10);
}

test "while on error union with else result follow else prong" {
    const result = while (returnError()) |value| {
        break value;
    } else |err|
        i32(2);
    assertOrPanic(result == 2);
}

test "while on error union with else result follow break prong" {
    const result = while (returnSuccess(10)) |value| {
        break value;
    } else |err|
        i32(2);
    assertOrPanic(result == 10);
}

test "while on bool with else result follow else prong" {
    const result = while (returnFalse()) {
        break i32(10);
    } else
        i32(2);
    assertOrPanic(result == 2);
}

test "while on bool with else result follow break prong" {
    const result = while (returnTrue()) {
        break i32(10);
    } else
        i32(2);
    assertOrPanic(result == 10);
}

test "break from outer while loop" {
    testBreakOuter();
    comptime testBreakOuter();
}

fn testBreakOuter() void {
    outer: while (true) {
        while (true) {
            break :outer;
        }
    }
}

test "continue outer while loop" {
    testContinueOuter();
    comptime testContinueOuter();
}

fn testContinueOuter() void {
    var i: usize = 0;
    outer: while (i < 10) : (i += 1) {
        while (true) {
            continue :outer;
        }
    }
}

fn returnNull() ?i32 {
    return null;
}
fn returnOptional(x: i32) ?i32 {
    return x;
}
fn returnError() anyerror!i32 {
    return error.YouWantedAnError;
}
fn returnSuccess(x: i32) anyerror!i32 {
    return x;
}
fn returnFalse() bool {
    return false;
}
fn returnTrue() bool {
    return true;
}
