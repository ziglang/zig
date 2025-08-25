const assert = @import("std").debug.assert;
pub const bar = @import("bar");

comptime {
    assert(bar.foo == @This());
}
