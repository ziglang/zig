const a_namespace = @import("cases3/import/a_namespace.zig");

fn callFnViaNamespaceLookup() {
    @setFnTest(this);

    assert(a_namespace.foo() == 1234);
}

// TODO const assert = @import("std").debug.assert;
fn assert(ok: bool) {
    if (!ok)
        @unreachable();
}
