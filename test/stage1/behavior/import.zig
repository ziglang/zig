const assertOrPanic = @import("std").debug.assertOrPanic;
const a_namespace = @import("import/a_namespace.zig");

test "call fn via namespace lookup" {
    assertOrPanic(a_namespace.foo() == 1234);
}

test "importing the same thing gives the same import" {
    assertOrPanic(@import("std") == @import("std"));
}
