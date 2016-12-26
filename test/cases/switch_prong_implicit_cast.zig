const FormValue = enum {
    One,
    Two: bool,
};

error Whatever;

fn foo(id: u64) -> %FormValue {
    switch (id) {
        2 => FormValue.Two { true },
        1 => FormValue.One,
        else => return error.Whatever,
    }
}

fn switchProngImplicitCast() {
    @setFnTest(this);

    const result = switch (%%foo(2)) {
        FormValue.One => false,
        FormValue.Two => |x| x,
    };
    assert(result);
}

// TODO const assert = @import("std").debug.assert;
fn assert(ok: bool) {
    if (!ok)
        @unreachable();
}
