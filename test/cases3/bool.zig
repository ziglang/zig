fn boolLiterals() {
    @setFnTest(this);

    assert(true);
    assert(!false);
}

fn castBoolToInt() {
    @setFnTest(this);

    const t = true;
    const f = false;
    assert(i32(t) == i32(1));
    assert(i32(f) == i32(0));
    nonConstCastBoolToInt(t, f);
}

fn nonConstCastBoolToInt(t: bool, f: bool) {
    assert(i32(t) == i32(1));
    assert(i32(f) == i32(0));
}

// TODO const assert = @import("std").debug.assert;
fn assert(ok: bool) {
    if (!ok)
        @unreachable();
}
