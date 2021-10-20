const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const mem = std.mem;

test "continue in for loop" {
    const array = [_]i32{ 1, 2, 3, 4, 5 };
    var sum: i32 = 0;
    for (array) |x| {
        sum += x;
        if (x < 3) {
            continue;
        }
        break;
    }
    if (sum != 6) unreachable;
}

test "break from outer for loop" {
    try testBreakOuter();
    comptime try testBreakOuter();
}

fn testBreakOuter() !void {
    var array = "aoeu";
    var count: usize = 0;
    outer: for (array) |_| {
        for (array) |_| {
            count += 1;
            break :outer;
        }
    }
    try expect(count == 1);
}

test "continue outer for loop" {
    try testContinueOuter();
    comptime try testContinueOuter();
}

fn testContinueOuter() !void {
    var array = "aoeu";
    var counter: usize = 0;
    outer: for (array) |_| {
        for (array) |_| {
            counter += 1;
            continue :outer;
        }
    }
    try expect(counter == array.len);
}

test "ignore lval with underscore (for loop)" {
    for ([_]void{}) |_, i| {
        _ = i;
        for ([_]void{}) |_, j| {
            _ = j;
            break;
        }
        break;
    }
}
