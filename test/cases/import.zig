const assert = @import("std").debug.assert;
const a_namespace = @import("import/a_namespace.zig");

test "call fn via namespace lookup" {
    assert(a_namespace.foo() == 1234);
}
