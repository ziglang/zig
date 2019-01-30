const builtin = @import("builtin");
const assertOrPanic = @import("std").debug.assertOrPanic;

test "namespace depends on compile var" {
    if (some_namespace.a_bool) {
        assertOrPanic(some_namespace.a_bool);
    } else {
        assertOrPanic(!some_namespace.a_bool);
    }
}
const some_namespace = switch (builtin.os) {
    builtin.Os.linux => @import("a.zig"),
    else => @import("b.zig"),
};
