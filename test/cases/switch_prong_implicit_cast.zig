const assert = @import("std").debug.assert;

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

test "switch prong implicit cast" {
    const result = switch (%%foo(2)) {
        FormValue.One => false,
        FormValue.Two => |x| x,
    };
    assert(result);
}
