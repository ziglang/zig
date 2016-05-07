const assert = @import("index.zig").assert;

pub const eql = slice_eql(u8);

pub fn slice_eql(T: type)(a: []const T, b: []const T) -> bool {
    if (a.len != b.len) return false;
    for (a) |item, index| {
        if (b[index] != item) return false;
    }
    return true;
}

#attribute("test")
fn string_equality() {
    assert(eql("abcd", "abcd"));
    assert(!eql("abcdef", "abZdef"));
    assert(!eql("abcdefg", "abcdef"));
}
