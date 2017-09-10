const assert = @import("std").debug.assert;
const a_namespace = @import("import/a_namespace.zig");

test "call fn via namespace lookup" {
    assert(a_namespace.foo() == 1234);
}

test "importing the same thing gives the same import" {
    assert(@import("std") == @import("std"));
}
