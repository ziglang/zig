const std = @import("std");
const expect = std.testing.expect;

test "while loop" {
    var i: i32 = 0;
    while (i < 4) {
        i += 1;
    }
    try expect(i == 4);
    try expect(whileLoop1() == 1);
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
    try expect(static_eval_while_number == 1);
}
const static_eval_while_number = staticWhileLoop1();
fn staticWhileLoop1() i32 {
    return staticWhileLoop2();
}
fn staticWhileLoop2() i32 {
    while (true) {
        return 1;
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
    try expect(sum == 40);
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
    try expect(sum == 10);
    try expect(got_else == 1);
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

test "while copies its payload" {
    const S = struct {
        fn doTheTest() !void {
            var tmp: ?i32 = 10;
            while (tmp) |value| {
                // Modify the original variable
                tmp = null;
                try expect(value == 10);
            }
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}
