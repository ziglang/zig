const assertOrPanic = @import("std").debug.assertOrPanic;

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
