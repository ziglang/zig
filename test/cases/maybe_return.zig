const assert = @import("std").debug.assert;

fn maybeReturn() {
    @setFnTest(this, true);

    assert(??foo(1235));
    assert(if (const _ ?= foo(null)) false else true);
    assert(!??foo(1234));
}

// TODO test static eval maybe return
fn foo(x: ?i32) -> ?bool {
    @setFnStaticEval(this, false);

    const value = ?return x;
    return value > 1234;
}
