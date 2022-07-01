const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

test "miscompilation with bool return type" {
    var x: usize = 1;
    var y: bool = getFalse();
    _ = y;

    try expect(x == 1);
}

fn getFalse() bool {
    return false;
}
