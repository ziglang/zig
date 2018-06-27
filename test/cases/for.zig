const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;

test "continue in for loop" {
    const array = []i32{
        1,
        2,
        3,
        4,
        5,
    };
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

test "for loop with pointer elem var" {
    const source = "abcdefg";
    var target: [source.len]u8 = undefined;
    mem.copy(u8, target[0..], source);
    mangleString(target[0..]);
    assert(mem.eql(u8, target, "bcdefgh"));
}
fn mangleString(s: []u8) void {
    for (s) |*c| {
        c.* += 1;
    }
}

test "basic for loop" {
    const expected_result = []u8{ 9, 8, 7, 6, 0, 1, 2, 3, 9, 8, 7, 6, 0, 1, 2, 3 };

    var buffer: [expected_result.len]u8 = undefined;
    var buf_index: usize = 0;

    const array = []u8{ 9, 8, 7, 6 };
    for (array) |item| {
        buffer[buf_index] = item;
        buf_index += 1;
    }
    for (array) |item, index| {
        buffer[buf_index] = @intCast(u8, index);
        buf_index += 1;
    }
    const unknown_size: []const u8 = array;
    for (unknown_size) |item| {
        buffer[buf_index] = item;
        buf_index += 1;
    }
    for (unknown_size) |item, index| {
        buffer[buf_index] = @intCast(u8, index);
        buf_index += 1;
    }

    assert(mem.eql(u8, buffer[0..buf_index], expected_result));
}

test "break from outer for loop" {
    testBreakOuter();
    comptime testBreakOuter();
}

fn testBreakOuter() void {
    var array = "aoeu";
    var count: usize = 0;
    outer: for (array) |_| {
        // TODO shouldn't get error for redeclaring "_"
        for (array) |_2| {
            count += 1;
            break :outer;
        }
    }
    assert(count == 1);
}

test "continue outer for loop" {
    testContinueOuter();
    comptime testContinueOuter();
}

fn testContinueOuter() void {
    var array = "aoeu";
    var counter: usize = 0;
    outer: for (array) |_| {
        // TODO shouldn't get error for redeclaring "_"
        for (array) |_2| {
            counter += 1;
            continue :outer;
        }
    }
    assert(counter == array.len);
}
