const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;

comptime {
    const builtin = @import("builtin");
    if (builtin.os == builtin.Os.macosx) {
        @export("__mh_execute_header", _mh_execute_header, builtin.GlobalLinkage.Weak);
    }
}
var _mh_execute_header = extern struct {x: usize}{.x = 0};

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    assertOrPanic(add(3, 7) == 10);
}
