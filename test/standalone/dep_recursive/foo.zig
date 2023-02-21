const assert = @import("std").debug.assert;
pub const foo = @import("foo");

comptime {
    assert(foo == @This());
}
