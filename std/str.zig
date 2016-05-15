const assert = @import("index.zig").assert;

pub const concat = join(u8);
pub const eql = slice_eql(u8);

pub fn slice_eql(T: type)(a: []const T, b: []const T) -> bool {
    if (a.len != b.len) return false;
    for (a) |item, index| {
        if (b[index] != item) return false;
    }
    return true;
}

pub fn join(T: type)(a: []T, b: []T) -> []T {
    var result : [a.len + b.len]T = undefined;

    @memcpy(result.ptr, a.ptr, a.len * @sizeof(T));
    @memcpy((&T)((usize)(result.ptr) + (usize)(a.len * @sizeof(T))), b.ptr, b.len * @sizeof(T));

    return result;
}

#attribute("test")
fn string_equality() {
    assert(eql("abcd", "abcd"));
    assert(!eql("abcdef", "abZdef"));
    assert(!eql("abcdefg", "abcdef"));
}
