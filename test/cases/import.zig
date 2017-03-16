const assert = @import("std").debug.assert;
const a_namespace = @import("cases/import/a_namespace.zig");

test "callFnViaNamespaceLookup" {
    assert(a_namespace.foo() == 1234);
}
