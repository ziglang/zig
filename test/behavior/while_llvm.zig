const std = @import("std");
const expect = std.testing.expect;

test "while with optional as condition" {
    numbers_left = 10;
    var sum: i32 = 0;
    while (getNumberOrNull()) |value| {
        sum += value;
    }
    try expect(sum == 45);
}

test "while with optional as condition with else" {
    numbers_left = 10;
    var sum: i32 = 0;
    var got_else: i32 = 0;
    while (getNumberOrNull()) |value| {
        sum += value;
        try expect(got_else == 0);
    } else {
        got_else += 1;
    }
    try expect(sum == 45);
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
