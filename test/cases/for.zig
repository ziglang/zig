const std = @import("std");
const assert = std.debug.assert;
const str = std.str;

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
    @memcpy(&target[0], &source[0], source.len);
    mangleString(target);
    assert(str.eql(target, "bcdefgh"));
}
fn mangleString(s: []u8) {
    for (s) |*c| {
        *c += 1;
    }
}
