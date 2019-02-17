const expect = @import("std").testing.expect;
const a_namespace = @import("import/a_namespace.zig");

test "call fn via namespace lookup" {
    expect(a_namespace.foo() == 1234);
}

test "importing the same thing gives the same import" {
    expect(@import("std") == @import("std"));
}
