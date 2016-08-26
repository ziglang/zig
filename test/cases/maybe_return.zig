const assert = @import("std").debug.assert;

#attribute("test")
fn maybeReturn() {
    assert(??foo(1235));
    assert(if (const _ ?= foo(null)) false else true);
    assert(!??foo(1234));
}

// TODO add another function with static_eval_enable(true)
#static_eval_enable(false)
fn foo(x: ?i32) -> ?bool {
    const value = ?return x;
    return value > 1234;
}
