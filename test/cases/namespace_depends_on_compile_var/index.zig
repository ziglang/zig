const assert = @import("std").debug.assert;

#attribute("test")
fn namespaceDependsOnCompileVar() {
    if (some_namespace.a_bool) {
        assert(some_namespace.a_bool);
    } else {
        assert(!some_namespace.a_bool);
    }
}
const some_namespace = switch(@compileVar("os")) {
    linux => @import("a.zig"),
    else => @import("b.zig"),
};


