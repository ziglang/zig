const assert = @import("std").debug.assert;

enum FormValue {
    One,
    Two: bool,
}

error Whatever;

#static_eval_enable(false)
fn foo(id: u64) -> %FormValue {
    switch (id) {
        2 => FormValue.Two { true },
        1 => FormValue.One,
        else => return error.Whatever,
    }
}

#attribute("test")
fn switchProngImplicitCast() {
    const result = switch (%%foo(2)) {
        One => false,
        Two => |x| x,
    };
    assert(result);
}
