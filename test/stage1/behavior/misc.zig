const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const cstr = std.cstr;
const builtin = @import("builtin");
const maxInt = std.math.maxInt;

// normal comment

/// this is a documentation comment
/// doc comment line 2
fn emptyFunctionWithComments() void {}

test "empty function with comments" {
    emptyFunctionWithComments();
}
