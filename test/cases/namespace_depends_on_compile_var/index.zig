const builtin = @import("builtin");
const assert = @import("std").debug.assert;

test "namespace depends on compile var" {
    if (some_namespace.a_bool) {
        assert(some_namespace.a_bool);
    } else {
        assert(!some_namespace.a_bool);
    }
}
const some_namespace = switch (builtin.os) {
    builtin.Os.linux => @import("a.zig"),
    else => @import("b.zig"),
};
