const assert = @import("debug.zig").assert;

pub fn eql(a: []const u8, b: []const u8) -> bool {
    sliceEql(u8, a, b)
}

pub fn sliceEql(inline T: type, a: []const T, b: []const T) -> bool {
    if (a.len != b.len) return false;
    for (a) |item, index| {
        if (b[index] != item) return false;
    }
    return true;
}

fn testStringEquality() {
    @setFnTest(this, true);

    assert(eql("abcd", "abcd"));
    assert(!eql("abcdef", "abZdef"));
    assert(!eql("abcdefg", "abcdef"));
}
