const assert = @import("std").debug.assert;

enum FormValue {
    One,
    Two: bool,
}

error Whatever;

fn foo(id: u64) -> %FormValue {
    @setFnStaticEval(this, false);

    switch (id) {
        2 => FormValue.Two { true },
        1 => FormValue.One,
        else => return error.Whatever,
    }
}

fn switchProngImplicitCast() {
    @setFnTest(this, true);

    const result = switch (%%foo(2)) {
        One => false,
        Two => |x| x,
    };
    assert(result);
}
