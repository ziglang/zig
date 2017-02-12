const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;

fn continueInForLoop() {
    @setFnTest(this);

    const array = []i32 {1, 2, 3, 4, 5};
    var sum : i32 = 0;
    for (array) |x| {
        sum += x;
        if (x < 3) {
            continue;
        }
        break;
    }
    if (sum != 6) @unreachable()
}

fn forLoopWithPointerElemVar() {
    @setFnTest(this);

    const source = "abcdefg";
    var target: [source.len]u8 = undefined;
    mem.copy(u8, target[0...], source);
    mangleString(target[0...]);
    assert(mem.eql(u8, target, "bcdefgh"));
}
fn mangleString(s: []u8) {
    for (s) |*c| {
        *c += 1;
    }
}

fn basicForLoop() {
    @setFnTest(this);

    const expected_result = []u8{9, 8, 7, 6, 0, 1, 2, 3, 9, 8, 7, 6, 0, 1, 2, 3 };

    var buffer: [expected_result.len]u8 = undefined;
    var buf_index: usize = 0;

    const array = []u8 {9, 8, 7, 6};
    for (array) |item| {
        buffer[buf_index] = item;
        buf_index += 1;
    }
    for (array) |item, index| {
        buffer[buf_index] = u8(index);
        buf_index += 1;
    }
    const unknown_size: []const u8 = array;
    for (unknown_size) |item| {
        buffer[buf_index] = item;
        buf_index += 1;
    }
    for (unknown_size) |item, index| {
        buffer[buf_index] = u8(index);
        buf_index += 1;
    }

    assert(mem.eql(u8, buffer[0...buf_index], expected_result));
}
