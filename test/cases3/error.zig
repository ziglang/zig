pub fn foo() -> %i32 {
    const x = %return bar();
    return x + 1
}

pub fn bar() -> %i32 {
    return 13;
}

pub fn baz() -> %i32 {
    const y = foo() %% 1234;
    return y + 1;
}

fn errorWrapping() {
    @setFnTest(this);

    assert(%%baz() == 15);
}

error ItBroke;
fn gimmeItBroke() -> []const u8 {
    @errorName(error.ItBroke)
}

fn errorName() {
    @setFnTest(this);
    assert(memeql(@errorName(error.ItBroke), "ItBroke"));
}


// TODO const assert = @import("std").debug.assert;
fn assert(ok: bool) {
    if (!ok)
        @unreachable();
}

// TODO import from std.str
pub fn memeql(a: []const u8, b: []const u8) -> bool {
    sliceEql(u8, a, b)
}

// TODO import from std.str
pub fn sliceEql(inline T: type, a: []const T, b: []const T) -> bool {
    if (a.len != b.len) return false;
    for (a) |item, index| {
        if (b[index] != item) return false;
    }
    return true;
}

