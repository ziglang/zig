pub const Rand = @import("rand.zig").Rand;
pub const io = @import("io.zig");
pub const os = @import("os.zig");
pub const math = @import("math.zig");

pub fn assert(b: bool) {
    if (!b) unreachable{}
}

pub const str_eql = slice_eql(u8);

pub fn slice_eql(T: type)(a: []T, b: []T) -> bool {
    if (a.len != b.len) return false;
    for (a) |item, index| {
        if (b[index] != item) return false;
    }
    return true;
}

#attribute("test")
fn string_equality() {
    assert(str_eql("abcd", "abcd"));
    assert(!str_eql("abcdef", "abZdef"));
    assert(!str_eql("abcdefg", "abcdef"));
}
