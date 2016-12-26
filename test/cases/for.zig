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
    assert(memeql(target, "bcdefgh"));
}
fn mangleString(s: []u8) {
    for (s) |*c| {
        *c += 1;
    }
}


// TODO import from std.str
pub fn memeql(a: []const u8, b: []const u8) -> bool {
    sliceEql(u8, a, b)
}

// TODO import from std.str
pub fn sliceEql(inline T: type, a: []const T, b: []const T) -> bool {
    if (a.len != b.len) return false;
    for (a) |item, index| {
        if (b[index] != item) return false;
    }
    return true;
}

// TODO const assert = @import("std").debug.assert;
fn assert(ok: bool) {
    if (!ok)
        @unreachable();
}
