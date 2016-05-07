const assert = @import("index.zig").assert;

// fix https://github.com/andrewrk/zig/issues/140
// and then make this able to run at compile time
#static_eval_enable(false)
pub fn len(ptr: &const u8) -> isize {
    var count: isize = 0;
    while (ptr[count] != 0; count += 1) {}
    return count;
}

pub fn from_c_const(str: &const u8) -> []const u8 {
    return str[0...len(str)];
}

pub fn from_c(str: &u8) -> []u8 {
    return str[0...len(str)];
}

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
