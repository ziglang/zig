const assert = @import("std").debug.assert;

const S = extern struct {
    x: i32,
};

extern fn ret_struct() S {
    return S{ .x = 42 };
}

test "extern return small struct (bug 1230)" {
    const s = ret_struct();
    assert(s.x == 42);
}
